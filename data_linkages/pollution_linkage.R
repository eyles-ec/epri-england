library(terra)
library(sf)
library(dplyr)
library(tools)
library(exactextractr)

#function to link to LSOAS using the DEFRA annual data which is provided as a 1x1km centroid grid in OSGB

pollution_data <- function(csv_folder, polygons_sf) {
  
  # List all CSV files in the folder
  csv_files <- list.files(csv_folder, pattern = "\\.csv$", full.names = TRUE)
  
  # Copy input sf object
  result_sf <- polygons_sf
  
  #read in the CSVs and link to LSOAs
  
  for (file in csv_files) {
    
    # Read CSV
    df <- read.csv(file)
    
    # Convert to raster (x, y, value)
    r <- rast(df, type = "xyz", crs = "EPSG:27700")
    
    # Option Reproject raster to match polygons, in case but it will likely fail due to 
    # Needing a lot of memory to run (enormous England sized 1x1km2 grid to reproject)
    #r <- terra::project(r, st_crs(polygons_sf)$wkt)
    
    # Name for the extracted column from the source CSV/raster
    value_name <- names(r)[1]   
    col_name <- make.names(
      paste0(file_path_sans_ext(basename(file)), "_", value_name)
    )
    
    # Extract area-weighted mean
    result_sf[[col_name]] <- exact_extract(r, result_sf, 'mean')
  }
  
  return(result_sf)
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

#link air pollution data and write to shapefile and CSV

poll_folder <- "./pollution/2024/"

pollution_england <- pollution_data(poll_folder, england)

st_write(pollution_england, "./linked/england_pollution.shp", delete_dsn = TRUE)
write.csv(st_drop_geometry(pollution_england), "./linked/england_pollution_CSV.csv", row.names = FALSE)