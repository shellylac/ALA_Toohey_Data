library(galah)
library(sf)
library(tidyverse)
library(ggplot2)
library(sf)
library(here)
library(showtext)

# Define the Toohey bounding box
# nw = -27.531057, 153.035337
# ne = -27.537956, 153.082805
# se = -27.561382, 153.078571
# sw = -27.555471, 153.030074

b_box <- sf::st_bbox(c(xmin = 153.030074, xmax = 153.082805,
                       ymin = -27.531057, ymax = -27.561382),
                     crs = sf::st_crs("WGS84"))


## Function to extract data from the ALA Interface [galah package] ----
# library(galah)
# getOption("galah_config")$package
# clear_cached_files()

galah_config(atlas = "Australia",
             email = "shelly.lachish@csiro.au",
             download_reason_id = "citizen science", #ID 11
             caching = T
             # cache_directory = here("Temp")
             )


# Get counts of species in taxa list
counts <- galah_call() |>
  galah_identify("koala") |>
  galah_group_by(species) |>
  galah_geolocate(b_box, type = "bbox") |>
  galah_apply_profile(ALA) |>
  galah_filter(year >= 2024) |>
  atlas_counts()

occurrences <- galah_call() |>
  galah_identify("koala") |>
  galah_group_by(species) |>
  galah_geolocate(b_box, type = "bbox") |>
  galah_apply_profile(ALA) |>
  galah_filter(year >= 2024) |>
  galah_select(scientificName,
               decimalLatitude,
               decimalLongitude,
               eventDate,
               occurrenceStatus) |>
  atlas_occurrences()

