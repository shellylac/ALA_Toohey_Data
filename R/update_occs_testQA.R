library(testthat)
library(tibble)

test_that("dataset has the correct structure", {
  # Check that it is a tibble (tbl_df)
  expect_s3_class(base_occs, "tbl_df")

  # Check that we have exactly 14 columns
  expected_cols <- c("scientificName", "decimalLatitude", "decimalLongitude", "eventDate",
                     "dataResourceName", "scientific_name", "taxon_concept_id",
                     "class", "order", "family", "genus", "species", "vernacular_name")
  expect_equal(colnames(base_occs), expected_cols)

  # Check column types
  # Character columns
  expect_type(base_occs$scientificName, "character")
  expect_type(base_occs$dataResourceName, "character")
  expect_type(base_occs$scientific_name, "character")
  expect_type(base_occs$taxon_concept_id, "character")
  expect_type(base_occs$class, "character")
  expect_type(base_occs$order, "character")
  expect_type(base_occs$family, "character")
  expect_type(base_occs$genus, "character")
  expect_type(base_occs$species, "character")
  expect_type(base_occs$vernacular_name, "character")

  # Numeric columns
  expect_type(base_occs$decimalLatitude, "double")
  expect_type(base_occs$decimalLongitude, "double")

  # eventDate should be a POSIXct datetime
  expect_s3_class(base_occs$eventDate, "POSIXct")

  # Optionally, you can test for other conditions:
  # e.g., that decimalLatitude and decimalLongitude fall within valid ranges
  expect_true(all(base_occs$decimalLatitude >= -90 & base_occs$decimalLatitude <= 90, na.rm = TRUE))
  expect_true(all(base_occs$decimalLongitude >= -180 & base_occs$decimalLongitude <= 180, na.rm = TRUE))
})
