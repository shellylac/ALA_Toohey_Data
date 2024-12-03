library(rgbif)
library(tidyverse)

df <- data.frame(species_names = c("Panthera leo", "Homo sapiens", "Canis lupus", "Gorilla gorilla"), stringsAsFactors = FALSE)

# Function to get usageKey for a single species name
get_usage_key <- function(species_name) {
  res <- name_backbone(name = species_name)
  if (!is.null(res$usageKey)) {
    return(res$usageKey)
  } else {
    return(NA)
  }
}

# Apply the function over species_names
df$usageKey <- sapply(df$species_names, get_usage_key)
df


get_common_names <- function(taxonKey) {
  res <- name_usage(key = taxonKey, data = 'vernacularNames')
  if (!is.null(res$data) && nrow(res$data) > 0) {
    vernaculars <- res$data
    # Filter for English common names
    eng_common_names <- vernaculars %>%
      filter(language == "eng") %>%
      pull(vernacularName)
    if (length(eng_common_names) > 0) {
      return(paste(unique(eng_common_names), collapse = "; "))
    } else {
      # If no English names, return all available common names
      all_common_names <- vernaculars$vernacularName
      return(paste(unique(all_common_names), collapse = "; "))
    }
  } else {
    return(NA)
  }
}

# Apply the function to get common names
df$common_names <- sapply(df$usageKey, get_common_names)

print(df)
