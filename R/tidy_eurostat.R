#' @title Transform Data into Row-Column-Value Format
#' @description Transform raw Eurostat data table into the row-column-value
#' format (RCV).
#' @param dat a data.frame from \code{\link{get_eurostat_raw}}.
#' @param time_format a string giving a type of the conversion of the
#'                    time column from the eurostat format.
#'                    A "date" (default) convers to a \code{\link{Date}}
#'                    with a first date of the period. A "date_last"
#'                    convers to a \code{\link{Date}} with
#'         a last date of the period. A "num" convers to a numeric and "raw"
#'         does not do conversion. See \code{\link{eurotime2date}} and
#'         \code{\link{eurotime2num}}.
#' @param select_time a character symbol for a time frequence or NULL
#'  (default).
#' @param stringsAsFactors if \code{TRUE} (the default) variables are
#'         converted to factors in original Eurostat order. If \code{FALSE}
#'         they are returned as strings.
#' @param keepFlags a logical whether the flags (e.g. "confidential",
#'     "provisional") should be kept in a separate column or if they
#'     can be removed. Default is \code{FALSE}
#' @return data.frame in the molten format with the last column 'values'.
#' @seealso \code{\link{get_eurostat}}
#' @references See citation("eurostat").
#' @author Przemyslaw Biecek, Leo Lahti and Janne Huovari \email{ropengov-forum@@googlegroups.com} \url{http://github.com/ropengov/eurostat}
#' @keywords internal utilities database
tidy_eurostat <- function(dat, time_format = "date", select_time = NULL,
           stringsAsFactors = default.stringsAsFactors(),
           keepFlags = FALSE) {

    # To avoid warnings
    time <- NULL

    # Separate codes to columns
    cnames <- strsplit(colnames(dat)[1], split = "\\.")[[1]]
    cnames1 <- cnames[-length(cnames)]  # for columns
    cnames2 <- cnames[length(cnames)]   # for colnames
    
    # Separe variables from first column
    dat2 <- tidyr::separate_(dat, col = colnames(dat)[1],
                       into = cnames1,
                       sep = ",", convert = FALSE)
    
    # Get variable from column names
    # na.rm TRUE to save memory
    dat2 <- tidyr::gather_(dat2, cnames2, "values", 
                           names(dat2)[!(names(dat2) %in% cnames1)],
                           convert = FALSE, na.rm = TRUE)

    ## separate flags into separate column
    if(keepFlags == TRUE) {
      dat2$flags <- as.vector(
        stringi::stri_match_first_regex(dat2$values, pattern = "[A-Za-z]"))
    }
    
    # clean time and values
    dat2$time <- gsub("X", "", dat2$time)
    dat2$values <- tidyr::extract_numeric(dat2$values)
    
    # variable columns
    var_cols <- names(dat2)[!(names(dat2) %in% c("time", "values"))]
    
    # reorder to standard order
    dat2 <- dat2[c(var_cols, "time", "values")]
    
    # columns from var_cols are converted into factors
    # avoid convert = FALSE since it converts T into TRUE instead of TOTAL
    if (stringsAsFactors){
      dat2[,var_cols] <- lapply(dat2[, var_cols, drop = FALSE],
                              function(x) factor(x, levels = unique(x)))
    }

    # For multiple time frequency

    freqs <- available_freq(dat2$time)
    
    if (!is.null(select_time)){
      if (length(select_time) > 1) stop(
        "Only one frequency should be selected in select_time. Selected: ",
        shQuote(select_time))
 
      # Annual
      if (select_time == "Y"){
        dat2 <- subset(dat2, nchar(time) == 4)
      # Others
      } else {
        dat2 <- subset(dat2, grepl(select_time, time))
      }
      # Test if data
      if (nrow(dat2) == 0) stop(
        "No data selected with select_time:", dQuote(select_time), "\n",
        "Available frequencies: ", shQuote(freqs))
    } else {

      if (length(freqs) > 1 & time_format != "raw") stop(
        "Data includes several time frequencies. Select frequency with
         select_time or use time_format = \"raw\".
         Available frequencies: ", shQuote(freqs ))
    }

    # convert time column
    dat2$time <- convert_time_col(dat2$time,
    	   	                       time_format = time_format)



    dat2

}


#' @title Time Column Conversions
#' @description Internal function to convert time column.
#' @param x A time column (vector)
#' @param time_format see \code{\link{tidy_eurostat}}
#' @keywords internal
convert_time_col <- function(x, time_format){

  if (time_format == "raw"){
    y <- x
  } else {
    x <- factor(x)
    if (time_format == "date"){
      y <- eurotime2date(x, last = FALSE)
    } else if (time_format == "date_last"){
      y <- eurotime2date(x, last = TRUE)
    } else if (time_format == "num"){
      y <- eurotime2num(x)
    } else if (time_format == "raw") {
      
    } else {
      stop("An unknown time_format argument: ", time_format,
           " Allowed are date, date_last, num and raw")
    }
  }
  y
}
