# Run test suite for the update occs dataset
test_that("dataset has the correct structure", {
  # Check that it is a tibble (tbl_df)
  expect_s3_class(occ_updates_cladistics, "tbl_df")

  # Check that we have exactly 15 columns
  expected_cols <- c("scientificName", "latitude", "longitude", "eventDate", "eventTime",
                     "dataResourceName", "scientific_name", "taxon_concept_id",
                     "class", "order", "family", "genus", "species", "vernacular_name",
                     "wikipedia_url")
  expect_equal(colnames(occ_updates_cladistics), expected_cols)

  # Check column types
  # Character columns
  expect_type(occ_updates_cladistics$scientificName, "character")
  expect_type(occ_updates_cladistics$dataResourceName, "character")
  expect_type(occ_updates_cladistics$scientific_name, "character")
  expect_type(occ_updates_cladistics$taxon_concept_id, "character")
  expect_type(occ_updates_cladistics$class, "character")
  expect_type(occ_updates_cladistics$order, "character")
  expect_type(occ_updates_cladistics$family, "character")
  expect_type(occ_updates_cladistics$genus, "character")
  expect_type(occ_updates_cladistics$species, "character")
  expect_type(occ_updates_cladistics$vernacular_name, "character")
  expect_type(occ_updates_cladistics$wikipedia_url, "character")

  expect_type(occ_updates_cladistics$eventDate, "character")
  expect_type(occ_updates_cladistics$eventTime, "character")

  # Numeric columns
  expect_type(occ_updates_cladistics$latitude, "double")
  expect_type(occ_updates_cladistics$longitude, "double")

  # Optionally, you can test for other conditions:
  # e.g., that latitude and longitude fall within valid ranges
  expect_true(all(occ_updates_cladistics$latitude >= -90 & occ_updates_cladistics$latitude <= 90, na.rm = TRUE))
  expect_true(all(occ_updates_cladistics$longitude >= -180 & occ_updates_cladistics$longitude <= 180, na.rm = TRUE))
})
