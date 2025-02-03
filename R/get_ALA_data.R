#===============================================================================
# Script Name: get_ALA_data.R
# Description: Downloads and processes species occurrence data from the Atlas of
#              Living Australia (ALA) for Toohey Forest, Brisbane. Uses the galah
#              package to interface with ALA and spatial data to define the area
#              of interest.
#
# Outputs: Species occurrence data for Toohey Forest area
#===============================================================================

# Configure ALA ----
galah::galah_config(atlas = "Australia",
             email = "shelly.lachish@csiro.au",
             download_reason_id = "citizen science"
             )


## Functions to extract data from the ALA Interface [galah package] ----

# Get occurrences of all reptiles, birds and mammals, amphibians for past 5 years
toohey_occurrences <- get_occurrences(year = this_year - years_past,
                                      month = 1,
                                      geo_limit = toohey_outline)
toohey_occurrences_formatted <- tidy_ala_data(toohey_occurrences)


# Get cladistics dataset
ala_clad_data <- galah::search_taxa(unique(toohey_occurrences_formatted$scientificName)) |> distinct()

# Get cladistics - Join cladistics to this and filter to remove duplicates
occ_cladistics <- add_cladistics(occ_data = toohey_occurrences_formatted,
                                 clad_data = ala_clad_data,
                                 type = "ALA") |>
  # There was a single row with NA for vernacular name
  # Drop rows where species or vernacular_name are NA
  tidyr::drop_na(c(species, vernacular_name))

# Get Wiki URLS
wiki_urls_list <- readr::read_rds("./output_data/wiki_urls.rds")
occ_cladistics_wikiurls <- occ_cladistics |>
  left_join((wiki_urls_list |> select(species, wikipedia_url)),
            by = "species")


# Save this dataset as the base data - (the github action will just run the update script in the future)
readr::write_rds(occ_cladistics_wikiurls,
          file = "./output_data/toohey_species_occurrences.rds",
          compress = "gz")

