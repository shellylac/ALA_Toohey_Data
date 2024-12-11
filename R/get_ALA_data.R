library(here)
library(galah)
library(tidyverse)
library(purrr)
library(sf)

# Configure ALA
galah_config(atlas = "Australia",
             email = "shelly.lachish@csiro.au",
             download_reason_id = "citizen science"
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

# Get occurrences of all reptiles, birds and mammals for past 5 years
toohey_occurrences <- galah_call() |>
  galah_identify(c("reptilia", "birds", "mammals")) |>
  galah_group_by(species) |>
  galah_geolocate(b_box, type = "bbox") |>
  apply_profile(ALA) |>
  galah_filter(year >= min_year) |>
  atlas_occurrences()

# Get cladistics
occ_cladistics <- search_taxa(unique(toohey_occurrences$scientificName))

# Join cladistics to this and filter
toohey_occs_cladistics <- toohey_occurrences |>
  left_join(occ_cladistics, by = c("scientificName" = "search_term")) |>
  # For some reason these species names aren't given a vernacular name - do it manually
  # "Tachyglossus aculeatus"   "Tropidonophis mairii"     "Colluricincla rufogaster"
  mutate(vernacular_name = case_match(species,
                                      "Tachyglossus aculeatus" ~ "Short-beaked Echidna",
                                      "Tropidonophis mairii" ~ "Common Keelback",
                                      "Colluricincla rufogaster" ~ "Rufous Shrikethrush",
                                      .default = vernacular_name)) |>
  # There are some rows without species level info - remove
  filter(!is.na(species)) |>
  # Remove unecessary rows
  select(-c(recordID, taxonConceptID, occurrenceStatus,
            scientific_name_authorship, match_type, rank,
            kingdom, phylum, issues)) |>
  distinct()


#Get counts by species
toohey_counts_cladistics <- toohey_occs_cladistics |>
  group_by(class, order, family, genus, species, vernacular_name) |>
  count()

# Save these datasets - In future just add updates
write_rds(toohey_occs_cladistics,
          file = here("output_data", "toohey_species_occurences.rds"),
          compress = "gz")

write_rds(toohey_counts_cladistics,
          file = here("output_data", "toohey_species_counts.rds"),
          compress = "gz")


