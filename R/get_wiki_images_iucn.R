library(rvest)
library(tidyverse)
library(httr)

get_infobox_data <- function(url) {
  tryCatch(
    {
      # Pause briefly between requests
      Sys.sleep(1)

      # Fetch the page with a user agent to mimic a regular browser
      response <- httr::GET(
        url,
        httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
      )

      # Check for HTTP errors
      if (httr::http_error(response)) {
        warning("HTTP error: ", httr::status_code(response), " for URL: ", url)
        return(list(image_url = NA_character_, iucn_status = NA_character_))
      }

      # Parse the page
      page <- rvest::read_html(response)

      ## 1) Extract the first image from table.infobox.biota
      infobox <- page |> rvest::html_node("table.infobox.biota")
      img_src <- NA_character_
      if (!is.null(infobox)) {
        img_node <- infobox |> rvest::html_node("img")
        if (!is.null(img_node)) {
          img_src <- img_node |> rvest::html_attr("src")
          # Prepend "https:" if the src is protocol-relative
          if (stringr::str_starts(img_src, "//")) {
            img_src <- paste0("https:", img_src)
          }
        }
      }

      ## 2) Extract the IUCN status using the provided XPath
      iucn_node <- page |>
        rvest::html_node(
          xpath = "/html/body/div[2]/div/div[3]/main/div[3]/div[3]/div[1]/table/tbody/tr[4]/td/div/a"
        )
      # Alternative path seen for welcome swallow
      if (is.na(iucn_node)) {
        iucn_node <- page |>
          rvest::html_node(
            xpath = "/html/body/div[2]/div/div[3]/main/div[3]/div[3]/div[1]/table/tbody/tr[5]/td/div/a"
          )
      }
      if (is.na(iucn_node)) {
        iucn_node <- page |>
          rvest::html_node(
            xpath = "/html/body/div[2]/div/div[3]/main/div[3]/div[3]/div[1]/table/tbody/tr[6]/td/div/a"
          )
      }
      if (is.na(iucn_node)) {
        iucn_node <- page |>
          rvest::html_node(
            xpath = "/html/body/div[2]/div/div[3]/main/div[3]/div[3]/div[1]/table/tbody/tr[7]/td/div/a"
          )
      }
      if (is.na(iucn_node)) {
        iucn_node <- page |>
          rvest::html_node(
            xpath = "/html/body/div[2]/div/div[3]/main/div[3]/div[3]/div[1]/table/tbody/tr[3]/td/div/a"
          )
      }
      if (is.na(iucn_node)) {
        iucn_node <- page |>
          rvest::html_node(
            xpath = "/html/body/div[2]/div/div[3]/main/div[3]/div[3]/div[1]/table[1]/tbody/tr[4]/td/div"
          )
      }

      iucn_status <- NA_character_
      if (!is.null(iucn_node)) {
        iucn_status <- iucn_node |> rvest::html_text(trim = TRUE)
      }

      # Return both items in a list
      list(image_url = img_src, iucn_status = iucn_status)
    },
    error = function(e) {
      warning("Error processing URL: ", url, ": ", e$message)
      return(list(image_url = NA_character_, iucn_status = NA_character_))
    }
  )
}

# Wrap with possibly() if you like
safe_get_infobox_data <- purrr::possibly(
  get_infobox_data,
  otherwise = list(image_url = NA_character_, iucn_status = NA_character_)
)

# Example usage:
urls <- unique(base_occs$wikipedia_url)
# Map over each URL and return a tibble row for each
infobox_results <- urls |>
  purrr::map_df(
    function(u) {
      info_list <- safe_get_infobox_data(u)
      tibble(
        wiki_url = u,
        image_url = info_list$image_url,
        iucn_status = info_list$iucn_status
      )
    },
    .progress = TRUE
  )

infobox_results
which(is.na(infobox_results$iucn_status))
which(is.na(infobox_results$image_url))
