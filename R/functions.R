#> Info on the the ALA profile is here
#> https://support.ala.org.au/support/solutions/articles/6000240256-getting-started-with-the-data-profiles
#>

# Useful tools
# fields <- show_all(fields)
# search_fields("date")

#' Get occurrences data from ALA ----
#' This function retrieves occurrences data from the Atlas of Living Australia (ALA)
#' based on the specified year, month, and geographical limit.
#' @param year Numeric. The year from which to start retrieving occurrences.
#' @param geo_limit A geographical limit for the occurrences data.
#' @return A data frame containing the occurrences data.
get_occurrences <- function(start_year, geo_limit) {
  out <- galah::galah_call() |>
    galah::galah_identify(c("Aves", "Mammalia", "Reptilia", "Amphibia")) |>
    galah::galah_geolocate(geo_limit) |>
    galah::galah_filter(
      year >= start_year
    ) |>
    galah::apply_profile(ALA) |>
    galah::atlas_occurrences()
  return(out)
}

# Function to force latitude/longitude to x decimals places
sprintf_fixed <- function(x, n) {
  sprintf(paste0("%.", n, "f"), x)
}

# Tidy the ALA data ----
tidy_ala_data <- function(data) {
  new_data_formatted <- data |>
    # Using sprintf_fixed to truncate decimal places - for duplication removal later
    dplyr::mutate(
      decimalLatitude = sprintf_fixed(decimalLatitude, 5),
      decimalLongitude = sprintf_fixed(decimalLongitude, 4)
    ) |>
    dplyr::rename(latitude = decimalLatitude, longitude = decimalLongitude) |>
    # There are some taxon concept ids that aren't url's
    dplyr::filter(grepl("https://biodiversity.org.au.*", taxonConceptID)) |>
    tidyr::separate_wider_delim(
      eventDate,
      delim = " ",
      names = c("eventDate", "eventTime"),
      too_few = "align_start",
      too_many = "drop"
    )
  return(new_data_formatted)
}


# Tidy the iNat API data ----
tidy_api_newoccs <- function(data) {
  new_data_formatted <- data |>
    tidyr::drop_na(any_of(c("time_observed_at", "location", "taxon.name"))) |>
    dplyr::rename(
      eventDate = time_observed_at,
      vernacular_name = taxon.preferred_common_name,
      class = taxon.iconic_taxon_name
    ) |>
    dplyr::mutate(
      dataResourceName = "iNaturalist Australia",
      scientificName = taxon.name,
      # Need to cast time to Brisbane time zone (not UTC time)
      eventDate = lubridate::ymd_hms(eventDate, tz = "Australia/Brisbane")
    ) |>
    tidyr::separate_wider_delim(
      location,
      delim = ",",
      names = c("latitude", "longitude")
    ) |>
    dplyr::mutate(
      decimalLatitude = round(as.numeric(latitude), 6),
      decimalLongitude = round(as.numeric(longitude), 6)
    ) |>
    tidyr::separate_wider_delim(
      eventDate,
      delim = " ",
      names = c("eventDate", "eventTime"),
      too_few = "align_start",
      too_many = "drop"
    )

  return(new_data_formatted)
}


# Get and add cladistics to occurrence data and wrangle ----
add_cladistics <- function(occ_data, clad_data, type) {
  if (type == "ALA") {
    # Get cladistics

    occ_data_clads <- occ_data |>
      dplyr::left_join(
        clad_data,
        by = dplyr::join_by("scientificName" == "search_term")
      ) |>
      # For some reason these species names aren't given a vernacular name - do it manually
      dplyr::mutate(
        vernacular_name = dplyr::case_match(
          species,
          "Tachyglossus aculeatus" ~ "Short-beaked Echidna",
          "Tropidonophis mairii" ~ "Common Keelback",
          "Colluricincla rufogaster" ~ "Rufous Shrikethrush",
          .default = vernacular_name
        )
      ) |>
      # There will be rows without species level info (normally because the scientifiName is only genus level)
      dplyr::filter(!is.na(species)) |>
      # select final columns
      dplyr::select(c(
        "scientificName",
        "latitude",
        "longitude",
        "eventDate",
        "eventTime",
        "dataResourceName",
        "scientific_name",
        "taxon_concept_id",
        "class",
        "order",
        "family",
        "genus",
        "species",
        "vernacular_name"
      )) |>
      dplyr::arrange(eventDate, eventTime, species, latitude, longitude) |>
      dplyr::distinct()
  } else {
    occ_data_clads <- occ_data |>
      dplyr::left_join(
        clad_data |>
          select(
            search_term,
            scientific_name,
            taxon_concept_id,
            order,
            family,
            genus,
            species
          ),
        by = dplyr::join_by("taxon.name" == "search_term")
      ) |>
      dplyr::select(
        scientificName,
        latitude,
        longitude,
        eventDate,
        eventTime,
        dataResourceName,
        scientific_name,
        taxon_concept_id,
        class,
        order,
        family,
        genus,
        species,
        vernacular_name,
        taxon.wikipedia_url
      ) |>
      dplyr::rename(wikipedia_url = taxon.wikipedia_url) |>
      dplyr::arrange(eventDate, eventTime, species, latitude, longitude) |>
      dplyr::distinct()
  }
  return(occ_data_clads)
}


# Construct assumed Wikipedia URL ----
construct_wiki_url <- function(species) {
  wiki_url <- paste0("https://en.wikipedia.org/wiki/", gsub(" ", "_", species))
}


# Get log file name ----
get_log_filename <- function(type = c("inat", "ala")) {
  today <- format(Sys.Date(), "%Y-%m-%d")
  log_filename <- paste0("./logs/", type, "-update-", today, ".log")
  return(log_filename)
}


# Construct query string for iNat API ----
construct_api_query <- function(
  taxa_ids,
  min_date,
  max_date,
  swlat,
  swlng,
  nelat,
  nelng
) {
  # taxa_ids <- c(3, 40151, 26036, 20978)  # Birds, Mammals, Reptiles, Amphibia
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
  if (httr::status_code(resp) != 200) {
    stop("Failed to retrieve data. HTTP Status: ", status_code(resp))
  }
  json_data <- httr::content(resp, as = "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(json_data, flatten = TRUE)
  return(parsed)
}

# Function to do the spatial interaction between bounding box occs and toohey boundary
do_spatial_intersect <- function(occ_data, boundary_shapefile) {
  # Convert the new_occs data (which has lat/lon fields) into an sf object: EPSG:4326 = WGS84
  sf_new_occs <- sf::st_as_sf(
    occ_data,
    coords = c("longitude", "latitude"),
    crs = 4326
  )

  # Spatially intersect with our polygon to keep only the observations inside the polygon
  occs_geolimited <- sf_new_occs |> sf::st_intersection(boundary_shapefile)

  # Extract coordinates
  coords <- sf::st_coordinates(occs_geolimited)

  # Add the longitude/latitude columns
  occs_geolimited$longitude <- coords[, 1]
  occs_geolimited$latitude <- coords[, 2]

  # Drop the geometry to return a regular data frame
  occs_geolimited_nonspatial <- occs_geolimited |>
    sf::st_drop_geometry() |>
    dplyr::select(
      -c(
        "Name",
        "descriptio",
        "timestamp",
        "begin",
        "end",
        "altitudeMo",
        "tessellate",
        "extrude",
        "visibility",
        "drawOrder",
        "icon"
      )
    )

  return(occs_geolimited_nonspatial)
}


# Function to correct different vernacular name spellings ----
fix_common_names <- function(string, corrections_file) {
  corrected_common_names <- tibble::tibble(
    .row_id = seq_along(string),
    input_name_wrong = string
  ) |>
    dplyr::left_join(
      corrections_file,
      by = dplyr::join_by(input_name_wrong)
    ) |>
    dplyr::arrange(.row_id) |>
    dplyr::mutate(
      corrected_common_name = dplyr::coalesce(
        output_name_good,
        input_name_wrong
      )
    ) |>
    dplyr::pull(corrected_common_name)
  return(corrected_common_names)
}


# Construct Google Maps URL string
create_google_maps_url <- function(latitude, longitude) {
  # Format coordinates with 6 decimal places
  lat <- format(round(latitude, 6), nsmall = 6)
  lon <- format(round(longitude, 6), nsmall = 6)

  # Construct Google Maps URL
  sprintf("https://www.google.com/maps?q=%s,%s", lat, lon)
}


# Function to scrape the first infobox image URL from a Wikipedia page with error handling
get_infobox_image <- function(url) {
  tryCatch(
    {
      # Pause briefly between requests (adds a one-second pause between requests)
      Sys.sleep(1)

      # Fetch the page with a user agent to mimic a regular browser
      # By using GET() and setting a user agent, helps avoid potential blocks from the server
      # that might occur if many requests come in rapid succession from a script
      response <- httr::GET(
        url,
        httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
      )

      # Check for HTTP errors (e.g., 404, 500, etc.)
      if (httr::http_error(response)) {
        warning("HTTP error: ", httr::status_code(response), " for URL: ", url)
        return(NA_character_)
      }

      # Parse the page's HTML content
      page <- rvest::read_html(response)

      # Select the infobox table with both "infobox" and "biota" classes
      infobox <- page |> rvest::html_node("table.infobox.biota")
      if (is.null(infobox)) {
        warning("Infobox not found for URL: ", url)
        return(NA_character_)
      }

      # Select the first image element within the infobox
      img <- infobox |> rvest::html_node("img")
      if (is.null(img)) {
        warning("No image found in the infobox for URL: ", url)
        return(NA_character_)
      }

      # Extract the 'src' attribute from the image tag
      img_src <- img |> rvest::html_attr("src")
      # Prepend "https:" if the src is protocol-relative
      if (stringr::str_starts(img_src, "//")) {
        img_src <- paste0("https:", img_src)
      }

      img_src
    },
    error = function(e) {
      warning("Error processing URL: ", url, ": ", e$message)
      NA_character_
    }
  )
}

# Optionally, create a safe version of the function using purrr::possibly()
# possibly() wraps function so that any error returns a default value (NA_character_)
safe_get_infobox_image <- purrr::possibly(
  get_infobox_image,
  otherwise = NA_character_
)

# Function to create a subset for species in Tara Toohey part of reserve
create_select_spp_df <- function(data, spp_list) {
  select_data <- data |>
    dplyr::filter(eventDate >= Sys.Date() - 2, vernacular_name %in% spp_list) |>
    # apply the broad spatial filter for Tara Toohey
    dplyr::filter(
      latitude <= -27.530755,
      latitude >= -27.541794,
      longitude >= 153.033571,
      longitude <= 153.039194
    ) |>
    # Keep selected cols
    dplyr::select(vernacular_name, eventDate, eventTime, google_maps_url)

  return(select_data)
}

# Good to know
# ..............
# Regex to get first two words from a string (e.g. scientificName --> species)
# sub("(\\w+\\s+\\w+).*", "\\1", scientificName), species))

#
# decimalplaces <- function(x) {
#   if (abs(x - round(x)) > .Machine$double.eps^0.5) {
#     nchar(strsplit(sub('0+$', '', as.character(x)), ".", fixed = TRUE)[[1]][[2]])
#   } else {
#     return(0)
#   }
# }

# count_decimal_places <- function(x){
#   sapply(
#     format(x, scientific = FALSE, trim = TRUE),    # get a clean non-sci string
#     function(z) {
#       if (!grepl("\\.", z)) return(0L)            # no “.” → 0 places
#       nchar(sub(".*\\.", "", z))                  # drop everything up to “.”, count rest
#     }
#   )
# }

# Function to work out which mismatched common name should be retained
count_mismatched_names <- function(data, bad_name) {
  count_dat <- data |>
    dplyr::filter(species %in% bad_name) |>
    dplyr::count(vernacular_name, name = "count") |>
    dplyr::arrange(count)
  dput(count_dat$vernacular_name)
}

# list <- c("Demansia psammophis", "Pseudocheirus peregrinus")
# results_df <- map_dfr(list, \(bad) {
#   vern <- count_mismatched_names(updated_occ_data_wikiurls, bad)
#   tibble(inputbad_name = vern[1], outpugood_name = vern[2])
# })
