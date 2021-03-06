#' Download, Clean, Reformat and Generate New Elements From GSOD Weather Data
#'
#'This function automates downloading, cleaning, reformatting of data from
#'the Global Surface Summary of the Day (GSOD) data provided by the US National
#'Centers for Environmental Information (NCEI),
#'\url{https://data.noaa.gov/dataset/global-surface-summary-of-the-day-gsod},
#'and elements three new variables; saturation vapour pressure (es) – Actual
#'vapour pressure (ea) and relative humidity (RH).  Stations reporting a latitude
#'of < -90 or > 90 or longitude of < -180 or > 180 are removed.  Stations may be
#'individually checked for number of missing days to assure data quality and
#'omitting stations with too many missing observations.  All units are converted
#'to International System of Units (SI), e.g., Fahrenheit to Celsius and inches
#'to millimetres.  Alternative elevation measurements are supplied for missing
#'values or values found to be questionable based on the Consultative Group for
#'International Agricultural Research's Consortium for Spatial Information
#'group's (CGIAR-CSI) Shuttle Radar Topography Mission 90 metre (SRTM 90m)
#'digital elevation data based on NASA's original SRTM 90m data.  Further
#'information on these data and methods can be found on GSODR's GitHub
#'repository here:
#'\url{https://github.com/ropensci/GSODR/blob/master/data-raw/fetch_isd-history.md}.
#'
#' @param years Year(s) of weather data to download.
#' @param station Optional. Specify a station or multiple stations for which to
#' retrieve, check and clean weather data using \code{STNID}. The NCEI reports
#' years for which the data are available. This function checks against these
#' years. However, not all cases are properly documented and in some cases files
#' may not exist on the ftp server even though it is indicated that data was
#' recorded for the station for a particular year. If a station is specified
#' that does not have an existing file on the server, this function will
#' silently fail and move on to existing files for download and cleaning from
#' the FTP server.
#' @param country Optional. Specify a country for which to retrieve weather
#' data; full name or ISO codes can be used. See
#' \code{\link{country_list}} for a full list of country names and ISO
#' codes available.
#' @param CSV Optional. Logical. If set to TRUE, create a comma separated value
#' (CSV) file and save it locally in a user specified location, if \code{dsn} is
#' not specified by the user, defaults to the current working directory.
#' @param GPKG Optional. Logical. If set to TRUE, create a GeoPackage file and
#' save it locally in a user specified location, if \code{dsn} is not specified
#' by the user, defaults to the current working directory.
#' @param dsn Optional. Local file path to write file out to. Must be specified
#' if CSV or GPKG parameters are selected. If unspecified and \code{CSV} or
#' \code{GPKG} are set to TRUE, \code{dsn} will default to the current working
#' directory.
#' @param filename Optional. The filename for resulting file(s) to be written
#' with no file extension. File extension will be automatically appended to file
#' outputs. If unspecified by the user it will default to "GSOD" followed by
#' the file extension(s) set using \code{CSV} or \code{GPKG}.
#' @param max_missing Optional. The maximum number of days allowed to be missing
#' from a station's data before it is excluded from final file output.
#' @param agroclimatology Optional. Logical. Only clean data for stations
#' between latitudes 60 and -60 for agroclimatology work, defaults to FALSE.
#' Set to TRUE to include only stations within the confines of these
#' latitudes.
#'
#' @details
#' Data summarise each year by station, which include vapour pressure and
#' relative humidity elements calculated from existing data in GSOD.
#'
#' If the option to save locally is selected. Output may be saved as comma-
#' separated, CSV, files or GeoPackage, GPKG, files in a directory specified by
#' the user, defaulting to the current working directory.
#'
#' When querying selected stations and electing to write files to disk, all
#' years queried and stations queried will be merged into one final output file.
#'
#' All missing values in resulting files are represented as NA regardless of
#' which field they occur in.
#'
#'For more information see the description of the data provided by NCEI,
#'\url{http://www7.ncdc.noaa.gov/CDO/GSOD_DESC.txt}.
#'
#' The data returned either in a data.frame object and/or a file written to
#' local disk that includes the following fields:
#' \describe{
#' \item{STNID}{Station number (WMO/DATSAV3 number) for the location}
#' \item{WBAN}{Number where applicable--this is the historical "Weather Bureau
#' Air Force Navy" number - with WBAN being the acronym}
#' \item{STN_NAME}{Unique text identifier}
#' \item{CTRY}{Country in which the station is located}
#' \item{LAT}{Latitude. *Station dropped in cases where values are < -90 or
#'> 90 degrees or Lat = 0 and Lon = 0* (WGS84)}
#' \item{LON}{Longitude. *Station dropped in cases where values are < -180 or
#'> 180 degrees or Lat = 0 and Lon = 0* (WGS84)}
#' \item{ELEV_M}{Elevation in metres}
#' \item{ELEV_M_SRTM_90m}{Elevation in metres corrected for possible errors,
#' derived from the CGIAR-CSI SRTM 90m database (Jarvis et al. 2008)}
#' \item{YEARMODA}{Date in YYYY-mm-dd format}
#' \item{YEAR}{The year (YYYY)}
#' \item{MONTH}{The month (mm)}
#' \item{DAY}{The day (dd)}
#' \item{YDAY}{Sequential day of year (not in original GSOD)}
#' \item{TEMP}{Mean daily temperature converted to degrees C to tenths.
#' Missing = NA}
#' \item{TEMP_CNT}{Number of observations used in calculating mean daily
#' temperature}
#' \item{DEWP}{Mean daily dew point converted to degrees C to tenths. Missing
#' = NA}
#' \item{DEWP_CNT}{Number of observations used in calculating mean daily dew
#' point}
#' \item{SLP}{Mean sea level pressure in millibars to tenths. Missing = NA}
#' \item{SLP_CNT}{Number of observations used in calculating mean sea level
#' pressure}
#' \item{STP}{Mean station pressure for the day in millibars to tenths.
#' Missing = NA}
#' \item{STP_CNT}{Number of observations used in calculating mean station
#' pressure}
#' \item{VISIB}{Mean visibility for the day converted to kilometres to
#' tenths Missing = NA}
#' \item{VISIB_CNT}{Number of observations used in calculating mean daily
#' visibility}
#' \item{WDSP}{Mean daily wind speed value converted to metres/second to
#' tenths Missing = NA}
#' \item{WDSP_CNT}{Number of observations used in calculating mean daily
#' wind speed}
#' \item{MXSPD}{Maximum sustained wind speed reported for the day converted
#' to metres/second to tenths. Missing = NA}
#' \item{GUST}{Maximum wind gust reported for the day converted to
#' metres/second to tenths. Missing = NA}
#' \item{MAX}{Maximum temperature reported during the day converted to
#' Celsius to tenths--time of max temp report varies by country and region,
#' so this will sometimes not be the max for the calendar day. Missing =
#' NA}
#' \item{MAX_FLAG}{Blank indicates max temp was taken from the explicit max
#' temp report and not from the 'hourly' data. An "*" indicates max temp was
#' derived from the hourly data (i.e., highest hourly or synoptic-reported
#' temperature)}
#' \item{MIN}{Minimum temperature reported during the day converted to
#' Celsius to tenths--time of min temp report varies by country and region,
#' so this will sometimes not be the max for the calendar day. Missing =
#' NA}
#' \item{MIN_FLAG}{Blank indicates max temp was taken from the explicit max
#' temp report and not from the 'hourly' data. An "*" indicates min temp was
#' derived from the hourly data (i.e., highest hourly or synoptic-reported
#' temperature)}
#' \item{PRCP}{Total precipitation (rain and/or melted snow) reported during
#' the day converted to millimetres to hundredths; will usually not end
#' with the midnight observation, i.e., may include latter part of previous
#' day. A ".00" value indicates no measurable precipitation (includes a trace).
#' Missing = NA; *Note: Many stations do not report '0' on days with no
#' precipitation-- therefore, 'NA' will often appear on these days. For
#' example, a station may only report a 6-hour amount for the period during
#' which rain fell.* See FLAGS_PRCP column for source of data}
#' \item{PRCP_FLAG}{
#'   \describe{
#'    \item{A}{1 report of 6-hour precipitation amount}
#'    \item{B}{Summation of 2 reports of 6-hour precipitation amount}
#'    \item{C}{Summation of 3 reports of 6-hour precipitation amount}
#'    \item{D}{Summation of 4 reports of 6-hour precipitation amount}
#'    \item{E}{1 report of 12-hour precipitation amount}
#'    \item{F}{Summation of 2 reports of 12-hour precipitation amount}
#'    \item{G}{1 report of 24-hour precipitation amount}
#'    \item{H}{Station reported '0' as the amount for the day (e.g., from
#'    6-hour reports), but also reported at least one occurrence of
#'    precipitation in hourly observations--this could indicate a trace
#'    occurred, but should be considered as incomplete data for the day}
#'    \item{I}{Station did not report any precip data for the day and did not
#'    report any occurrences of precipitation in its hourly observations--it's
#'    still possible that precipitation occurred but was not reported}
#'   }
#' }
#' \item{SNDP}{Snow depth in millimetres to tenths. Missing = NA}
#' \item{I_FOG}{Indicator for fog, (1 = yes, 0 = no/not reported) for the
#' occurrence during the day}
#' \item{I_RAIN_DRIZZLE}{Indicator for rain or drizzle, (1 = yes, 0 = no/not
#' reported) for the occurrence during the day}
#' \item{I_SNOW_ICE}{Indicator for snow or ice pellets, (1 = yes, 0 = no/not
#' reported) for the occurrence during the day}
#' \item{I_HAIL}{Indicator for hail, (1 = yes, 0 = no/not reported) for the
#' occurrence during the day}
#' \item{I_THUNDER}{Indicator for thunder, (1 = yes, 0 = no/not reported)
#' for the occurrence during the day}
#' \item{I_TORNADO_FUNNEL}{Indicator for tornado or funnel cloud, (1 = yes, 0 =
#' no/not reported) for the occurrence during the day}
#'\item{ea}{Mean daily actual vapour pressure}
#' \item{es}{Mean daily saturation vapour pressure}
#' \item{RH}{Mean daily relative humidity}
#' }
#'
#'
#' @note Some of these data are redistributed with this R package.  Originally
#' from these data come from the US NCEI which states that users of these data
#' should take into account the following: \dQuote{The following data and
#' products may have conditions placed on their international commercial use.
#' They can be used within the U.S. or for non-commercial international
#' activities without restriction.  The non-U.S. data cannot be redistributed
#' for commercial purposes.  Re-distribution of these data by others must
#' provide this same notification.}
#'
#' @examples
#' \dontrun{
#' # Download weather station for Toowoomba, Queensland for 2010
#' t <- get_GSOD(years = 2010, station = "955510-99999")
#'
#' # Download data for Philippines for year 2010 and generate a yearly
#' # summary GeoPackage file, Philippines_GSOD-2010.gpkg, file in the user's
#' # home directory with a maximum of five missing days per station allowed.
#'
#' get_GSOD(years = 2010, country = "Philippines", dsn = "~/",
#' filename = "Philippines_GSOD", GPKG = TRUE, max_missing = 5)
#'
#' # Download global GSOD data for agroclimatology work for years 2009 and 2010
#' # and generate yearly summary files, GSOD-agroclimatology-2010.csv and
#' # GSOD-agroclimatology-2011.csv in the user's home directory.
#'
#' get_GSOD(years = 2010:2011, dsn = "~/",
#' filename = "GSOD_agroclimatology_2010-2011", agroclimatology = TRUE,
#' CSV = TRUE)
#'
#' }
#'
#' @author Adam Sparks, \email{adamhsparks@gmail.com}
#'
#' @references {Jarvis, A., Reuter, H. I, Nelson, A., Guevara, E. (2008)
#' Hole-filled SRTM for the globe Version 4, available from the CGIAR-CSI SRTM
#' 90m Database \url{http://srtm.csi.cgiar.org}}
#'
#' @return A \code{data.frame} object of weather data or a comma-separated value
#' (CSV) or GeoPackage (GPKG) file saved to local disk.
#'
#' @seealso \code{\link{reformat_GSOD}}
#'
#' @importFrom dplyr %>%
#' @export
get_GSOD <- function(years = NULL,
                     station = NULL,
                     country = NULL,
                     dsn = NULL,
                     filename = NULL,
                     max_missing = NULL,
                     agroclimatology = FALSE,
                     CSV = FALSE,
                     GPKG = FALSE) {
  # Create objects for use in retrieving files ---------------------------------
  original_timeout <- options("timeout")[[1]]
  options(timeout = 300)
  on.exit(options(timeout = original_timeout), add = TRUE)
  cache_dir <- tempdir()
  ftp_base <- "ftp://ftp.ncdc.noaa.gov/pub/data/gsod/%s/"
  # Validate user inputs -------------------------------------------------------
  .validate_years(years)
  # Validate stations for missing days -----------------------------------------
  if (!is.null(max_missing)) {
    if (is.na(max_missing) | max_missing < 1) {
      stop("\nThe 'max_missing' parameter must be a positive value larger than
           1\n")
    }
  }
  if (!is.null(dsn)) {
    outfile <- .validate_fileout(CSV, dsn, filename, GPKG)
  }
  # Fetch latest station metadata from NCEI server
  stations <- get_station_list()
  # Validate user entered stations for existence in stations list from NCEI
  plyr::l_ply(
    .data = station,
    .fun = .validate_station,
    stations = stations,
    years = years
  )
  country <- .validate_country(country)

  # Download files from server -----------------------------------------------
  GSOD_list <- .download_files(ftp_base, station, years, cache_dir)

  # Subset GSOD_list for agroclimatology only stations -----------------------
  if (isTRUE(agroclimatology)) {
    GSOD_list <-
      .agroclimatology_list(GSOD_list, stations, cache_dir, years)
  }
  # Subset GSOD_list for specified country -------------------------------------
  if (!is.null(country)) {
    GSOD_list <-
      .country_list(country, GSOD_list, stations, cache_dir, years)
  }
  # Validate stations for missing days -----------------------------------------
  if (!is.null(max_missing)) {
    message("Checking stations against max_missing value")
    GSOD_list <-
      .validate_missing_days(max_missing, GSOD_list)
  }
  # Clean and reformat list of station files from local disk in tempdir --------
  message("Starting data file processing")
  GSOD_XY <- as.data.frame(plyr::ldply(
    .data = GSOD_list,
    .fun = .process_gz,
    stations = stations,
    .progress = "text"
  ))[, -1]
  # Write files to disk --------------------------------------------------------
  if (isTRUE(CSV)) {
    message("\nWriting CSV file to disk.\n")
    outfile <- paste0(outfile, ".csv")
    readr::write_csv(GSOD_XY, path = paste0(outfile))
    rm(outfile)
  }
  if (isTRUE(GPKG)) {
    message("\nWriting GeoPackage File to Disk.\n")
    outfile <- paste0(outfile, ".gpkg")
    sp::coordinates(GSOD_XY) <- ~LON+LAT
    sp::proj4string(GSOD_XY) <- sp::CRS("+proj=longlat +datum=WGS84")

    # If the filename specified exists, remove it and create new
    if (file.exists(path.expand(outfile))) {
      file.remove(outfile)
    }
    # Create new .gpkg file
    rgdal::writeOGR(GSOD_XY, dsn = path.expand(outfile), layer = "GSOD",
                    driver = "GPKG")
  }
  return(GSOD_XY)
  # Cleanup --------------------------------------------------------------------
  do.call(file.remove, list(list.files(cache_dir, full.names = TRUE)))
  rm(cache_dir)
  gc()
}
# Validation functions ---------------------------------------------------------
#' @noRd
.validate_years <- function(years) {
  this_year <- 1900 + as.POSIXlt(Sys.Date())$year
  if (is.null(years) | is.character(years)) {
    stop("\nYou must provide at least one year of data to download in a numeric
         format.\n")
  } else {
    for (i in years) {
      if (i <= 0) {
        stop("\nThis is not a valid year.\n")
      } else if (i < 1929) {
        stop("\nThe GSOD data files start at 1929, you have entered a year prior
             to 1929.\n")
      } else if (i > this_year) {
        stop("\nThe year cannot be greater than current year.\n")
      }
    }
    }
  }
#' @noRd
.validate_fileout <- function(CSV, dsn, filename, GPKG) {
  if (!is.null(filename) & !isTRUE(CSV) & !isTRUE(GPKG)) {
    stop("\nYou need to specify a filetype, CSV or GPKG.\n")
  }
  if (isTRUE(CSV) | isTRUE(GPKG)) {
    if (is.null(dsn)) {
      dsn <- getwd()
    }
  dsn <- trimws(dsn)
  } else {
    if (substr(dsn, nchar(dsn) - 1, nchar(dsn)) == "//") {
      p <- substr(dsn, 1, nchar(dsn) - 2)
    } else if (substr(dsn, nchar(dsn), nchar(dsn)) == "/" |
               substr(dsn, nchar(dsn), nchar(dsn)) == "\\") {
      p <- substr(dsn, 1, nchar(dsn) - 1)
    } else {
      p <- dsn
    }
    if (!file.exists(p) & !file.exists(dsn)) {
      stop("\nFile dsn does not exist: ", dsn, ".\n")
    }
  }
  if (substr(dsn, nchar(dsn), nchar(dsn)) != "/" &
      substr(dsn, nchar(dsn), nchar(dsn)) != "\\") {
    dsn <- paste0(dsn, "/")
  }
  if (is.null(filename)) {
    filename_out <- "GSOD"
  } else {
    filename_out <- filename
  }
  outfile <- paste0(dsn, filename_out)
  return(outfile)
}
#' @noRd
.validate_station <- function(station, stations, years) {
  if (!station %in% stations[[12]]) {
    stop(
      "\n",
      paste0(station),
      " is not a valid station ID number, please check your entry. Station IDs
      can be found in the 'stations' dataframe in the STNID column.\n"
    )
  }
  BEGIN <-
    as.numeric(substr(stations[stations[[12]] == station]$BEGIN, 1, 4))
  END <-
    as.numeric(substr(stations[stations[[12]] == station]$END, 1, 4))
  if (min(years) < BEGIN | max(years) > END) {
    message("This station, ",
            station,
            ", only provides data for years ",
            BEGIN,
            " to ",
            END,
            ".\n")
  }
}

#' @noRd
.validate_country <-
  function(country) {
    if (!is.null(country)) {
      country <- toupper(trimws(country[1]))
      nc <- nchar(country)
      if (nc == 3) {
        if (country %in% GSODR::country_list$iso3c) {
          c <- which(country == GSODR::country_list$iso3c)
          country <- GSODR::country_list[[c, 1]]
        } else {
          stop(
            "\nPlease provide a valid name or 2 or 3 letter ISO country code;
            you can view the entire list of valid countries in this data by
            typing, 'country_list'.\n"
          )
        }
        } else if (nc == 2) {
          if (country %in% GSODR::country_list$iso2c) {
            c <- which(country == GSODR::country_list$iso2c)
            country <- GSODR::country_list[[c, 1]]
          } else {
            stop(
              "\nPlease provide a valid name or 2 or 3 letter ISO country code;
              you can view the entire list of valid countries in this data by
              typing, 'country_list'.\n"
            )
          }
          } else if (country %in% GSODR::country_list$COUNTRY_NAME) {
            c <- which(country == GSODR::country_list$COUNTRY_NAME)
            country <- GSODR::country_list[[c, 1]]
          } else {
            stop(
              "\nPlease provide a valid name or 2 or 3 letter ISO country code;
              you can view the entire list of valid countries in this data by
              typing, 'country_list'.\n"
            )
          }
          }
          }
#' @noRd
.validate_missing_days <-
  function(max_missing, GSOD_list) {
    records <-
      lapply(X = paste0(GSOD_list),
             FUN = R.utils::countLines)
    names(records) <- GSOD_list
    year <- as.numeric(substr(
      basename(GSOD_list[1]),
      start = nchar(basename(GSOD_list[1])) - 10 + 1,
      stop  = nchar(basename(GSOD_list[1])) - 7 + 1
    ))
    ifelse(
      format(as.POSIXct(paste0(year, "-03-01")) - 1, "%d") != "29",
      allow <- 365 - max_missing,
      allow <- 366 - max_missing
    )
    GSOD_list <- stats::na.omit(ifelse(records >= allow,
                                       GSOD_list,
                                       NA))
  }
# Function to download files from server --------------------------------------
#' @noRd
.download_files <-
  function(ftp_base, station, years, cache_dir) {
    if (is.null(station)) {
      file_list <-
        paste0(sprintf(ftp_base, years), "gsod_", years, ".tar")
      tryCatch(
        Map(
          function(ftp, dest)
            utils::download.file(url = ftp, destfile = dest),
          file_list,
          file.path(cache_dir, basename(file_list))
        ),
        error = function(x)
          stop("\nThe file downloads have failed. Please restart.\n")
      )
      tar_files <-
        list.files(cache_dir, pattern = "^gsod.*\\.tar$", full.names = TRUE)
      plyr::ldply(.data = tar_files,
                  .fun = utils::untar,
                  exdir = cache_dir)
      GSOD_list <-
        list.files(cache_dir, pattern = "^.*\\.op.gz$", full.names = TRUE)
    }
    if (!is.null(station)) {
      # The remainder of this function is from @hrbrmstr in response to my
      # SO question: http://stackoverflow.com/questions/40715370/
      message("\nChecking requested station file for availability on server.")
      MAX_RETRIES <- 6
      dir_list_handle <-
        curl::new_handle(
          ftp_use_epsv = FALSE,
          dirlistonly = TRUE,
          crlf = TRUE,
          ssl_verifypeer = FALSE,
          ftp_response_timeout = 30
        )
      s_curl_fetch_memory <- purrr::safely(curl::curl_fetch_memory)
      retry_cfm <-
        function(url, handle) {
          i <- 0
          repeat {
            i <- i + 1
            res <- s_curl_fetch_memory(url, handle = handle)
            if (!is.null(res$result))
              return(res$result)
            if (i == MAX_RETRIES) {
              stop("Too many retries...server may be under load")
            }
          }
        }
      # Wrapping the disk writer (for the actual files)
      # Note the use of the cache dir. It won't waste your bandwidth or the
      # server's bandwidth or CPU if the file has already been retrieved.
      s_curl_fetch_disk <- purrr::safely(curl::curl_fetch_disk)
      retry_cfd <-
        function(url, path) {
          cache_file <- sprintf("%s/%s", cache_dir, basename(url))
          if (file.exists(cache_file))
            return()
          i <- 0
          repeat {
            i <- i + 1
            if (i == 6) {
              stop("Too many retries...server may be under load")
            }
            res <- s_curl_fetch_disk(url, cache_file)
            if (!is.null(res$result))
              return()
          }
        }
      message("\nDownloading individual station files.\n")
      pb <- dplyr::progress_estimated(length(years))
      purrr::walk(years, function(yr) {
        year_url <- sprintf(ftp_base, yr)
        tmp <- retry_cfm(year_url, handle = dir_list_handle)
        con <- rawConnection(tmp$content)
        fils <- readLines(con)
        close(con)
        # sift out only the target stations
        purrr::map(station, ~ grep(., fils, value = TRUE)) %>%
          purrr::keep(~ length(.) > 0) %>%
          purrr::flatten_chr() -> fils
        # grab the station files
        purrr::walk(paste0(year_url, fils), retry_cfd)
        # progress bar
        pb$tick()$print()
      })
    }
    GSOD_list <-
      list.files(path = cache_dir,
                 pattern = "^.*\\.op.gz$",
                 full.names = TRUE)
  }
# Agroclimatology: subset list of stations to process---------------------------
.agroclimatology_list <-
  function(GSOD_list, stations, cache_dir, years) {
    station_list <- stations[stations$LAT >= -60 &
                               stations$LAT <= 60, ]$STNID
    station_list <- do.call(paste0,
                            c(
                              expand.grid(cache_dir, "/", station_list, "-",
                                          years, ".op.gz")
                            ))
    GSOD_list <- GSOD_list[GSOD_list %in% station_list]
    rm(station_list)
    return(GSOD_list)
  }
# Specified country: subset list of stations to process ------------------------
.country_list <-
  function(country,
           GSOD_list,
           stations,
           cache_dir,
           years) {
    country_FIPS <- unlist(
      as.character(
        stats::na.omit
        (GSODR::country_list[GSODR::country_list$FIPS == country, ][[1]]),
                                        use.names = FALSE))
    station_list <- stations[stations$CTRY == country_FIPS, ]$STNID
    station_list <- do.call(paste0,
                            c(
                              expand.grid(cache_dir,
                                          "/",
                                          station_list,
                                          "-",
                                          years,
                                          ".op.gz")
                            ))
    GSOD_list <- GSOD_list[GSOD_list %in% station_list]
    return(GSOD_list)
    rm(station_list)
  }
