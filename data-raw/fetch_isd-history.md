Fetch, clean and correct altitude in GSOD isd\_history.csv Data
================
Adam H. Sparks
2017-03-03

Introduction
============

This document details how the GSOD station history data file, ["isd-history.csv"](ftp://ftp.ncdc.noaa.gov/pub/data/noaa/isd-history.csv), is fetched from the NCEI ftp server, error checked and new elevation values generated. The new elevation values are then saved for inclusion in package as /data/SRTM\_GSOD\_elevation.rda. The resulting values are merged with the most recent station history data file from the NCEI when the user runs the `get_GSOD()` function. The resulting data frame of station information, based on the merging of the `SRTM_GSOD_elevation` data frame with the most recently available "isd-history.csv" file will result in the following changes to the data:

-   Stations where latitude or longitude are NA or both 0 are removed

-   Stations where latitude is &lt; -90˚ or &gt; 90˚ are removed

-   Stations where longitude is &lt; -180˚ or &gt; 180˚ are removed

-   A new field, STNID, a concatenation of the USAF and WBAN fields, is added

-   Stations are checked against Natural Earth 1:10 ADM0 Cultural data, stations not mapping in the isd-history reported country are dropped

-   90m hole-filled SRTM digital elevation (Jarvis *et al.* 2008) is used to identify and correct/remove elevation errors in data for station locations between -60˚ and 60˚ latitude. This applies to cases here where elevation was missing in the reported values as well. In case the station reported an elevation and the DEM does not, the station reported value is taken. For stations beyond -60˚ and 60˚ latitude, the values are station reported values in every instance for the 90m column.

Data Processing
===============

Set up workspace
----------------

``` r
dem_tiles <- list.files(path.expand("~/Data/CGIAR-CSI SRTM"), 
                        pattern = glob2rx("*.tif"), full.names = TRUE)
crs <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"
cor_stations <- list()
tf <- tempfile()
```

Download from Natural Earth and NCEI
------------------------------------

``` r
# import Natural Earth cultural 1:10m data
curl::curl_download("http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_admin_0_countries.zip",
                    destfile = tf)
NE <- unzip(tf)
NE <- raster::shapefile("./ne_10m_admin_0_countries.shp")
unlink(tf)

# download data
stations <- readr::read_csv(
  "ftp://ftp.ncdc.noaa.gov/pub/data/noaa/isd-history.csv",
  col_types = "ccccccddddd",
  col_names = c("USAF", "WBAN", "STN_NAME", "CTRY", "STATE", "CALL",
                "LAT", "LON", "ELEV_M", "BEGIN", "END"), skip = 1)

stations[stations == -999.9] <- NA
stations[stations == -999] <- NA

countries <- readr::read_table(
  "ftp://ftp.ncdc.noaa.gov/pub/data/noaa/country-list.txt")[-1, c(1, 3)]
```

Reformat and clean station data file from NCDC
----------------------------------------------

``` r
# clean data
stations <- stations[!is.na(stations$LAT) & !is.na(stations$LON), ]
stations <- stations[stations$LAT != 0 & stations$LON != 0, ]
stations <- stations[stations$LAT > -90 & stations$LAT < 90, ]
stations <- stations[stations$LON > -180 & stations$LON < 180, ]
stations$STNID <- as.character(paste(stations$USAF, stations$WBAN, sep = "-"))

# join countries with countrycode data
countries <- dplyr::left_join(countries, countrycode::countrycode_data,
                              by = c(FIPS = "fips105"))

# create xy object to check for geographic location agreement with reported
xy <- dplyr::left_join(stations, countries, by = c("CTRY" = "FIPS"))
```

Check data for inconsistencies
------------------------------

GSOD data have some inconsistencies in them, some of this has been removed above with filtering. Further filtering is used remove stations reporting locations in countries that do not match the physical coordinates reported. Using [Natural Earth Data 1:10 Cultural Data](http://www.naturalearthdata.com/downloads/10m-cultural-vectors/), the stations reported countries are checked against the country in which the coordinates map.

Also, reported elevation may differ from actual. Hijmans *et al.* (2005) created their own digital elevation model using Jarvis *et al.* (2004) and [GTOPO30 data](https://lta.cr.usgs.gov/GTOPO30) for areas where there was no SRTM data available (&gt;+/-60˚ latitude). Here only the hole-filled SRTM data, V4 (Jarvis *et al.* 2008) was used for correction of agroclimatology data (-60˚ to 60˚ latitude). Any incorrect station elevations beyond these values were ignored in this data set. Stations with incorrect elevation were identified using `raster::extract(x, y, buffer = 200, fun = mean)` so that surrounding cells are also used to determine the elevation at that point, reducing the chances of over or underestimating in mountainous areas. See Hijmans *et al.* (2005) for more detailed information on this methodology.

The hole-filled SRTM data is large enough that it won't all fit in-memory on most desktop computers. Using tiles allows this process to run on a modest machine with minimal effort but does take some time to loop through all of the tiles.

Data can be downloaded from the [CGIAR-CSI's](http://csi.cgiar.org/WhtIsCGIAR_CSI.asp) ftp server, [srtm.csi.cgiar.org](ftp://srtm.csi.cgiar.org), using an FTP client to facilitate this next step.

``` r
# quality check station locations for reported country and lat/lon position
# agreement

# create spatial object to check for location
xy <- as.data.frame(xy)
sp::coordinates(xy) <- ~ LON + LAT
sp::proj4string(xy) <- sp::CRS(crs)

# check for location in country
point_check <- sp::over(xy, NE)
point_check <- as.data.frame(point_check)
stations_discard <- point_check[point_check$FIPS %in% point_check$FIPS_10_ == FALSE, ]
nrow(stations_discard)
```

    ## [1] 0

Zero observations (rows) in stations\_discard, the data look good, no need to remove any

``` r
# create a spatial object for extracting elevation values using spatial points
stations <- as.data.frame(stations)
sp::coordinates(stations) <- ~ LON + LAT
sp::proj4string(stations) <- sp::CRS(crs)

# set up cluster for parallel processing
library(foreach)
cl <- parallel::makeCluster(parallel::detectCores())
doParallel::registerDoParallel(cl)

corrected_elev <- tibble::as_tibble(
  data.table::rbindlist(foreach(i = dem_tiles) %dopar% {
    
    # Load the DEM tile
    dem <- raster::raster(i)
    sub_stations <- raster::crop(stations, dem)
    
    # in some cases the DEM represents areas where there is no station
    # check for that here and if no stations, go on to next iteration
    if (!is.null(sub_stations)) {
      
      # use a 200m buffer to extract elevation from the DEM
      sub_stations$ELEV_M_SRTM_90m <- raster::extract(dem, sub_stations,
                                                      buffer = 200,
                                                      fun = mean)
      
      # convert spatial object back to normal data frame and add new fields
      sub_stations <- as.data.frame(sub_stations)
      return(sub_stations)
    }
  }
  )
)
# stop cluster
parallel::stopCluster(cl)
```

Some stations occur in areas where DEM has no data, in this case, use original station elevation for these stations.

``` r
corrected_elev <- dplyr::mutate(corrected_elev,
                                ELEV_M_SRTM_90m = ifelse(is.na(ELEV_M_SRTM_90m),
                                                ELEV_M, ELEV_M_SRTM_90m))
# round SRTM_90m_Buffer field to whole number in cases where station reported
# data was used and rename column
corrected_elev[, 13] <- round(corrected_elev[, 13], 0)
```

Tidy up the `corrected_elev` object by converting any factors to character prior to performing a left-join with the `stations` object. For stations above/below 60/-60 latitude, `ELEV_M_SRTM_90m` will be `NA` as there is no SRTM data for these latitudes.

``` r
c <- sapply(corrected_elev, is.factor)
corrected_elev[c] <- lapply(corrected_elev[c], as.character)

# convert stations from a spatial object to a tibble for joining
stations <- tibble::as_tibble(stations)

# Perform left join to join corrected elevation with original station data,
# this will include stations below/above -60/60
SRTM_GSOD_elevation <- dplyr::left_join(stations, corrected_elev)
```

    ## Joining, by = c("USAF", "WBAN", "STN_NAME", "CTRY", "STATE", "CALL", "LAT", "LON", "ELEV_M", "BEGIN", "END", "STNID")

``` r
summary(SRTM_GSOD_elevation)
```

    ##      USAF               WBAN             STN_NAME        
    ##  Length:28330       Length:28330       Length:28330      
    ##  Class :character   Class :character   Class :character  
    ##  Mode  :character   Mode  :character   Mode  :character  
    ##                                                          
    ##                                                          
    ##                                                          
    ##                                                          
    ##      CTRY              STATE               CALL                LAT        
    ##  Length:28330       Length:28330       Length:28330       Min.   :-89.00  
    ##  Class :character   Class :character   Class :character   1st Qu.: 22.47  
    ##  Mode  :character   Mode  :character   Mode  :character   Median : 39.25  
    ##                                                           Mean   : 31.13  
    ##                                                           3rd Qu.: 49.88  
    ##                                                           Max.   : 89.37  
    ##                                                                           
    ##       LON               ELEV_M           BEGIN               END          
    ##  Min.   :-179.983   Min.   :-350.0   Min.   :19010101   Min.   :19051231  
    ##  1st Qu.: -83.269   1st Qu.:  23.0   1st Qu.:19570701   1st Qu.:20020418  
    ##  Median :   6.700   Median : 140.0   Median :19760304   Median :20160222  
    ##  Mean   :  -3.445   Mean   : 360.8   Mean   :19782412   Mean   :20047483  
    ##  3rd Qu.:  61.889   3rd Qu.: 435.0   3rd Qu.:20020409   3rd Qu.:20170227  
    ##  Max.   : 179.750   Max.   :5304.0   Max.   :20170118   Max.   :20170301  
    ##                     NA's   :218                                           
    ##     STNID           ELEV_M_SRTM_90m 
    ##  Length:28330       Min.   :-361.0  
    ##  Class :character   1st Qu.:  25.0  
    ##  Mode  :character   Median : 156.0  
    ##                     Mean   : 380.1  
    ##                     3rd Qu.: 462.0  
    ##                     Max.   :5273.0  
    ##                     NA's   :3012

Figures
=======

``` r
if (!require("ggalt"))
{
  install.packages("ggalt")
}

ggplot(data = SRTM_GSOD_elevation, aes(x = ELEV_M, y = ELEV_M_SRTM_90m)) +
  geom_point(alpha = 0.4, size = 0.5)
```

![GSOD Reported Elevation versus CGIAR-CSI SRTM Buffered Elevation](fetch_isd-history_files/figure-markdown_github/Buffered%20SRTM%2090m%20vs%20Reported%20Elevation-1.png)

Buffered versus non-buffered elevation values were previously checked and found not to be different while also not showing any discernible geographic patterns. However, The buffered elevation data are higher than the non-buffered data. To help avoid within cell and between cell variation the buffered values are the values that are included in the final data for distribution with the GSODR package following the approach of Hijmans *et al.* (2005).

Only values for elevation derived from the SRTM data and the STNID, used to join this with the original "isd-history.csv" file data when running `get_GSOD` are included in the final data frame for distribution with the GSODR package.

``` r
# write rda file to disk for use with GSODR package
data.table::setDT(SRTM_GSOD_elevation)
SRTM_GSOD_elevation[, c(1:11) := NULL]
```

    ##               STNID ELEV_M_SRTM_90m
    ##     1: 008268-99999            1160
    ##     2: 010010-99999              NA
    ##     3: 010014-99999              48
    ##     4: 010015-99999              NA
    ##     5: 010016-99999              NA
    ##    ---                             
    ## 28326: 999999-94996             416
    ## 28327: 999999-96404              NA
    ## 28328: 999999-96406              NA
    ## 28329: 999999-96407              NA
    ## 28330: 999999-96408              NA

``` r
devtools::use_data(SRTM_GSOD_elevation, overwrite = TRUE, compress = "bzip2")

# clean up Natural Earth data files before we leave
file.remove(list.files(pattern = glob2rx("ne_10m_admin_0_countries*")))
```

    ## [1] TRUE TRUE TRUE TRUE TRUE TRUE TRUE

The SRTM\_GSOD\_elevation.rda file included in the GSODR package includes the new elevation data as the field; ELEV\_M\_SRTM\_90m.

Notes
=====

NOAA Policy
-----------

Users of these data should take into account the following (from the [NCDC website](http://www7.ncdc.noaa.gov/CDO/cdoselect.cmd?datasetabbv=GSOD&countryabbv=&georegionabbv=)):

> "The following data and products may have conditions placed on their international commercial use. They can be used within the U.S. or for non-commercial international activities without restriction. The non-U.S. data cannot be redistributed for commercial purposes. Re-distribution of these data by others must provide this same notification." [WMO Resolution 40. NOAA Policy](http://www.wmo.int/pages/about/Resolution40.html)

R System Information
--------------------

    ## R version 3.3.2 (2016-10-31)
    ## Platform: x86_64-apple-darwin15.6.0 (64-bit)
    ## Running under: OS X El Capitan 10.11.6
    ## 
    ## locale:
    ## [1] en_AU.UTF-8/en_AU.UTF-8/en_AU.UTF-8/C/en_AU.UTF-8/en_AU.UTF-8
    ## 
    ## attached base packages:
    ## [1] stats     graphics  grDevices utils     datasets  methods   base     
    ## 
    ## other attached packages:
    ## [1] ggalt_0.4.0   ggplot2_2.2.1 foreach_1.4.3
    ## 
    ## loaded via a namespace (and not attached):
    ##  [1] Rcpp_0.12.9        highr_0.6          RColorBrewer_1.1-2
    ##  [4] compiler_3.3.2     plyr_1.8.4         iterators_1.0.8   
    ##  [7] tools_3.3.2        extrafont_0.17     digest_0.6.12     
    ## [10] memoise_1.0.0      evaluate_0.10      tibble_1.2        
    ## [13] gtable_0.2.0       lattice_0.20-34    DBI_0.5-1         
    ## [16] curl_2.3           yaml_2.1.14        rgdal_1.2-5       
    ## [19] parallel_3.3.2     Rttf2pt1_1.3.4     withr_1.0.2       
    ## [22] dplyr_0.5.0        stringr_1.2.0      raster_2.5-8      
    ## [25] knitr_1.15.1       devtools_1.12.0    maps_3.1.1        
    ## [28] rprojroot_1.2      grid_3.3.2         data.table_1.10.4 
    ## [31] R6_2.2.0           rmarkdown_1.3      sp_1.2-4          
    ## [34] extrafontdb_1.0    readr_1.0.0        magrittr_1.5      
    ## [37] MASS_7.3-45        backports_1.0.5    scales_0.4.1      
    ## [40] codetools_0.2-15   htmltools_0.3.5    proj4_1.0-8       
    ## [43] assertthat_0.1     countrycode_0.19   colorspace_1.3-2  
    ## [46] labeling_0.3       ash_1.0-15         KernSmooth_2.23-15
    ## [49] stringi_1.1.2      lazyeval_0.2.0     doParallel_1.0.10 
    ## [52] munsell_0.4.3

References
==========

Hijmans, RJ, SJ Cameron, JL Parra, PG Jones, A Jarvis, 2005, Very High Resolution Interpolated Climate Surfaces for Global Land Areas. *International Journal of Climatology*. 25: 1965-1978. [DOI:10.1002/joc.1276](http://dx.doi.org/10.1002/joc.1276)

Jarvis, A, HI Reuter, A Nelson, E Guevara, 2008, Hole-filled SRTM for the globe Version 4, available from the CGIAR-CSI SRTM 90m Database (<http://srtm.csi.cgiar.org>)

Jarvis, A, J Rubiano, A Nelson, A Farrow and M Mulligan, 2004, Practical use of SRTM Data in the Tropics: Comparisons with Digital Elevation Models Generated From Cartographic Data. Working Document no. 198. Cali, CO. International Centre for Tropical Agriculture (CIAT): 32. [URL](http://srtm.csi.cgiar.org/PDF/Jarvis4.pdf)
