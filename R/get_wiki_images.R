# Load necessary packages
library(rvest)
library(tidyverse)
library(httr)


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

# Read in the base data ----
base_occs <- readr::read_rds("./output_data/toohey_species_occurrences.rds")

# Example usage:
urls <- unique(base_occs$wikipedia_url) # You can add more URLs here

# Apply the function to each URL and collect the results
image_urls <- purrr::map_chr(urls, safe_get_infobox_image, .progress = TRUE)

image_urls_df <- data.frame(wiki_url = urls, image_url = image_urls) |>
  mutate(
    image_url = dplyr::if_else(
      wiki_url == "https://en.wikipedia.org/wiki/Ctenotus_spaldingi",
      "https://www.jcu.edu.au/__data/assets/image/0010/97372/366939.3.jpg",
      image_url
    )
  )

readr::write_rds(
  image_urls_df,
  file = "./output_data/image_urls_df.rds",
  compress = "gz"
)

# base_occs <- readr::read_rds("./output_data/toohey_species_occurrences.rds")
# image_urls_df <- readr::read_rds("./output_data/image_urls_df.rds")
#
# base_occs_imageurls <- base_occs |>
#   dplyr::left_join(image_urls_df, by = c("wikipedia_url" = "wiki_url"))
#
# readr::write_rds(base_occs_imageurls,
#                  file = "./output_data/toohey_species_occurrences.rds",
#                  compress = "gz")
#
