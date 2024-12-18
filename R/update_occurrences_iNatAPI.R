# This script gets updated data from the ALA to add to the base dataset
library(galah)
library(dplyr)
library(tidyr)
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
galah::galah_config(atlas = "Australia",
                    email = "shelly.lachish@csiro.au",
                    download_reason_id = "citizen science"
)

# Read in the base data ----
message("\nReading in base occurrences ...")
base_occs <- readr::read_rds("./output_data/toohey_species_occurrences.rds")


# Define date range: from max Date in base data to today
base_date <- as.Date(max(base_occs$eventDate), format = "%Y-%m-%d")
max_date <- Sys.Date()

# Define bounding box - iNat API doesn't accept shapefily to geo limit -----
nelat <- -27.5312
nelng <- 153.082
swlat <- -27.5625
swlng <- 153.0302

# Build the API query string for Taxa of interest ----
taxa_ids <- c(3, 40151, 26036)  # Birds, Mammals, Reptiles
query_str <- construct_api_query(taxa_ids,
                                 min_date = base_date,
                                 max_date = max_date)

# Base URL for observations -----
base_url <- "https://api.inaturalist.org/v1/observations"

# Get the latest observations  -----
message("\nDownloading occurrences ...")

new_occs <- data.frame()
page_num <- 1

while (TRUE) {
  parsed <- fetch_page(base_url, query_str, page_num)
  # If there are no new occurrences  - then break loop
  if (is.null(parsed$results$id)) break

  fields <- c("time_observed_at",
              "location",
              "taxon.name",
              "taxon.preferred_common_name",
              "taxon.iconic_taxon_name",
              "taxon.wikipedia_url")

  existing_fields <- fields[fields %in% names(parsed$results)]

  observations_df <- parsed$results[, existing_fields, drop = FALSE]
  new_occs <- dplyr::bind_rows(new_occs, observations_df)

  page_num <- page_num + 1
}

# Tidy the data and get cladistics  -----
new_occs_tidy <- tidy_api_newoccs(new_occs)


# Spatially filter the data to retain only occurrences in our shapefile ----
# Read in the Toohey Forest Boundary shapefile to limit occurrences
toohey_outline <- sf::st_read("./spatial_data/toohey_forest_boundary.shp")

new_occs_toohey <- do_spatial_intersect(new_occs_tidy, toohey_outline)

# Add cladistics ----
message("Adding cladistics ...")
api_clad_data <- galah::search_taxa(new_occs_toohey$taxon.name) |> distinct()
occ_updates_cladistics <- add_cladistics(occ_data = new_occs_toohey,
                                         clad_data = api_clad_data,
                                         type = "iNat")


# Run tests to check format of occ_updates_cladistics ----
message("Running test suite ...")
test_summary <- testthat::test_file("./R/update_occs_testQA.R")[[1]]$results
test_results <- purrr::map_chr(test_summary, ~ attr(.x, "class")[1])

# Row bind and save (overwrite) ----
if (any(test_results == "expectation_failure")) {
  stop("Data structure tests failed. Please fix the issues before proceeding.")

  } else {
    message("\nAll tests passed. Proceeding with further analysis.")

    new_occs_to_add <- occ_updates_cladistics |>
      dplyr::anti_join(base_occs |>
                         select(latitude, longitude, eventDate, eventTime, species))

    message(paste0("\n\nNumber of new occurrences added: ", dim(new_occs_to_add)[1]))

    # Row bind, remove duplicates and save (overwrite)
    updated_occ_data <- dplyr::bind_rows(base_occs, new_occs_to_add)

    message(paste0("\n\nTotal number of occurrences in data: ", dim(updated_occ_data)[1]))

    # Overwrite the current occurrence data with this update
    readr::write_rds(updated_occ_data,
                     file = "./output_data/toohey_species_occurrences.rds",
                     compress = "gz")

    }

#Turn of logging
sink()
closeAllConnections()

