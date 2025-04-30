# This script gets updated data from the ALA to add to the base dataset
library(galah)
library(dplyr)
library(readr)
library(purrr)
library(lubridate)
library(sf)
library(testthat)
library(httr)
library(jsonlite)


# Source functions ----
source("./R/functions.R")

# Set logging ----
logfile <- get_log_filename()
tmp <- file(logfile, open = "wt")
sink(tmp, type = "message")
sink(tmp, type = "output")


# Configure ALA ----
galah::galah_config(
  atlas = "Australia",
  email = "shelly.lachish@csiro.au",
  download_reason_id = "citizen science"
)

# Read in the base data ----
message("Reading in base occurrences ...")
base_occs <- readRDS("./output_data/toohey_species_occurrences.rds")


#> Define the Toohey bounding box ----
# nw = -27.531057, 153.035337
# ne = -27.537956, 153.082805
# se = -27.561382, 153.078571
# sw = -27.555471, 153.030074

b_box <- sf::st_bbox(
  c(xmin = 153.030074, xmax = 153.082805, ymin = -27.531057, ymax = -27.561382),
  crs = sf::st_crs("WGS84")
)


# Get latest month of occs -----
base_latest_year <- lubridate::year(max(base_occs$eventDate))
base_latest_month <- lubridate::month(max(base_occs$eventDate))
update_month <- base_latest_month - 1


# Get update occ data ----
message("Downloading occurrences ...")
occurrence_updates <- get_occurrences(
  year = base_latest_year,
  month = base_latest_month,
  b_box = b_box
)

# Add cladistics ----
message("Adding cladistics ...")
occ_updates_cladistics <- add_cladistics(occurrence_updates, type = "ALA")


# Run tests to check format of occ_updates_cladistics ----
message("Running test suite ...")
test_summary <- testthat::test_file("./R/update_occs_testQA.R")[[1]]$results
test_results <- purrr::map_chr(test_summary, ~ attr(.x, "class")[1])

# Row bind and save (overwrite) ----
if (any(test_results == "expectation_failure")) {
  stop("Data structure tests failed. Please fix the issues before proceeding.")
} else {
  message("All tests passed. Proceeding with further analysis.")

  # Calculate how many rows will be added
  new_occs <- occ_updates_cladistics |>
    dplyr::anti_join(
      occurrence_updates,
      by = dplyr::join_by(
        scientificName,
        decimalLatitude,
        decimalLongitude,
        eventDate,
        dataResourceName
      )
    )

  message(paste0("Number of new occurrences added:", dim(new_occs)[1]))

  # Row bind, remove duplicates and save (overwrite)
  updated_occ_data <- dplyr::bind_rows(base_occs, occ_updates_cladistics) |>
    dplyr::distinct()

  message(paste0(
    "Total number of occurrences in data:",
    dim(updated_occ_data)[1]
  ))

  # Overwrite the current occurrence data with this update
  readr::write_rds(
    updated_occ_data,
    file = "./output_data/toohey_species_occurrences.rds",
    compress = "gz"
  )
}

#Turn of logging
sink()
closeAllConnections()
