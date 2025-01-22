#> This script describes the process used to construct
#> the ALA/iNat data that sits behind the Wild Toohey App
#>

library(galah)
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(lubridate)
library(sf)
library(testthat)
library(httr)
library(jsonlite)

# Step 1 : Source functions ----
source("./R/functions.R")

# Step 2: Define the spatial limits ----
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


# Step 3: ALA extract from year_past years ago up to today (i.e 22/01/2025) ----
#> This is basically the "base records" occurrences (they are QA'd records via the ALA profile)
#> Info on the the ALA profile is here
#> https://support.ala.org.au/support/solutions/articles/6000240256-getting-started-with-the-data-profiles

#>  This is a one off that doesn't get re-run in the updates
#>  However every so often it is good to update recent records to QA'd records
years_past = 9
this_year <- lubridate::year(Sys.Date())
source("./R/get_ALA_data.R")

# Because ALA (galah) data doesn't have most recent fortnight (or so) of occurrences
# We get more recent observations from the iNat API


# Step 4: Update the ALA extract created above with data from iNaturalist API ----
#> (from a week before the max(EventDate) up to Sys.Date()
#> This script is what get re-run via the Github Action
source("./R/update_occurrences_iNatAPI.R")
