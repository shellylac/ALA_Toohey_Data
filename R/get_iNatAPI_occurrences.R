library(httr)
library(jsonlite)

# Define date range: last 10 days
d2 <- Sys.Date()
d1 <- d2 - 10

# Define bounding box
swlat <- -27.561382
swlng <- 153.030074
nelat <- -27.531057
nelng <- 153.082805

# Taxa of interest
taxa_ids <- c(3, 40151, 26036)  # Birds, Mammals, Reptiles
taxon_id_str <- paste0("taxon_id=", taxa_ids, collapse = "&")

# Build the API query string
query_str <- paste(
  taxon_id_str,
  paste0("d1=", as.character(d1)),
  paste0("d2=", as.character(d2)),
  "order=desc",
  "order_by=created_at",
  "per_page=200",
  paste0("swlat=", swlat),
  paste0("swlng=", swlng),
  paste0("nelat=", nelat),
  paste0("nelng=", nelng),
  sep="&"
)

base_url <- "https://api.inaturalist.org/v1/observations"

fetch_page <- function(page_num) {
  # Append page parameter
  full_url <- paste0(base_url, "?", query_str, "&page=", page_num)
  resp <- GET(full_url)
  if (status_code(resp) != 200) {
    stop("Failed to retrieve data. HTTP Status: ", status_code(resp))
  }
  json_data <- content(resp, as = "text", encoding = "UTF-8")
  parsed <- fromJSON(json_data, flatten = TRUE)
  return(parsed)
}

all_observations <- data.frame()
species_list <- data.frame()
page_num <- 1

while (TRUE) {
  parsed <- fetch_page(page_num)
  # if (length(parsed$results) == 0) break
  if (is.null(parsed$results$id)) break

  fields <- c("id",
              "time_observed_at",
              "observed_on_string",
              "latitude",
              "longitude",
              "location",
              "user.login",
              "taxon.name",
              "taxon.preferred_common_name",
              "taxon.rank",
              "taxon.iconic_taxon_name",
              "identifications")

  existing_fields <- fields[fields %in% names(parsed$results)]

  observations_df <- parsed$results[, existing_fields, drop = FALSE]
  all_observations <- rbind(all_observations, observations_df)

  # if (page_num >= parsed$total_pages) break
  page_num <- page_num + 1
}

out <- galah::search_taxa(all_observations$taxon.name)




for(i in 1:56){
  print(length(parsed$results$identifications[[i]]$taxon.ancestors[[1]]$name))
}
paste(parsed$results$identifications[[4]]$taxon.ancestors[[1]]$name, collapse = ", ")
