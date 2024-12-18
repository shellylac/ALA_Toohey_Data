
#> Info on the the ALA profile is here
#> https://support.ala.org.au/support/solutions/articles/6000240256-getting-started-with-the-data-profiles

# Useful tools
# fields <- show_all(fields)
# search_fields("date")


# update occurences function ----
get_occurrences <- function(year, month, geo_limit){
  galah::galah_call() |>
    galah::galah_identify(c("reptilia", "birds", "mammals")) |>
    galah::galah_group_by(species) |>
    galah::galah_geolocate(geo_limit) |>
    galah::apply_profile(ALA) |>
    galah::galah_filter(year >= as.numeric(year)) |>
    galah::galah_filter(month >= as.numeric(month)) |>
    galah::atlas_occurrences()
}

# Tidy the ALA data
tidy_ala_data <- function(data){
  new_data_formatted <- data |>
    dplyr::mutate(decimalLatitude = round(as.numeric(decimalLatitude), 4),
           decimalLongitude = round(as.numeric(decimalLongitude), 4)
           ) |>
    dplyr::rename(latitude = decimalLatitude, longitude = decimalLongitude) |>
    # mutate(eventDate = if_else(grepl(" ", eventDate),
    #                            lubridate::ymd_hms(eventDate, tz = "Australia/Brisbane"),
    #                            eventDate)
    #        ) |>
    # There are some taxon concept ids that aren't url's
    dplyr::filter(grepl("https://biodiversity.org.au.*", taxonConceptID)) |>
    tidyr::separate_wider_delim(eventDate,
                         delim = " ",
                         names = c("eventDate", "eventTime"),
                         too_few = "align_start",
                         too_many = "drop")
  return(new_data_formatted)
}

# Tidy the API data
tidy_api_newoccs <- function(data){
  new_data_formatted <- data |>
    tidyr::drop_na(any_of(c("time_observed_at",
                            "location",
                            "taxon.name",
                            "taxon.preferred_common_name",
                            "taxon.iconic_taxon_name")))  |>
    dplyr::rename(eventDate = time_observed_at,
                  vernacular_name = taxon.preferred_common_name,
                  class = taxon.iconic_taxon_name) |>
    # Need to cast time to brisbane timezone (not UTC time)
    dplyr::mutate(dataResourceName = "iNaturalist Australia",
                  scientificName = taxon.name,
                  eventDate = lubridate::ymd_hms(eventDate, tz = "Australia/Brisbane")
    ) |>
    tidyr::separate_wider_delim(location, delim = ",",
                                names = c("latitude", "longitude")) |>
    dplyr::mutate(decimalLatitude = round(as.numeric(latitude), 4),
                  decimalLongitude = round(as.numeric(longitude), 4)
    ) |>
    # Round latitude/longitude so that they match with new updates later on
    dplyr::mutate(dplyr::across(dplyr::where(is.numeric), ~ round(.x, digits = 4))) |>
    tidyr::separate_wider_delim(eventDate,
                                delim = " ",
                                names = c("eventDate", "eventTime"),
                                too_few = "align_start",
                                too_many = "drop")

  return(new_data_formatted)
}


# Get and add cladistics to occurrence data and wrangle ----
add_cladistics <- function(occ_data, clad_data, type){

  if (type == "ALA") {
    # Get cladistics

    occ_data_clads <- occ_data |>
      dplyr::left_join(clad_data, by = c("scientificName" = "search_term")) |>
      # For some reason these species names aren't given a vernacular name - do it manually
      # "Tachyglossus aculeatus"   "Tropidonophis mairii"     "Colluricincla rufogaster"
      dplyr::mutate(vernacular_name = dplyr::case_match(species,
                                          "Tachyglossus aculeatus" ~ "Short-beaked Echidna",
                                          "Tropidonophis mairii" ~ "Common Keelback",
                                          "Colluricincla rufogaster" ~ "Rufous Shrikethrush",
                                          .default = vernacular_name)) |>
      # There may be some rows without species level info - remove
      dplyr::filter(!is.na(species)) |>
      # select final columns
      dplyr::select(c("scientificName", "latitude", "longitude", "eventDate",
               "eventTime", "dataResourceName", "scientific_name",
               "taxon_concept_id", "class", "order",
               "family", "genus", "species", "vernacular_name")) |>
      dplyr::arrange(eventDate, eventTime, species, latitude, longitude) |>
      dplyr::distinct()


    } else {

      occ_data_clads <- occ_data |>
        dplyr::left_join(clad_data |> select(search_term, scientific_name,
                                           taxon_concept_id, order,
                                           family, genus, species),
                  by = c("taxon.name" = "search_term")) |>
        dplyr::select(c("scientificName", "latitude", "longitude", "eventDate",
                 "eventTime", "dataResourceName", "scientific_name",
                 "taxon_concept_id", "class", "order",
                 "family", "genus", "species", "vernacular_name")) |>
        dplyr::arrange(eventDate, eventTime, species, latitude, longitude) |>
        dplyr::distinct()
      }
  return(occ_data_clads)
}


# Get log file name
get_log_filename <- function(){
  today <- format(Sys.Date(), "%d-%m-%Y")
  log_filename <- paste0("./logs/", "update-", today, ".log")
  return(log_filename)
}


# Construct query string for iNat API
construct_api_query <- function(taxa_ids, min_date, max_date){
  # taxa_ids <- c(3, 40151, 26036)  # Birds, Mammals, Reptiles
  taxon_id_str <- paste0("taxon_id=", taxa_ids, collapse = "&")

  # Build the API query string
  query_str <- paste(
    taxon_id_str,
    paste0("d1=", as.character(min_date)),
    paste0("d2=", as.character(max_date)),
    "order=desc",
    "order_by=created_at",
    "per_page=200",
    paste0("swlat=", swlat),
    paste0("swlng=", swlng),
    paste0("nelat=", nelat),
    paste0("nelng=", nelng),
    sep = "&"
  )
  return(query_str)
  }


# Function to fetch a single page from the API
fetch_page <- function(base_url, query_str, page_num) {
  # Append page parameter
  full_url <- paste0(base_url, "?", query_str, "&page=", page_num)
  resp <- httr::GET(full_url)
  if (status_code(resp) != 200) {
    stop("Failed to retrieve data. HTTP Status: ", status_code(resp))
  }
  json_data <- httr::content(resp, as = "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(json_data, flatten = TRUE)
  return(parsed)
}

# Function to do the spatial interaction between bounding box occs and toohey boundary
do_spatial_intersect <- function(occ_data, boundary_shapefile){

  # Convert the new_occs data (which has lat/lon fields) into an sf object: EPSG:4326 = WGS84
  sf_new_occs <- sf::st_as_sf(occ_data, coords = c("longitude", "latitude"), crs = 4326)

  # Spatially intersect with your polygon to keep only the observations inside the polygon
  occs_geolimited <- sf_new_occs |> sf::st_intersection(boundary_shapefile)

  # Extract coordinates
  coords <- st_coordinates(occs_geolimited)

  # Add the longitude/latitude columns
  occs_geolimited$longitude <- coords[, 1]
  occs_geolimited$latitude <- coords[, 2]

  # Drop the geometry to return a regular data frame
  occs_geolimited_nonspatial <- occs_geolimited |>
    st_drop_geometry() |>
    select(-c("Name", "descriptio", "timestamp", "begin", "end", "altitudeMo",
              "tessellate", "extrude", "visibility", "drawOrder", "icon")) |>
    select("eventDate", "eventTime", "latitude", "longitude", "taxon.name",
           "vernacular_name", "class", "taxon.wikipedia_url", "dataResourceName",
           "scientificName")

  return(occs_geolimited_nonspatial)
  }

