---
title: "GSODR use case: Specified years/stations vignette"
author: "Adam H Sparks"
date: "2017-01-30"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteEngine{knitr::knitr}
  %\VignetteIndexEntry{GSODR use case: Specified years/stations vignette}
  %\VignetteEncoding{UTF-8}
---

# Gather Data for IRRI Central Luzon Survey Loop

The IRRI (International Rice Research Institute) survey loop in Central Luzon is a study that aims to monitor the changes in rice farming in the major rice producing area of the Philippines - the Central Luzon region, which is called as the "rice bowl of the Philippines". Data have been collected in this project since the 1960s. See, <http://ricestat.irri.org/fhsd/php/panel.php?page=1&sortBy=title&sortOrder=ascending#> for the panel data.

This vignette details how to find and retrieve weather data for the area that this survey covers for the time period of 1960-2016. Methods that are detailed include: 
  * retrieving a spatial object of provincial level data;
  * subsetting this data for the provinces of interest;
  * merging the polygons into one object;
  * finding the centroid of this resulting polygon;
  * using the centroid of the polygon to find stations within 100km of this point;
  * determining which stations provide data for the specified time-period, 1960-2016; and 
  * downloading the station files and creating a single CSV file of the data.

## Retrieve PHL Provincial Data and Select Loop Provinces

First we retrieve data from GADM.org that will provide the provincial spatial data for the survey area. We will then use this to find the centroid, which will be used to find the nearest stations.

```r
library(raster)
library(rgdal)

RP <- getData(country = "Philippines", level = 1)
```
Select the provinces involved in the survey and make a new object called
`Central_Luzon`.


```r
Central_Luzon <- RP[RP@data$NAME_1 == "Pampanga" | 
           RP@data$NAME_1 == "Tarlac" |
           RP@data$NAME_1 == "Pangasinan" |
           RP@data$NAME_1 == "La Union" |
           RP@data$NAME_1 == "Nueva Ecija" |
           RP@data$NAME_1 == "Bulacan", ]
```

## Dissolve Polygons and Find Centroid of Loop Survey Area

Now that we have the provincial data imported, we will dissolve the polygons and find the centroid.

```r
library(rgeos)
Central_Luzon <- gUnaryUnion(Central_Luzon)
centroid <- gCentroid(Central_Luzon)
```

Next, make a list of stations that are within this area.

```r
library(GSODR)
library(readr)
# Fetch station list from NCDC
station_meta <- read_csv(
  "ftp://ftp.ncdc.noaa.gov/pub/data/noaa/isd-history.csv",
  col_types = "ccccccddddd",
  col_names = c("USAF", "WBAN", "STN_NAME", "CTRY", "STATE", "CALL", "LAT",
                "LON", "ELEV_M", "BEGIN", "END"), skip = 1)
station_meta$STNID <- as.character(paste(station_meta$USAF,
                                         station_meta$WBAN,
                                         sep = "-"))

loop_stations <- nearest_stations(LAT = centroid@coords[, 2],
                                  LON = centroid@coords[, 1], 
                                  distance = 100)

loop_stations <- station_meta[station_meta$STNID %in% loop_stations, ]

loop_stations <- loop_stations[loop_stations$BEGIN <= 19591231 &
                                 loop_stations$END >= 20151231, ]
```

## Using get_GSOD to Fetch the Requested Station Files

Using the `get_GSOD()` function may not work with this many station and year combinations. Often the FTP server becomes overwhelmed and stops responding to requests.

This example shows how you could construct a query using the `get_GSOD()` function. Be aware that it may result in incomplete data and error from the server. If it does this, see the following option for using the `reformat_GSOD()` function.


```r
get_GSOD(station = eval(parse(text = loop_stations[, 12])), years = 1960:2015,
                              CSV = TRUE, dsn = "~/",
                              filename = "Loop_Survey_Weather_1960-1969")
```

## Another Option

`GSODR` provides a function for dealing with local files that have been transfered from the server already as well, `reformat_GSOD()`. If the previous example with `get_GSOD()` does not work, this is a good alternative that takes a bit more intervention but gives the same results.

Using your FTP client, e.g. FileZilla, log into the NCDC FTP server, <ftp.ncdc.noaa.gov> and navigate to /pub/data/gsod/. Manually downloading the files for each station listed above from 1960 to 2015 is possible, but tedious. An easier solution is to simply download the annual files found in each yearly directory, "gsod-YYYY.tar" and untar them locally and then use R to list the available files and select only the files for the stations of interest. Lastly, write the data to disk as a CSV file for saving and later use.

```r
years <- 1960:2015

loop_stations <- eval(parse(text = loop_stations[, 12]))

# create file list
loop_stations <- do.call(
  paste0, c(expand.grid(loop_stations, "-", years, ".op.gz"))
  )

local_files <- list.files(path = "./GSOD", full.names = TRUE, recursive = TRUE)
local_files <- local_files[basename(local_files) %in% loop_stations]

loop_data <- reformat_GSOD(file_list = local_files)

write.csv(loop_data, file = "Loop_Survey_Weather_1960-1969")
```

# Notes

## Sources

#### Elevation Values

90m hole-filled SRTM digital elevation (Jarvis *et al.* 2008) was used to identify and correct/remove elevation errors in data for station locations between -60˚ and 60˚ latitude. This applies to cases here where elevation was missing in the reported values as well. In case the station reported an elevation and the DEM does not, the station reported is taken. For stations beyond -60˚ and 60˚ latitude, the values are station reported values in every instance. See <https://github.com/ropensci/GSODR/blob/devel/data-raw/fetch_isd-history.md>
for more detail on the correction methods.

## WMO Resolution 40. NOAA Policy

*Users of these data should take into account the following (from the [NCDC website](http://www7.ncdc.noaa.gov/CDO/cdoselect.cmd?datasetabbv=GSOD&countryabbv=&georegionabbv=)):*

> "The following data and products may have conditions placed on their international commercial use. They can be used within the U.S. or for non-commercial international activities without restriction. The non-U.S. data cannot be redistributed for commercial purposes. Re-distribution of these data by others must provide this same notification." [WMO Resolution 40. NOAA Policy](https://public.wmo.int/en/our-mandate/what-we-do/data-exchange-and-technology-transfer)

References
==========

Jarvis, A., Reuter, H.I., Nelson, A., Guevara, E. (2008) Hole-filled SRTM for the globe Version 4, available from the CGIAR-CSI SRTM 90m Database (<http://srtm.csi.cgiar.org>)

