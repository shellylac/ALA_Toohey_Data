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

# SETS DEFAULT colours for plotly plots----
STATS_BLUE = "#8080FF"
STATS_RED = "#FF8080"
STATS_ORANGE = "#FFD5A5"
STATS_GREEN = "#B3FFB3"


#.......................................................
# Set logging ----
#.......................................................

# Set logging ----
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
# years_past = 9
this_year <- lubridate::year(Sys.Date())
start_year <- 2016

#.......................................................
# Get occurrences of all reptiles, birds and mammals, amphibians
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


# Get cladistics dataset - add taxonomic information
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
  # Drop any rows where species or vernacular_name are NA
  tidyr::drop_na(c(species, vernacular_name))

#.......................................................
# Get Wiki URLS and Images datasets (created by previously run scripts)
#.......................................................
wiki_urls_df <- readr::read_rds("./output_data/wiki_urls.rds")

image_urls_df <- readr::read_rds("./output_data/image_urls_df.rds")

#.......................................................
# Add wikis and images
#.......................................................

occ_cladistics_wikiurls <- occ_cladistics |>
  # Revert lat/lon to numeric fields
  dplyr::mutate(
    latitude = as.numeric(latitude),
    longitude = as.numeric(longitude)
  ) |>
  dplyr::left_join(wiki_urls_df, by = "species") |>
  dplyr::mutate(
    wikipedia_url = dplyr::if_else(
      is.na(wikipedia_url),
      construct_wiki_url(species = species),
      wikipedia_url
    )
  ) |>
  dplyr::left_join(image_urls_df, by = c("wikipedia_url" = "wiki_url")) |>
  # Process each row individually - to add any missing image urls
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


if (any(test_results == "expectation_failure")) {
  stop("Data structure tests failed. Please fix the issues before proceeding.")
} else {
  message("\nAll tests passed. Proceeding with further analysis.")
}

#.......................................................
# Print status to log
#.......................................................
message(paste0(
  "\n\nTotal number of occurrences in data: ",
  dim(occ_cladistics_wikiurls)[1]
))

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

toohey_species_occurrences <- occ_cladistics_wikiurls |>
  # Add common class names - this bit is for the shiny app
  dplyr::mutate(
    class_common = case_match(
      class,
      "Aves" ~ "Birds",
      "Mammalia" ~ "Mammals",
      "Reptilia" ~ "Reptiles",
      "Amphibia" ~ "Amphibians"
    ),
    class_common = factor(
      class_common,
      levels = c("Birds", "Mammals", "Reptiles", "Amphibians")
    ),
    # Add colour for trend plots (based on class_common)
    plot_colour = case_match(
      class_common,
      "Birds" ~ STATS_BLUE,
      "Mammals" ~ STATS_RED,
      "Reptiles" ~ STATS_ORANGE,
      "Amphibians" ~ STATS_GREEN
    ),
    # Add formatted dates for stats plots
    year = as.factor(lubridate::year(eventDate)),
    month = lubridate::month(eventDate, label = TRUE),
    hour = as.factor(lubridate::hour(hms(eventTime)))
  )

# Generate the species list dataset ----
species_list <- toohey_species_occurrences |>
  dplyr::group_by(
    class_common,
    class,
    order,
    family,
    species,
    vernacular_name,
    wikipedia_url,
    image_url
  ) |>
  count(name = "Sightings") |>
  ungroup() |>
  rename(Class = class, `Common name` = vernacular_name) |>
  mutate(
    Taxonomy = paste0(
      "<p style=\"font-size:14px;\">",
      "<a href=\"",
      wikipedia_url,
      "\" target=\"_blank\">",
      `Common name`,
      "</a>",
      "<br>",
      "<b>Class</b>: ",
      Class,
      "<br>",
      "<b>Order</b>: ",
      order,
      "<br>",
      "<b>Family</b>: ",
      family,
      "<br>",
      "<b>Species</b>: <em>",
      species,
      "</em></p>"
    ),
    Image = paste0(
      "<img src=\"",
      image_url,
      "\" height=\"120\" data-toggle=\"tooltip\" data-placement=\"center\" title=\"",
      `Common name`,
      "\"></img>",
      "</p>"
    )
  ) |>
  arrange(
    desc(Sightings),
    factor(Class, levels = c('Aves', 'Mammalia', 'Reptilia', 'Amphibia')),
    `Common name`
  ) |>
  select(Class, Taxonomy, Image, Sightings)


# Save/overwrite the current occurrence data with this update
readr::write_rds(
  toohey_species_occurrences,
  file = "./output_data/toohey_species_occurrences.rds",
  compress = "gz"
)

# Save/overwrite the current species list data with this update
readr::write_rds(
  species_list,
  file = "./output_data/toohey_species_list.rds",
  compress = "gz"
)

# Turn off logging ----
sink(type = "message")
sink(type = "output")
close(tmp)
