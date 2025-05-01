# Run test suite for the update occs dataset
test_that("dataset has the correct structure", {
  # Check that it is a tibble (tbl_df)
  expect_s3_class(occ_cladistics_wikiurls, "tbl_df")

  # Check that we have exactly 16 columns
  expected_cols <- c(
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
    "vernacular_name",
    "wikipedia_url",
    "image_url"
  )
  expect_equal(colnames(occ_cladistics_wikiurls), expected_cols)

  # Check column types
  # Character columns
  expect_type(occ_cladistics_wikiurls$scientificName, "character")
  expect_type(occ_cladistics_wikiurls$dataResourceName, "character")
  expect_type(occ_cladistics_wikiurls$scientific_name, "character")
  expect_type(occ_cladistics_wikiurls$taxon_concept_id, "character")
  expect_type(occ_cladistics_wikiurls$class, "character")
  expect_type(occ_cladistics_wikiurls$order, "character")
  expect_type(occ_cladistics_wikiurls$family, "character")
  expect_type(occ_cladistics_wikiurls$genus, "character")
  expect_type(occ_cladistics_wikiurls$species, "character")
  expect_type(occ_cladistics_wikiurls$vernacular_name, "character")
  expect_type(occ_cladistics_wikiurls$wikipedia_url, "character")
  expect_type(occ_cladistics_wikiurls$image_url, "character")
  expect_type(occ_cladistics_wikiurls$eventDate, "character")
  expect_type(occ_cladistics_wikiurls$eventTime, "character")
  expect_type(occ_cladistics_wikiurls$latitude, "character")
  expect_type(occ_cladistics_wikiurls$longitude, "character")

  # Test latitude and longitude fall within valid ranges
  expect_true(all(
    as.numeric(occ_cladistics_wikiurls$latitude) >= -90 &
      as.numeric(occ_cladistics_wikiurls$latitude) <= 90,
    na.rm = TRUE
  ))
  expect_true(all(
    as.numeric(occ_cladistics_wikiurls$longitude) >= -180 &
                 as.numeric(occ_cladistics_wikiurls$longitude) <= 180,
    na.rm = TRUE
  ))
})
