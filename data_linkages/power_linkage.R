library(sf)
library(dplyr)
library(tidyr)
library(purrr)


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

#load transmission data 

transmission_lines <- st_read(file.path("./transmission/all_data/LINE.shp"))
transmission_cables <- st_read(file.path("./transmission/all_data/CABLE.shp"))


#load lsoa data and then restrict to English LSOAS by filtering out LSOA codes starting with W (Wales)

england <- st_read(file.path("./LSOA 2021/LSOA/LSOA_2021_EW_BGC.shp"))

england <- england %>%
  filter(!str_starts(LSOA21CD, "W"))

#run summarise function for everything
plants_lsoa <- summarise_to_lsoa(power_plants, england, summary_type = "count", name = "plant_count")
underground_lsoa <- summarise_to_lsoa(underground, england, summary_type = "length", name = "all_ug_km")
overhead_lsoa <- summarise_to_lsoa(overhead, england, summary_type = "length", name = "all_oh_km")
trans_lines_lsoa <- summarise_to_lsoa(transmission_lines, england, summary_type = "length", name = "trans_lines_km")
trans_cables_lsoa <- summarise_to_lsoa(transmission_cables, england, summary_type = "length", name = "trans_cables_km")
substations_lsoa <- summarise_to_lsoa(power_substations, england, summary_type = "count", name = "sub_count")
towers_lsoa_ct <- summarise_to_lsoa(power_towers, england, summary_type = "count", name = "tower_count")
towers_lsoa_de <- summarise_to_lsoa(power_towers, england, summary_type = "density", name ="tower_dens_km2")


#left join everything but only keep the summaries from the joined tables by dropping the geometry 
join_list <- list(
  underground_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, all_ug_km),
  overhead_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, all_oh_km),
  trans_lines_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, trans_lines_km),
  trans_cables_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, trans_cables_km),
  substations_lsoa %>% st_drop_geometry() %>% select(LSOA21CD, sub_count),
  towers_lsoa_ct %>% st_drop_geometry() %>% select(LSOA21CD, tower_count),
  towers_lsoa_de %>% st_drop_geometry() %>% select(LSOA21CD, tower_dens_km2)
)

#use reduce function from purrr so it's easier to add more items to the join list
lsoa_all <- reduce(
  join_list,
  .init = plants_lsoa,
  .f = ~ left_join(.x, .y, by = "LSOA21CD")
)


#create distribution variables and place them after the other line/cable variables
lsoa_all <- lsoa_all %>%
  mutate(
    dist_lines_km   = pmax(all_oh_km - trans_lines_km, 0),
    dist_cables_km  = pmax(all_ug_km - trans_cables_km,0)
  ) %>%
  relocate(dist_lines_km, dist_cables_km, .after = trans_cables_km)


#save as a shp and csv

st_write(lsoa_all, "./linked/england_power.shp", delete_dsn = TRUE)
write.csv(st_drop_geometry(lsoa_all), "./linked/england_power_CSV.csv", row.names = FALSE)

#save power components as shps, not necessary for transmission data as they exist as shp already

st_write(underground,        "./power_shapefiles/underground.shp")
st_write(overhead,           "./power_shapefiles/overhead.shp")
st_write(power_plants,       "./power_shapefiles/power_plants.shp")
st_write(power_substations,  "./power_shapefiles/power_substations.shp")
st_write(power_towers,       "./power_shapefiles/power_towers.shp")
