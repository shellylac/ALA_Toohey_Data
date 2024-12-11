# This script gets updated data from the ALA to add to the base dataset
library(here)
library(galah)
library(tidyverse)

# Configure ALA ----
galah_config(atlas = "Australia",
             email = "shelly.lachish@csiro.au",
             download_reason_id = "citizen science"
)

# Source functions ----
source(here("R", "functions.R"))


# Read in the base data ----
base_counts <- read_rds(here("output_data", "toohey_species_counts.rds"))
base_occs <- read_rds(here("output_data", "toohey_species_occurences.rds"))


#> Define the Toohey bounding box ----
# nw = -27.531057, 153.035337
# ne = -27.537956, 153.082805
# se = -27.561382, 153.078571
# sw = -27.555471, 153.030074

b_box <- sf::st_bbox(c(xmin = 153.030074, xmax = 153.082805,
                       ymin = -27.531057, ymax = -27.561382),
                     crs = sf::st_crs("WGS84"))


# Get latest month of occs -----
base_latest_year <- year(max(base_occs$eventDate))
base_latest_month <- month(max(base_occs$eventDate))
update_month <- base_latest_month - 1


# Get update occ data ----
occurrence_updates <- update_occurrences(year = base_latest_year,
                                        month = base_latest_month,
                                        b_box = b_box)

# Add cladistics ----
occ_updates_cladistics <- add_cladistics(occurrence_updates)


# Run tests to check format of occ_updates_cladistics ----
test_results <- test_file(here("R", "update_occs_testQA.R"))
results_df <- as.data.frame(test_results)

# Row bind and save (overwrite) ----
# Check if there are any failures or errors in the outcome column
if (any(results_df$outcome %in% c("failure", "error"))) {
  stop("Data structure tests failed. Please fix the issues before proceeding.")

  } else {
  message("All tests passed. Proceeding with further analysis.")

  # Row bind, remove duplicates and save (overwrite)
  all_occ_data <- bind_rows(base_occs, occ_updates_cladistics) |>
    distinct()
}


