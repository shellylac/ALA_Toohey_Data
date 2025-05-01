#===============================================================================
# Script Name: update_occurrences_iNatAPI.R
# Description: Updates species occurrence records for Toohey Forest by retrieving
#              most recent observations from the iNaturalist APIs to add to the previously
#              downloaded Atlas of Living Australia (ALA) observations.
#
# Input: Base occurrence dataset (./output_data/toohey_species_occurrences.rds)
# Output: Updated species occurrence records with new observations from iNaturalist
# Process: 1. Reads existing occurrence data
#         2. Determines date range for new records
#         3. Queries iNat API with spatial bounds for Toohey Forest
#         4. Cleans and wrangles new data observations (with taxonomy/cladistics)
#         5. Appends new records to base dataset with some cleaning and wrangling
#         6. Logs all the output for record keeping
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

source("./R/functions.R")

# Set logging ----

logfile <- get_log_filename(type = "inat")
tmp <- file(logfile, open = "wt")
sink(tmp, type = "message")
sink(tmp, type = "output")


# Configure ALA ----
galah::galah_config(atlas = "Australia", download_reason_id = "citizen science")

# Read in the base data ----
message("\nReading in base occurrences ...")
base_occs <- readr::read_rds("./output_data/toohey_species_occurrences.rds")
image_urls_df <- readr::read_rds("./output_data/image_urls_df.rds")


# Define date range: from max Date in base data to today
base_date <- as.Date(max(base_occs$eventDate), format = "%Y-%m-%d") - 7
max_date <- Sys.Date()

# Define bounding box - iNat API doesn't accept shapefile to geo limit -----
#> Later we will spatial intersect to limit to Toohey shapefile
nelat <- -27.5312
nelng <- 153.082
swlat <- -27.5625
swlng <- 153.0302

# Build the API query string for Taxa of interest ----
taxa_ids <- c(3, 40151, 26036, 20978) # Birds, Mammals, Reptiles, Amphibians
query_str <- construct_api_query(
  taxa_ids,
  min_date = base_date,
  max_date = max_date
)

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

  fields <- c(
    "time_observed_at",
    "location",
    "taxon.name",
    "taxon.preferred_common_name",
    "taxon.iconic_taxon_name",
    "taxon.wikipedia_url"
  )

  existing_fields <- fields[fields %in% names(parsed$results)]

  observations_df <- parsed$results[, existing_fields, drop = FALSE]
  new_occs <- dplyr::bind_rows(new_occs, observations_df)

  page_num <- page_num + 1
}

# Tidy the data and get cladistics  -----
new_occs_tidy <- tidy_api_newoccs(new_occs)


# Spatially filter (intersect) the data to retain only occurrences in our shapefile limits ----
# Read in the Toohey Forest Boundary shapefile to limit occurrences
toohey_outline <- sf::st_read("./spatial_data/toohey_forest_boundary.shp")

new_occs_toohey <- do_spatial_intersect(new_occs_tidy, toohey_outline)


# Add cladistics ----
message("Adding cladistics ...")
api_clad_data <- galah::search_taxa(new_occs_toohey$taxon.name) |> distinct()

occ_updates_cladistics <- add_cladistics(
  occ_data = new_occs_toohey,
  clad_data = api_clad_data,
  type = "iNat"
  ) |>
  # Drop rows where species or vernacular_name are NA
  # This can occur if they aren't match to cladistics in ALA
  tidyr::drop_na(c(species, vernacular_name))


# Run tests to check format of occ_updates_cladistics ----
message("Running test suite ...")
test_summary <- testthat::test_file("./R/update_occs_testQA.R")[[1]]$results
test_results <- purrr::map_chr(test_summary, ~ attr(.x, "class")[1])

# Row bind and save (overwrite) ----
if (any(test_results == "expectation_failure")) {
  stop("Data structure tests failed. Please fix the issues before proceeding.")
} else {
  message("\nAll tests passed. Proceeding with further analysis.")

  #Format lat/long and then remove duplicates from previous dataset (if any)
  new_occs_to_add <- occ_updates_cladistics |>
    dplyr::mutate(
      latitude = as.numeric(sprintf_fixed(latitude, 5)),
      longitude = as.numeric(sprintf_fixed(longitude, 4))
    ) |>
    dplyr::anti_join(
      base_occs |>
        select(latitude, longitude, eventDate, eventTime, species)
    ) |>
    # Add image urls
    dplyr::left_join(image_urls_df, by = c("wikipedia_url" = "wiki_url"))

  message(paste0(
    "\n\nNumber of new occurrences added: ",
    dim(new_occs_to_add)[1]
  ))

  # Row bind - append,
  updated_occ_data <- dplyr::bind_rows(base_occs, new_occs_to_add) |>
    # If any wikipedia links are missing fill down from same species
    group_by(species) |>
    fill(wikipedia_url, .direction = "downup") |>
    fill(image_url, .direction = "downup") |>
    ungroup() |>
    # ALA and iNat have different common name spellings/namings - this function tries to remedy most of them
    dplyr::mutate(vernacular_name = fix_common_names(vernacular_name)) |>
    # create the URL link for Google Maps (for use in the map)
    dplyr::mutate(
      google_maps_url = create_google_maps_url(latitude, longitude)
      ) |>
    # Final check to remove any NA in species column (if any)
    dplyr::filter(!is.na(species))

  message(paste0(
    "\n\nTotal number of occurrences in data: ",
    dim(updated_occ_data)[1]
  ))

  # Get notification about any missing Wiki URLs
  wikiurl_na <- which(is.na(updated_occ_data$wikipedia_url))
  message("\n\nThese species are missing wiki URLs - created default URLs: ")
  print(updated_occ_data$species[wikiurl_na])

  # Add wiki and image urls - where these are missing
  updated_occ_data_wikiurls <- updated_occ_data |>
    dplyr::mutate(
      wikipedia_url = dplyr::if_else(
        is.na(wikipedia_url),
        construct_wiki_url(species = species),
        wikipedia_url
      )
    ) |>
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

  # Get notification about any missing image URLs
  imageurl_na <- which(is.na(updated_occ_data_wikiurls$image_url))
  message("\n\nThese species are missing image URLs: ")
  print(updated_occ_data_wikiurls$species[imageurl_na])

  # Check whether there are species/common names mismatches
  n_name_mismatch <- updated_occ_data_wikiurls |>
    select(species, vernacular_name) |>
    distinct() |>
    group_by(species) |>
    count() |>
    filter(n > 1)

  if (dim(n_name_mismatch)[1] > 0) {
    message("\n\nThe following name mismatches were found: \n\n")
    print(n_name_mismatch$species)
  } else {
    message("No name mismatches")
  }

  # Get max date in updated data
  message("\n\nmax date in updated: ")
  print(max(updated_occ_data_wikiurls$eventDate))


  message("\n\nList of Tara Toohey species detected: ")
  # Define the species of interest
  my_species = c("Koala",
                 "Squirrel Glider",
                 "Feathertail Glider",
                 "Short-beaked Echidna")
  tara_toohey_df <- create_select_spp_df(data = updated_occ_data_wikiurls,
                                         spp_list = my_species)

  # ── only print when there's data ─────────────────────────────────────────────
  if (nrow(tara_toohey_df) > 0) {
    print(tara_toohey_df)
  }

  # SETS DEFAULT colours for plotly plots----
  STATS_BLUE = "#8080FF"
  STATS_RED = "#FF8080"
  STATS_ORANGE = "#FFD5A5"
  STATS_GREEN = "#B3FFB3"


  # Prepare occs data for Shiny app ----
  toohey_species_occurrences <- updated_occ_data_wikiurls |>
    # Just a catch in case an NA species gets through
    dplyr::filter(!is.na(species)) |>
    # Add common class names
    dplyr::mutate(class_common = case_match(class,
                                            "Aves" ~ "Birds",
                                            "Mammalia" ~ "Mammals",
                                            "Reptilia" ~ "Reptiles",
                                            "Amphibia" ~ "Amphibians"),
                  class_common = factor(class_common,
                                        levels = c("Birds", "Mammals",
                                                   "Reptiles", "Amphibians")
                  ),
                  # Add colour for trend plots (based on class_common)
                  plot_colour = case_match(class_common,
                                           "Birds" ~ STATS_BLUE,
                                           "Mammals" ~ STATS_RED,
                                           "Reptiles" ~ STATS_ORANGE,
                                           "Amphibians" ~ STATS_GREEN),
                  # Add formatted dates for stats plots
                  year = as.factor(lubridate::year(eventDate)),
                  month = lubridate::month(eventDate, label = TRUE),
                  hour = as.factor(lubridate::hour(hms(eventTime)))
    )


  # Generate the species list dataset ----
  species_list <- toohey_species_occurrences |>
    dplyr::group_by(class_common, class, order, family, species, vernacular_name,
                    wikipedia_url, image_url) |>
    count(name = "Sightings") |>
    ungroup() |>
    rename(Class = class,  `Common name` = vernacular_name) |>
    mutate(
      Taxonomy = paste0("<p style=\"font-size:14px;\">",
                        "<a href=\"", wikipedia_url, "\" target=\"_blank\">",
                        `Common name`, "</a>", "<br>",
                        "<b>Class</b>: ", Class, "<br>",
                        "<b>Order</b>: ", order, "<br>",
                        "<b>Family</b>: ", family, "<br>",
                        "<b>Species</b>: <em>", species,
                        "</em></p>"),
      Image = paste0("<img src=\"", image_url,
                     "\" height=\"120\" data-toggle=\"tooltip\" data-placement=\"center\" title=\"",
                     `Common name`, "\"></img>", "</p>")
    ) |>
    arrange(desc(Sightings),
            factor(Class, levels = c('Aves', 'Mammalia', 'Reptilia', 'Amphibia')),
            `Common name`) |>
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

}

#Turn off logging ----
sink()
closeAllConnections()
