# This is sript gets wikipedia information for all species from iNat API

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
  min_date = "01/01/2016",
  max_date = Sys.Date()
)

# Base URL for observations -----
base_url <- "https://api.inaturalist.org/v1/observations"

wiki_data <- data.frame()
page_num <- 1

while (TRUE) {
  parsed <- fetch_page(base_url, query_str, page_num)
  # If there are no new occurrences  - then break loop
  if (is.null(parsed$results$id)) break

  wiki_fields <- c(
    "taxon.name",
    "taxon.preferred_common_name",
    "taxon.iconic_taxon_name",
    "taxon.wikipedia_url"
  )

  wiki_existing_fields <- wiki_fields[wiki_fields %in% names(parsed$results)]

  wiki_observations_df <- parsed$results[, wiki_existing_fields, drop = FALSE]
  wiki_data <- dplyr::bind_rows(wiki_data, wiki_observations_df)

  page_num <- page_num + 1
}


wiki_urls <- wiki_data |>
  distinct() |>
  mutate(
    wikipedia_url = case_match(
      taxon.name,
      "Litoria caerulea" ~
        "https://en.wikipedia.org/wiki/Australian_green_tree_frog",
      "Litoria balatus" ~
        "https://en.wikipedia.org/wiki/Slender_bleating_tree_frog",
      "Acridotheres tristis tristis" ~
        "http://en.wikipedia.org/wiki/Common_myna",
      "Alectura lathami lathami" ~
        "http://en.wikipedia.org/wiki/Australian_brushturkey",
      "Cryptoblepharus pulcher pulcher" ~
        "https://en.wikipedia.org/wiki/Cryptoblepharus_pulcher",
      "Cryptoblepharus virgatus" ~
        "https://en.wikipedia.org/wiki/Cryptoblepharus_virgatus",
      "Eolophus roseicapilla albiceps" ~ "http://en.wikipedia.org/wiki/Galah",
      "Eudynamys orientalis cyanocephalus" ~
        "https://en.wikipedia.org/wiki/Pacific_koel",
      "Gymnorhina tibicen tibicen" ~
        "https://en.wikipedia.org/wiki/Australian_magpie",
      "Intellagama lesueurii lesueurii" ~
        "https://en.wikipedia.org/wiki/Australian_water_dragon",
      "Malurus melanocephalus melanocephalus" ~
        "http://en.wikipedia.org/wiki/Red-backed_fairywren",
      "Ninox boobook boobook" ~
        "https://en.wikipedia.org/wiki/Australian_boobook",
      "Pardalotus punctatus punctatus" ~
        "http://en.wikipedia.org/wiki/Spotted_pardalote",
      "Podargus strigoides strigoides" ~
        "http://en.wikipedia.org/wiki/Tawny_frogmouth",
      "Porphyrio melanotus melanotus" ~
        "http://en.wikipedia.org/wiki/Australasian_swamphen",
      "Sphecotheres vieilloti vieilloti" ~
        "http://en.wikipedia.org/wiki/Australasian_figbird",
      "Tachyglossus aculeatus aculeatus" ~
        "http://en.wikipedia.org/wiki/Short-beaked_echidna",
      "Tropidonophis mairii mairii" ~
        "https://en.wikipedia.org/wiki/Tropidonophis_mairii",
      "Vulpes vulpes crucigera" ~ "http://en.wikipedia.org/wiki/Red_fox",
      .default = taxon.wikipedia_url
    ),
    # For each element of taxon.name, keep the first two “words” only
    species = sub("(\\w+\\s+\\w+).*", "\\1", taxon.name)
  ) |>
  distinct(species, .keep_all = TRUE)

#..................................................................................
# # This was a one off to find the missing Wikipages I needed after the above
# missing_species_urls <- occ_cladistics_wikiurls |>
#   filter(is.na(wikipedia_url)) |>
#   distinct(species, vernacular_name) |>
#   mutate(wikipedia_url = paste0(
#     "https://en.wikipedia.org/wiki/",
#     gsub(" ", "_", stringr::str_to_sentence(vernacular_name))
#     ))
#
# readr::write_rds(missing_species_urls,
#                  file = "./output_data/missing_species_urls.rds",
#                  compress = "gz")
#..................................................................................

missing_species_urls <- readr::read_rds(
  "./output_data/missing_species_urls.rds"
)

wiki_urls_list <- wiki_urls |>
  select(species, wikipedia_url) |>
  bind_rows(missing_species_urls) |>
  distinct(species, .keep_all = TRUE)


readr::write_rds(
  wiki_urls_list,
  file = "./output_data/wiki_urls.rds",
  compress = "gz"
)
