
# update occurences function ----
get_occurrences <- function(year, month, b_box){
  galah_call() |>
    galah_identify(c("reptilia", "birds", "mammals")) |>
    galah_group_by(species) |>
    galah_geolocate(b_box, type = "bbox") |>
    apply_profile(ALA) |>
    galah_filter(year >= as.numeric(year)) |>
    galah_filter(month >= as.numeric(month)) |>
    atlas_occurrences()
}


add_cladistics <- function(occ_data){

  # Get cladistics
  occ_cladistics <- search_taxa(unique(occ_data$scientificName))

  occ_data_clads <- occ_data |>
    left_join(occ_cladistics, by = c("scientificName" = "search_term")) |>
    # For some reason these species names aren't given a vernacular name - do it manually
    # "Tachyglossus aculeatus"   "Tropidonophis mairii"     "Colluricincla rufogaster"
    mutate(vernacular_name = case_match(species,
                                        "Tachyglossus aculeatus" ~ "Short-beaked Echidna",
                                        "Tropidonophis mairii" ~ "Common Keelback",
                                        "Colluricincla rufogaster" ~ "Rufous Shrikethrush",
                                        .default = vernacular_name)) |>
    # There may be some rows without species level info - remove
    filter(!is.na(species)) |>
    # Remove unecessary rows
    select(-c(recordID, taxonConceptID, occurrenceStatus,
              scientific_name_authorship, match_type, rank,
              kingdom, phylum, issues)) |>
    distinct()

  return(occ_data_clads)
  }


# Get log file name
get_log_filename <- function(){
  today <- format(Sys.Date(), "%d-%m-%Y")
  log_filename <- paste0("./logs/", "update-", today, ".log")
  return(log_filename)
}

