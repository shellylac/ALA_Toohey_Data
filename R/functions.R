
# update occurences function ----
update_occurrences <- function(year, month, b_box){
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
              kingdom, phylum, issues))

  return(occ_data_clads)
  }


# Get log file name
get_log_filename <- function(){
  today <- format(Sys.Date(), "%d-%m-%Y")
  log_filename <- paste0("./logs/", "update-", today, ".log")
  return(log_filename)
}


# Run tests function
# Create a function to run tests and capture their results
run_tests <- function() {
  # Temporary file to store test results
  temp_file <- tempfile(fileext = ".Rdata")

  # Run tests and capture the result
  test_results <- tryCatch({
    # Capture test results
    test_output <- capture.output({
      results <- testthat::test_file("./R/update_occs_testQA.R",
                                     stop_on_failure = FALSE,
                                     reporter = "summary")

      # Save results to a temporary file
      save(results, file = temp_file)
    })

    # Return the path to the saved results
    temp_file
  }, error = function(e) {
    # If an error occurs during testing
    message("Error in test execution: ", e$message)
    NULL
  })

  return(test_results)
}


# Function to check test results
check_test_results <- function(results_file) {
  if (is.null(results_file)) {
    stop("Tests could not be run")
  }

  # Load the saved results
  load(results_file)

  # Check if any tests failed
  if (length(results) > 0 && any(sapply(results, function(x) x$failed > 0))) {
    # Collect failure messages
    failure_messages <- sapply(results[sapply(results, function(x) x$failed > 0)],
                               function(x) x$message)

    # Stop with detailed error message
    stop("Tests failed:\n", paste(failure_messages, collapse = "\n"))
  }

  # If we get here, tests passed
  message("All tests passed successfully!")
}
