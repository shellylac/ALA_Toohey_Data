
# script to check if any koala occurrences in the past week
# have been i nthe TaraToohey area

base_occs <- readRDS("./output_data/toohey_species_occurrences.rds")

#> Define the TaraToohey min and max lats/longs bounding box ----
#> # latitude    #longitude
# nw = -27.531369, 153.035630
# ne = -27.532544, 153.041347
# se = -27.542821, 153.039362
# sw = -27.541744, 153.033001


#1. Read in toohey occurrences RDS file
#2. Filter for "koala" (and others?) records in the past XX days
#3. Filter for lat is (>=min(TaraToohey_lat) & <=max(TaraToohey_lat) &&
#              long is (>= min(TaraToohey_long) & <=max(TaraToohey_long))
#4. Make a df that has species, vernacular_name, lat, lon, and google_url link
#5. Turn all this into a function
#6. Add a send email function (if the dataset contains any records)
#7. Add to the inat update script so that it runs in the GA!


