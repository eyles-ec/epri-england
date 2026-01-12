library(sf)
library(dplyr)
library(tidyr)


#function to extract layers from the geopackage
#arguments are the path of the gpkg, the name of the layer you want to extract
#fields you want extracted, the name/path of an exported shapefile, and the same for csv
#you can inspect a gpkg with st_layers from the sf package

extract_layer <- function(gpkg_path,
                            layer_name,
                            fields = NULL,
                            shapefile_out = NULL,
                            csv_out = NULL) {
  
  #Read the layer
  data <- st_read(gpkg_path, layer = layer_name)
  
  # Always corece CRS to WGS84 (EPSG:4326)
  data <- st_transform(data, 4326)
  
  # Select user-specified fields (if provided)
  if (!is.null(fields)) {
    missing <- setdiff(fields, names(data))
    if (length(missing) > 0) {
      stop("These fields are not in the layer: ", paste(missing, collapse = ", "))
    }
    data <- data %>% select(all_of(fields), geometry)
  }
  
  # Export shapefile (optional)
  if (!is.null(shapefile_out)) {
    st_write(data, shapefile_out, delete_dsn = TRUE)
  }
  
  # Export CSV (optional)
  if (!is.null(csv_out)) {
    write.csv(st_drop_geometry(data), csv_out, row.names = FALSE)
  }
  
  # Return the sf object
  return(data)
}

#function to summarise power data 

summarise_to_lsoa <- function(data, 
                              lsoa,
                              lsoa_id = "LSOA21CD",
                              summary_type = c("count", "density", "length"),
                              name = NULL) {
  
  summary_type <- match.arg(summary_type)
  
  # Coerce CRS
  data <- st_transform(data, st_crs(lsoa))
  
  # Detect geometry type
  geom_type <- unique(st_geometry_type(data))
  
  # Default names if user doesn't supply one
  if (is.null(name)) {
    name <- dplyr::case_when(
      summary_type == "count"   ~ "count",
      summary_type == "density" ~ "density",
      summary_type == "length"  ~ "total_km"
    )
  }
  
  
  # points
  if (geom_type %in% c("POINT", "MULTIPOINT")) {
    
    # Spatial join: points → LSOA
    joined <- st_join(data, lsoa)
    
    # Count points per LSOA
    counts <- joined %>%
      st_drop_geometry() %>%
      count(.data[[lsoa_id]], name = "value")
    
    if (summary_type == "count") {
      
      # Join back to LSOA polygons (sf output)
      out <- lsoa %>%
        left_join(counts, by = lsoa_id) %>%
        mutate(value = replace_na(value, 0)) %>%
        rename(!!name := value)
      
      return(out)
    }
    
    if (summary_type == "density") {
      
      # Area in km2 -> 1e6 is shorthand for a million as it's area
      lsoa$area_km2 <- as.numeric(st_area(lsoa)) / 1e6
      
      out <- lsoa %>%
        left_join(counts, by = lsoa_id) %>%
        mutate(
          value = replace_na(value, 0),        # ensure value exists
          density_val = value / area_km2       # compute density
        ) %>%
        rename(!!name := density_val)
      
      return(out)
    }
  }
  
  # lines
  if (geom_type %in% c("LINESTRING", "MULTILINESTRING")) {
    
    # Clip lines to LSOA boundaries
    clipped <- st_intersection(data, lsoa)
    
    # Length in km, in this case /1000 because length not area
    clipped$length_km <- as.numeric(st_length(clipped)) / 1000
    
    # Summarise by LSOA
    lengths <- clipped %>%
      st_drop_geometry() %>%
      group_by(.data[[lsoa_id]]) %>%
      summarise(value = sum(length_km), .groups = "drop")
    
    # Join back to LSOA polygons (sf output)
    out <- lsoa %>%
      left_join(lengths, by = lsoa_id) %>%
      mutate(value = replace_na(value, 0)) %>%
      rename(!!name := value)
    
    return(out)
  }
  
  stop("Unsupported geometry type for this function.")
}


#collect paths - save your own paths to a file called paths.R that is ignored by git (.gitignore) 

source("../paths.R")

#set working directory 

setwd(wd)

#check layers in geopackage
st_layers("./OIM/GBR.gpkg")

#set path
gpkg_path <- "./OIM/GBR.gpkg"

#extract files
power_plant <- extract_layer(gpkg_path, "power_plant", c("name", "operator", "construction", "source", "method", "output"), "./power/power_plant.shp", "./power/power_plant.csv")
power_lines <- extract_layer(gpkg_path, "power_line", c("operator", "construction", "location", "max_voltage", "voltages", "frequency", "circuits", "cables"), "./power/power_lines.shp", "./power/power_lines.csv")
power_substations <- extract_layer(gpkg_path, "power_substation_point", c("operator", "construction", "substation_type", "max_voltage", "voltages", "frequency"), "./power/power_substations.shp", "./power/power_substations.csv")
power_towers <- extract_layer(gpkg_path, "power_tower", c("operator"), "./power/power_towers.shp", "./power/power_towers.csv")

#masts include lighting and radar, but comms, so included here as a TBD
#masts <- extract_layer(gpkg_path, "mast", c("operator", "mast_type"), "./power/masts.shp", "./power/masts.csv")

#convert plants to centroids
power_plants <- st_centroid(power_plant)
rm(power_plant)

#separate overhead lines and underground cables
overhead_lines <- c("bridge", "overground", "overhead", "roof", "surface")
underground_cables <- c("indoor", "transition", "trough", "tunnel", "underground", "underwater")

overhead <- power_lines %>%
  dplyr::filter(location %in% overhead_lines)

underground <- power_lines %>%
  dplyr::filter(location %in% underground_cables)

#load lsoa data and then restrict to English LSOAS by filtering out LSOA codes starting with W (Wales)

england <- st_read(file.path("./LSOA 2021/LSOA/LSOA_2021_EW_BGC.shp"))

england <- england %>%
  filter(!str_starts(LSOA21CD, "W"))

#run summarise function for everything
plants_lsoa <- summarise_to_lsoa(power_plants, england, summary_type = "count", name = "plant_count")
underground_lsoa <- summarise_to_lsoa(underground, england, summary_type = "length", name = "ug_km")
overhead_lsoa <- summarise_to_lsoa(overhead, england, summary_type = "length", name = "oh_km")
substations_lsoa <- summarise_to_lsoa(power_substations, england, summary_type = "count", name = "sub_count")
towers_lsoa_ct <- summarise_to_lsoa(power_towers, england, summary_type = "count", name = "tower_count")
towers_lsoa_de <- summarise_to_lsoa(power_towers, england, summary_type = "density", name ="tower_dens_km2")


#left join everything but only keep the summaries from the joined tables by dropping the geometry 
lsoa_all <- plants_lsoa %>%
  left_join(
    underground_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, ug_km),
    by = "LSOA21CD"
  ) %>%
  left_join(
    overhead_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, oh_km),
    by = "LSOA21CD"
  ) %>%
  left_join(
    substations_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, sub_count),
    by = "LSOA21CD"
  ) %>%
  left_join(
    towers_lsoa_ct %>% st_drop_geometry() %>% select(LSOA21CD, tower_count),
    by = "LSOA21CD"
  ) %>%
  left_join(
    towers_lsoa_de %>% st_drop_geometry() %>% select(LSOA21CD, tower_dens_km2),
    by = "LSOA21CD"
  )

#save as a shp and csv

st_write(lsoa_all, "./linked/england_power.shp", delete_dsn = TRUE)
write.csv(st_drop_geometry(lsoa_all), "./linked/england_power_CSV.csv", row.names = FALSE)