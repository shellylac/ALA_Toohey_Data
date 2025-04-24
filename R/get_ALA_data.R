#===============================================================================
# Script Name: get_ALA_data.R
# Description: Downloads and processes species occurrence data from the Atlas of
#              Living Australia (ALA) for Toohey Forest, Brisbane. Uses the galah
#              package to interface with ALA and spatial data to define the area
#              of interest.
#
# Outputs: Species occurrence data for Toohey Forest area
#===============================================================================

{
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
}


#.......................................................
# Source functions ----
#.......................................................
source("./R/functions.R")


#.......................................................
# Set logging ----
#.......................................................

logfile <- get_log_filename(type = "ala")
tmp <- file(logfile, open = "wt")
sink(tmp, type = "message")
sink(tmp, type = "output")

#.......................................................
# Read in the Toohey Forest Boundary shapefile to limit occurrences
#.......................................................
toohey_outline <- sf::st_read("./spatial_data/toohey_forest_boundary.shp")


#.......................................................
# Configure ALA ----
#.......................................................
galah::galah_config(
  atlas = "Australia",
  email = "shelly.lachish@csiro.au",
  download_reason_id = "citizen science"
)


#.......................................................
# Set parameters for ALA download
#.......................................................
years_past = 9
this_year <- lubridate::year(Sys.Date())
start_year <- this_year - years_past


#.......................................................
# Get occurrences of all reptiles, birds and mammals, amphibians for past 5 years
#.......................................................
toohey_occurrences <- get_occurrences(
  start_year = start_year,
  start_month = 1,
  geo_limit = toohey_outline
)

#.......................................................
# Wrangle data
#.......................................................

toohey_occurrences_formatted <- tidy_ala_data(toohey_occurrences)


# Get cladistics dataset
ala_clad_data <- galah::search_taxa(unique(
  toohey_occurrences_formatted$scientificName
)) |>
  distinct()

#.......................................................
# Get cladistics - Join cladistics to this and filter to remove duplicates
#.......................................................
occ_cladistics <- add_cladistics(
  occ_data = toohey_occurrences_formatted,
  clad_data = ala_clad_data,
  type = "ALA"
) |>
  # There was a single row with NA for vernacular name
  # Drop rows where species or vernacular_name are NA
  tidyr::drop_na(c(species, vernacular_name))

#.......................................................
# Get Wiki URLS and Images
#.......................................................
wiki_urls_df <- readr::read_rds("./output_data/wiki_urls_df.rds")

image_urls_df <- readr::read_rds("./output_data/image_urls_df.rds")

#.......................................................
# Add wikis and images
#.......................................................

occ_cladistics_wikiurls <- occ_cladistics |>
  dplyr::left_join(wiki_urls_df, by = "species") |>
  dplyr::mutate(
    wikipedia_url = dplyr::if_else(
      is.na(wikipedia_url),
      construct_wiki_url(species = species),
      wikipedia_url
    )
  ) |>
  dplyr::left_join(image_urls_df, by = c("wikipedia_url" = "wiki_url")) |>
  # Process each row individually
  rowwise() |>
  mutate(
    image_url = if (is.na(image_url)) {
      safe_get_infobox_image(wikipedia_url)
    } else {
      image_url
    }
  ) |>
  ungroup()


#.......................................................
# Run tests to check format of occ_cladistics_wikiurls ----
#.......................................................
message("Running test suite ...")
test_summary <- testthat::test_file("./R/get_alaoccs_testQA.R")[[1]]$results
test_results <- purrr::map_chr(test_summary, ~ attr(.x, "class")[1])

# Row bind and save (overwrite) ----
if (any(test_results == "expectation_failure")) {
  stop("Data structure tests failed. Please fix the issues before proceeding.")

} else {
  message("\nAll tests passed. Proceeding with further analysis.")
}

#.......................................................
# Print status to log
#.......................................................
message(paste0("\n\nTotal number of occurrences in data: ",
               dim(occ_cladistics_wikiurls)[1])
        )

# Get max date in updated data
message("\n\nmax date in updated: ")
print(max(occ_cladistics_wikiurls$eventDate))

# Get notification about any missing Wiki URLs
wikiurl_na <- which(is.na(occ_cladistics_wikiurls$wikipedia_url))
message("\n\nThese species are missing wiki URLs - created default URLs: ")
print(occ_cladistics_wikiurls$species[wikiurl_na])

# Get notification about any missing image URLs
imageurl_na <- which(is.na(occ_cladistics_wikiurls$image_url))
message("\n\nThese species are missing image URLs: ")
print(occ_cladistics_wikiurls$species[imageurl_na])


#.......................................................
# Save this dataset as the base data -
#.......................................................
readr::write_rds(
  occ_cladistics_wikiurls,
  file = "./output_data/toohey_species_occurrences.rds",
  compress = "gz"
)


#Turn off logging
sink()
closeAllConnections()

