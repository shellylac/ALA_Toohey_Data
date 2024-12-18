# My broad toohey bounding box
# top_l <-   -27.5312 / 153.0353
# top_r <-  -27.53855 / 153.082
# bottom_r <-  -27.5625 / 153.0774
# bottom_l <-  -27.5563 / 153.0302


orig <- toohey_occurrences$eventDate[1:5]
orig2 <- orig

time_aest <- as.POSIXct(orig, tz = "Australia/Brisbane")
time_aest


attr(orig2, "tzone") <- "Australia/Brisbane"
orig2
orig

time <- lubridate::hms(format(orig, "%H:%M:%S"))
time
class(time)
