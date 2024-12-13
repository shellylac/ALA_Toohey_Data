library(galah)
library(dplyr)
library(readr)
library(sf)


# Configure ALA
galah::galah_config(atlas = "Australia",
             email = "shelly.lachish@csiro.au",
             download_reason_id = "citizen science"
             )

# Useful tools
# fields <- show_all(fields)
# search_fields("date")

# Source functions ----
source("./R/functions.R")


#> Define the Toohey bounding box ----
# nw = -27.531057, 153.035337
# ne = -27.537956, 153.082805
# se = -27.561382, 153.078571
# sw = -27.555471, 153.030074

b_box <- sf::st_bbox(c(xmin = 153.030074, xmax = 153.082805,
                       ymin = -27.531057, ymax = -27.561382),
                     crs = sf::st_crs("WGS84"))


#> Info on the the ALA profile is here
#> https://support.ala.org.au/support/solutions/articles/6000240256-getting-started-with-the-data-profiles

## Functions to extract data from the ALA Interface [galah package] ----

# Get occurrences of all reptiles, birds and mammals for past 5 years
toohey_occurrences <- get_occurrences(year = 2024 - 5, month = 1, b_box = b_box)

# Get cladistics - Join cladistics to this and filter to remove duplicates
occ_cladistics <- add_cladistics(toohey_occurrences)

# Save this dataset as the base data - (the github action will just run the update script in the future)
readr::write_rds(occ_cladistics,
          file = "./output_data/toohey_species_occurrences.rds",
          compress = "gz")

