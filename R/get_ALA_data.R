library(here)
library(galah)
library(tidyverse)
library(sf)


# Source functions
source(here("R", "functions.R"))

# Configure ALA
galah_config(atlas = "Australia",
             email = "shelly.lachish@csiro.au",
             download_reason_id = "citizen science", #ID 11
             caching = T,
             directory = here("cache") # Use this if need to set cahce across R sessions
             )

# Useful tools
# fields <- show_all(fields)
# search_fields("date")

# Set params
curr_year <- lubridate::year(Sys.Date())
min_year <- curr_year - 5

#> Define the Toohey bounding box
# nw = -27.531057, 153.035337
# ne = -27.537956, 153.082805
# se = -27.561382, 153.078571
# sw = -27.555471, 153.030074

b_box <- sf::st_bbox(c(xmin = 153.030074, xmax = 153.082805,
                       ymin = -27.531057, ymax = -27.561382),
                     crs = sf::st_crs("WGS84"))


#> Info on the the ALA profile is here
#> https://support.ala.org.au/support/solutions/articles/6000240256-getting-started-with-the-data-profiles

## Function to extract data from the ALA Interface [galah package] ----

# Get counts of species in taxa list
counts <- galah_call() |>
  galah_identify(c("reptilia", "birds", "mammals")) |>
  galah_group_by(species) |>
  galah_geolocate(b_box, type = "bbox") |>
  apply_profile(ALA) |>
  galah_filter(year >= min_year) |>
  atlas_counts()

# Get cladistics
cladistics <- search_taxa(counts$species)

# Add cladistics to counts
toohey_species_counts <- counts |>
  mutate(common_name = cladistics$vernacular_name,
         class = cladistics$class,
         order = cladistics$order,
         family = cladistics$family,
         genus = cladistics$genus,
         scientific_name = cladistics$scientific_name,
         taxon_id = cladistics$taxon_concept_id) |>
  # For some reason this one is missing from the auto populatio for common name
  mutate(common_name =
           if_else(species == "Colluricincla rufogaster", "Rufous Shrikethrush",
                   common_name)
         )

# Get occurrences of all reptiles, birds and mammals for past 5 years
toohey_occurrences <- galah_call() |>
  galah_identify(c("reptilia", "birds", "mammals")) |>
  galah_group_by(species) |>
  galah_geolocate(b_box, type = "bbox") |>
  apply_profile(ALA) |>
  galah_filter(year >= min_year) |>
  atlas_occurrences()

# Join cladistics to this and filter
toohey_occs_cladistics <- toohey_occurrences |>
  # Need to limit the scientific names to just two words (better matches with count_cladistics)
  mutate(short_sci_name = remove_parenthesis_text(scientificName),
         short_sci_name = remove_third_if_duplicate(short_sci_name),
         short_sci_name = keep_first_two_words(short_sci_name)) |>
  left_join(select(toohey_species_counts, -count), by = c("short_sci_name" = "species")) |>
  # Now remove any records without a common name
  filter(!is.na(common_name)) |>
  rename(species = short_sci_name) |>
  select(-scientificName, -taxon_id) #-recordID


# Save these datasets - In future just add updates
write_rds(toohey_species_counts,
          file = here("output_data", "toohey_species_counts.rds"),
          compress = "gz")

write_rds(toohey_occs_cladistics,
          file = here("output_data", "toohey_species_occurences.rds"),
          compress = "gz")

