library(sf)
library(dplyr)
library(purrr)

road_metrics <- function(road_folder, lsoa_sf) {
  
  # load the road lengths (Link files in OS open roads)
  link_files <- list.files(road_folder, pattern = "RoadLink.*\\.shp$|RoadLink.*\\.gml$", full.names = TRUE)
  road_links <- map(link_files, st_read, quiet = TRUE) %>%
    bind_rows() %>%
    st_make_valid()
  
  # load the intersections (Node files in OS open roads)
  node_files <- list.files(road_folder, pattern = "RoadNode.*\\.shp$|RoadNode.*\\.gml$", full.names = TRUE)
  road_nodes <- map(node_files, st_read, quiet = TRUE) %>%
    bind_rows() %>%
    st_make_valid()
  
  #clip road links to match lsoas
  links_lsoa <- st_intersection(
    road_links %>% select(geometry),
    lsoa_sf %>% select(LSOA21CD)
  ) %>%
    mutate(length_m = st_length(geometry))
  
  # summarise road length by LSOA
  road_length <- links_lsoa %>%
    st_drop_geometry() %>%
    group_by(LSOA21CD) %>%
    summarise(total_road_m = sum(as.numeric(length_m), na.rm = TRUE))
  
  # clip intersections/nodes to LSOA
  nodes_lsoa <- st_join(
    road_nodes %>% select(geometry),
    lsoa_sf %>% select(LSOA21CD),
    left = FALSE
  )
  
  #count intersections per lsoa
  intersection_count <- nodes_lsoa %>%
    st_drop_geometry() %>%
    group_by(LSOA21CD) %>%
    summarise(n_intersections = n())
  
  #calculate lsoa area to do density 
  lsoa_area <- lsoa_sf %>%
    mutate(area_km2 = as.numeric(st_area(geometry)) / 1e6) %>%
    st_drop_geometry() %>%
    select(LSOA21CD, area_km2)
  
  #calculate density of road and intersections per km2 in LSOAs
  metrics <- lsoa_sf %>%
    left_join(road_length, by = "LSOA21CD") %>%
    left_join(intersection_count, by = "LSOA21CD") %>%
    left_join(lsoa_area, by = "LSOA21CD") %>%
    mutate(
      road_density_km_per_km2 = (total_road_m / 1000) / area_km2,
      intersection_density_per_km2 = n_intersections / area_km2
    )
  
  return(metrics)
}


#collect paths - save your own paths to a file called paths.R that is ignored by git (.gitignore) 

source("../paths.R")

#set working directory 

setwd(wd)

#load lsoa data and then restrict to English LSOAS by filtering out LSOA codes starting with W (Wales)


england <- st_read(file.path("./LSOA 2021/LSOA/LSOA_2021_EW_BGC.shp"))
#Projected CRS: OSGB36 / British National Grid

england <- england %>%
  filter(!str_starts(LSOA21CD, "W"))

#road path label

road_folder <- "./roads/data"

roads_lsoa <- road_metrics(road_folder, england)
