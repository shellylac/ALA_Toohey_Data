# ALA Toohey Forest Data 

This repository contains R scripts designed to interact with the [Atlas of Living Australia (ALA)](https://www.ala.org.au/) data and the [iNaturalist API](https://api.inaturalist.org/). The scripts retrieve data from the ALA/iNat of vertebrate species occurrences within the [Toohey Forest Reserve area in Brisbane, Australia](https://www.brisbane.qld.gov.au/parks-and-recreation/bushland-and-wetlands/find-reserves-and-forests/toohey-forest-and-mount-gravatt-lookout), Australia and populate a database that is utilised by [Wild Toohey](https://wildspire.shinyapps.io/Wild-Toohey) shiny app. 


## Features

- **Data Retrieval**: The scripts in this repo download vertebrate species occurrence data from the ALA database within the spatial limits of the Toohey Forest reserve. As the ALA does not provide occurrence data within the last 5-7 days, the data from ALA is augmented by retrieving recent occurrences (within the last 7 days) directly from the iNaturalist API.

- **Cladistics Integration**: Enriches the species occurrence data with taxonomic information for each record.

- **Wikipedia links**: Enriches occurrence data by adding the wikipedia link for each record 

- **URLS for images**: Enriches occurrence data by adding the URL of the image from the wikipedia link for each record. 

- **Data Updating**: Uses Github Actions to automate the process of updating the dataset with the latest occurrences.

- **Data Storage**: The final processed dataset is stored as a compressed RDS file for efficient retrieval by the Wild Toohey app.

## Description of Key Files

- **R/**: Contains all R scripts used for data management.

  - `functions.R`: Defines utility functions for data retrieval and processing.
  - `get_ALA_data.R`: Script to extract initial occurrence data from ALA.
  - `update_occurrences_iNatAPI.R`: Script to extract latest 7 days of occurrence data from the iNat API for Toohey Forest.
  - `get_wiki_urls.R`: Script to retrieve wikipedia links for all species in the dataset.
  - `get_wiki_images.R`: Script to retrieve URLS of species images from wikipedia links.  

- **spatial_data/**: Stores the shape files that define the spatial boundary of Toohey Forest reserve.

- **output_data/**: Stores the processed RDS files containing species occurrences and counts.

  - `toohey_species_occurences.rds`: Detailed occurrence records.

- **logs/**: Stores log files created as outputs of the github actions procedures that run the `get_ALA_data.R` and `update_occurrences_iNat.R` scripts on a weekly schedule.
 

## Dependencies


Ensure you have R installed. Then, install the necessary packages:

```r
install.packages(c("galah", "dplyr", "tidyr", "readr", "lubridate", "purrr", "sf", "testthat", "httr", "jasonlite", "rvest"))

```

_Note_: Some packages like galah might require additional configuration. Refer to the [galah documentation](https://galah.ala.org.au/) for detailed instructions.

