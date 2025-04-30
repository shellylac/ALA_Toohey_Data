# ALA Toohey Forest Data 

This repository contains R scripts designed to interact with the [Atlas of Living Australia (ALA)](https://www.ala.org.au/) data and the [iNaturalist API](https://api.inaturalist.org/). The scripts retrieve data from the ALA/iNat of vertebrate species occurrences within the [Toohey Forest Reserve area in Brisbane, Australia](https://www.brisbane.qld.gov.au/parks-and-recreation/bushland-and-wetlands/find-reserves-and-forests/toohey-forest-and-mount-gravatt-lookout), Australia and populate a database that is utilised by [Wild Toohey](https://wildspire.shinyapps.io/Wild-Toohey) shiny app. 


## Features

- **Data Retrieval**: The scripts in this repo download vertebrate species occurrence data from the ALA database within the spatial limits of the Toohey Forest reserve. As the ALA does not provide very recent occurrence data (within the past ~7 days), the data from ALA is augmented by retrieving recent occurrences - within the last 7 days - directly from the iNaturalist API.

- **Taxonomic information**: Species occurrence data is supplemented with taxonomic information for each record.

- **Wikipedia links**: Wikipedia links are retrieved for each record.

- **URLS for images**: wikipedia image URLs are retrieved for each record. 

- **Data Updating**: Github Actions are used to automate the process of updating the dataset with the latest occurrences by running scripts on a regular schedule.

- **Data Storage**: The final processed dataset is stored as a compressed RDS file for efficient retrieval by the Wild Toohey app.

## Description of Key Files

- **R/**: Contains all R scripts used for data management.

  - `functions.R`: Defines utility functions for data retrieval and processing.
  - `get_ALA_data.R`: Script to extract initial occurrence data from ALA.
  - `update_occurrences_iNatAPI.R`: Script to extract latest 7 days of occurrence data from the iNat API for Toohey Forest, and append to the ALA dataset.
  - `get_wiki_urls.R`: Script to retrieve wikipedia links for all species in the dataset.
  - `get_wiki_images.R`: Script to retrieve URLS of species images from wikipedia links.  

- **spatial_data/**: Stores the shape files that define the spatial boundary of Toohey Forest reserve.

- **output_data/**: Stores the processed RDS file (`toohey_species_occurences.rds`) containing species occurrences and counts.

- **logs/**: Stores log files created as outputs of the github actions procedures that run the `get_ALA_data.R` and `update_occurrences_iNat.R` scripts.
 

## Dependencies


Along with R, the scripts require these packages:

```r
install.packages(c("galah", "dplyr", "tidyr", "readr", "lubridate", "purrr", "sf", "testthat", "httr", "jasonlite", "rvest"))

```

_Note_: Some packages like galah might require additional configuration. Refer to the [galah documentation](https://galah.ala.org.au/) for detailed instructions.

