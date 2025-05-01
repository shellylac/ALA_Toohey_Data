# Function to create a subset for species in Tara Toohey part of reserve
create_select_spp_df <- function(data, spp_list) {
  select_data <- data |>
    dplyr::filter(eventDate >= Sys.Date()-2,
                  vernacular_name %in% spp_list
    ) |>
    # apply the broad spatial filter for Tara Toohey
    filter(latitude <= -27.530755,
           latitude >= -27.541794,
           longitude >= 153.033571,
           longitude <= 153.039194
    ) |>
    # Keep selected cols
    select(vernacular_name, eventDate, eventTime, google_maps_url)

  return(select_data)
}

# Define the species of interest
my_species = c("Koala",
             "Squirrel Glider",
             "Feathertail Glider",
             "Short-beaked Echidna")
