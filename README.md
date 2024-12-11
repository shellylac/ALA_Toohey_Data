# ALA Data Management Repository

Welcome to the **ALA Data Management Repository**! This repository contains R scripts designed to interact with the [Atlas of Living Australia (ALA)](https://www.ala.org.au/) data. The scripts facilitate data retrieval, updating, and quality assurance to help you manage species occurrence data efficiently.

## Table of Contents

- [Project Structure](#project-structure)
- [Description of Files](#description-of-files)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [1. Retrieve Initial Data](#1-retrieve-initial-data)
  - [2. Update Existing Data](#2-update-existing-data)
  - [3. Quality Assurance](#3-quality-assurance)
- [Dependencies](#dependencies)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Project Structure

├── R
│ ├── functions.R
│ ├── get_ALA_data.R
│ ├── update_ALA_data.R
│ └── update_occs_testQA.R
├── output_data
│ ├── toohey_species_occurences.rds
│ └── toohey_species_counts.rds
├── README.md
└── .gitignore

## Description of Files

- **R/**: Contains all R scripts used for data management.

  - `functions.R`: Defines utility functions for data retrieval and processing.
  - `get_ALA_data.R`: Script to extract initial occurrence data from ALA.
  - `update_ALA_data.R`: Updates the existing dataset with the latest data from ALA.
  - `update_occs_testQA.R`: Contains quality assurance tests to validate updated data.

- **output_data/**: Stores the processed RDS files containing species occurrences and counts.

  - `toohey_species_occurences.rds`: Detailed occurrence records.
  - `toohey_species_counts.rds`: Aggregated counts of species occurrences.

- **README.md**: This file, providing an overview of the repository.

- **.gitignore**: Specifies files and directories to be ignored by Git.

## Features

- **Data Retrieval**: Fetches species occurrence data for reptiles, birds, and mammals within a specified bounding box in Australia.
- **Data Updating**: Automates the process of updating the dataset with the latest occurrences.
- **Cladistics Integration**: Enriches occurrence data with cladistic information.
- **Quality Assurance**: Implements tests to ensure data integrity and correct structure before updates.
- **Data Storage**: Saves processed data in compressed RDS format for efficient storage and retrieval.

## Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/shellylac/ALA_Toohey_Data.git
   cd ALA_Toohey_Data

   ```

2. **Install Required R Packages**

Ensure you have R installed. Then, install the necessary packages:

```r
install.packages(c("here", "galah", "dplyr", "tidyr", "purrr", "lubridate", "testthat"))
```

_Note_: Some packages like galah might require additional configuration. Refer to the [galah documentation](https://galah.ala.org.au/) for detailed instructions.

## Usage

1. Retrieve Initial Data
   Run the get_ALA_data.R script to fetch the initial set of species occurrence data.

```r
source("R/get_ALA_data.R")
```

This script performs the following actions:

- Configures the ALA connection.
- Defines the geographic bounding box for data retrieval.
- Extracts occurrences of reptiles, birds, and mammals from the past five years.
- Enriches the data with cladistic information.
- Saves the processed data to output_data/toohey_species_occurences.rds and output_data/toohey_species_counts.rds.

2. Update Existing Data
   To update the dataset with the latest occurrences, execute the update_ALA_data.R script. This script will:

- Fetch new occurrence data since the last update.
- Enrich the data with cladistic information.
- Perform quality assurance tests.
- Merge and save the updated dataset.

```r
source("R/update_ALA_data.R")
```

Key Steps in update_ALA_data.R:

- Configuration: Sets up the ALA connection and sources necessary functions.
- Data Loading: Reads the existing occurrence and count data.
- Bounding Box Definition: Ensures consistency in the geographic area for updates.
- Data Retrieval: Fetches updated occurrence data based on the latest available month and year.
- Cladistics Addition: Integrates cladistic information into the new occurrence data.
- Quality Assurance: Runs tests to validate the structure and integrity of the updated data.
- Data Merging and Saving: Combines the new data with the base data, removes duplicates, recalculates counts, and saves the updated datasets.

3. Quality Assurance

The `update_occs_testQA.R` script contains tests to validate the structure and integrity of the updated data. It is automatically called during the update process. To run tests independently:

```r
source("R/update_occs_testQA.R")
```

What It Tests:

- Ensures the dataset is a tibble (tbl_df).
- Verifies the presence of exactly 14 specified columns.
- Confirms the correct data types for each column.
- Checks that latitude and longitude values fall within valid geographic ranges.
- Validates that eventDate is in the correct datetime format.

## Dependencies

The project relies on the following R packages:

- here: For constructing file paths.
- galah: Interface to the Atlas of Living Australia.
- tidyverse: Data manipulation and visualization.
- purrr: Functional programming tools.
- lubridate: Date and time manipulation.
- testthat: Unit testing framework.
  Ensure all dependencies are installed and properly configured before running the scripts.
