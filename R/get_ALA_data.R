library(galah)
library(dplyr)
library(readr)
library(sf)


# Configure ALA
galah::galah_config(atlas = "Australia",
             email = "shelly.lachish@csiro.au",
             download_reason_id = "citizen science"
             )


# Source functions ----
source("./R/functions.R")


#> Define the Toohey bounding box ----
# nw = -27.531057, 153.035337
# ne = -27.537956, 153.082805
# se = -27.561382, 153.078571
# sw = -27.555471, 153.030074

# b_box <- sf::st_bbox(c(xmin = 153.0302, xmax = 153.082,
#                        ymin = -27.5312, ymax = -27.53855),
#                      crs = sf::st_crs("WGS84"))


# Read in the Toohey Forest Boundary shapefile to limit occurrences
toohey_outline <- sf::st_read("./spatial_data/toohey_forest_boundary.shp")


## Functions to extract data from the ALA Interface [galah package] ----

# Get occurrences of all reptiles, birds and mammals for past 5 years
toohey_occurrences <- get_occurrences(year = 2024 - 5, month = 1, geo_limit = toohey_outline)
toohey_occurrences_formatted <- tidy_ala_data(toohey_occurrences)


# Get cladistics dataset
ala_clad_data <- galah::search_taxa(unique(toohey_occurrences_formatted$scientificName)) |> distinct()

# Get cladistics - Join cladistics to this and filter to remove duplicates
occ_cladistics <- add_cladistics(occ_data = toohey_occurrences_formatted,
                                 clad_data = ala_clad_data,
                                 type = "ALA")


# Save this dataset as the base data - (the github action will just run the update script in the future)
readr::write_rds(occ_cladistics,
          file = "./output_data/toohey_species_occurrences.rds",
          compress = "gz")

