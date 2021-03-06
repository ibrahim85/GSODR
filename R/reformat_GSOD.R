#' Clean, Reformat and Generate New Variables From GSOD Weather Data
#'
#'This function automates cleaning and reformatting of GSOD,
#'\url{https://data.noaa.gov/dataset/global-surface-summary-of-the-day-gsod},
#'station files in "WMO-WBAN-YYYY.op.gz" format that have been downloaded from
#' the United States National Center for Environmental Information's (NCEI)
#' FTP server.
#'
#'For automated downloading and processing see the \code{\link{get_GSOD}}
#'function which provides expanded functionality for automatically downloading
#'and expanding annual GSOD files and cleaning station files.
#'
#'This function reformats the data into a more usable form and calculates three
#'new elements; saturation vapour pressure (es), actual vapour pressure (ea) and
#'relative humidity (RH).  All units are converted to International System of
#'Units (SI), e.g., Fahrenheit to Celsius and inches to millimetres. 
#'Alternative elevation measurements are supplied for missing values or values 
#'found to be questionable based on the Consultative Group for International
#'Agricultural Research's Consortium for Spatial Information group's (CGIAR-CSI)
#'Shuttle Radar Topography Mission 90 metre (SRTM 90m) digital elevation data 
#'based on NASA's original SRTM 90m data.
#'
#'@param dsn User supplied file path to location of station file data on
#'local disk for reformatting.
#'@param file_list User supplied list of files of station data on local disk for
#'reformatting.
#'
#' @details
#' Data summarise each year by station, which include vapour pressure and
#' relative humidity elements calculated from existing data in GSOD.
#'
#' All missing values in resulting files are represented as NA regardless of
#' which field they occur in.
#'
#' Only station files in ".op.gz" file format are supported by this function. If
#' you have downloaded the full annual "gsod_YYYY.tar" file you will need to
#' extract the individual station files first to use this function.
#'
#' The data returned either in a data.frame object that includes the following
#' fields:
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
#' @note Some of these data are redistributed with this R package. Originally
#' from these data come from the US NCEI which states that users of these data
#' should take into account the following: \dQuote{The following data and
#' products may have conditions placed on their international commercial use.
#' They can be used within the U.S. or for non-commercial international
#' activities without restriction. The non-U.S. data cannot be redistributed for
#' commercial purposes. Re-distribution of these data by others must provide
#' this same notification.}
#'
#' @examples
#' \dontrun{
#'
#' # Reformat station data files in local directory
#' x <- reformat_GSOD(dsn = "~/tmp")
#'
#' # Reformat a list of data files
#' y <- c("~/GSOD/gsod_1960/200490-99999-1960.op.gz",
#'        "~/GSOD/gsod_1961/200490-99999-1961.op.gz")
#' x <- reformat_GSOD(file_list = y)
#' }
#'
#' @author Adam H Sparks, \email{adamhsparks@gmail.com}
#'
#' @references {Jarvis, A., Reuter, H.I, Nelson, A., Guevara, E. (2008)
#' Hole-filled SRTM for the globe Version 4, available from the CGIAR-CSI SRTM
#' 90m Database \url{http://srtm.csi.cgiar.org}}
#'
#' @return A \code{data.frame} object of weather data or a comma-separated value
#' (CSV) or GeoPackage (GPKG) file saved to local disk.
#'
#' @seealso \code{\link{get_GSOD}}
#'
#' @export
reformat_GSOD <- function(dsn = NULL, file_list = NULL) {
  # Fetch latest station metadata from NCDC server
  if (!exists("stations")) {
    stations <- get_station_list()
  }
  # If dsn !NULL, create a list of files to reformat
  if (!is.null(dsn)) {
    file_list <- list.files(path = dsn,
                            pattern = "^.*\\.op.gz$",
                            full.names = TRUE)
  }
  plyr::ldply(
    .data = file_list,
    .fun = .process_gz,
    stations = stations,
    .progress = "text"
  )
}
