# This script gets updated data from the ALA to add to the base dataset

# Read in the base data
# base_counts <- read_rds(here("output_data", "toohey_species_counts.rds"))
base_occs <- read_rds(here("output_data", "toohey_species_occurences.rds"))


# This is the update process

# Get the latest date minus 1 month from the base dataset
base_latest_data <- max(base_occs$eventDate)
base_year <- year(base_latest_data)
base_month <- month(base_latest_data)
update_month <- base_month - 2


occurence_updates <- galah_call() |>
  galah_identify(c("reptilia", "birds", "mammals")) |>
  galah_group_by(species) |>
  galah_geolocate(b_box, type = "bbox") |>
  apply_profile(ALA) |>
  galah_filter(year >= base_year) |>
  galah_filter(month >= update_month) |>
  atlas_occurrences()


setdiff(occurence_updates$eventDate, base_occs$eventDate)
