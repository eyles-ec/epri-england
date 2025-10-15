#Exposome Preparation - Pesticides linkage 

#load libraries

library(sf)
library(ggplot2)
library(terra)
library(dplyr)
library(exactextractr)
library(spatstat)
library(tidyverse)
library(sfheaders)
library(renv)
library(stats)

#a function to link the pesticide data to the LSOAS

pesticides_data <- function(raster_folder, polygons_sf) {
  
  # List all raster files
  raster_files <- list.files(raster_folder, pattern = "\\.tif$", full.names = TRUE)
  
  # Copy input sf object
  result_sf <- polygons_sf
  
  # Track extracted column names
  extracted_cols <- c()
  
  # Loop through raster files
  for (file in raster_files) {
    rast_obj <- rast(file)
    
    for (i in 1:nlyr(rast_obj)) {
      layer <- rast_obj[[i]]
      
      # Reproject raster layer to match sf CRS
      layer <- terra::project(layer, st_crs(polygons_sf)$wkt)
      
      # Safe column name
      layer_name <- names(layer)
      col_name <- make.names(paste0(tools::file_path_sans_ext(basename(file)), "_", layer_name))
      
      # Extract mean values
      result_sf[[col_name]] <- exact_extract(layer, result_sf, 'mean')
      extracted_cols <- c(extracted_cols, col_name)
    }
  }
  
  # Run Principal Components Analysis on extracted pesticide columns
  #pest_matrix <- result_sf[, extracted_cols] %>% st_drop_geometry()
  #pca_result <- prcomp(pest_matrix, scale. = TRUE)
  
  # Show explained variance to check which principal components are most important
  #explained_var <- summary(pca_result)$importance[2, 1:3]
  #cat("Explained variance by PC1–PC3:\n")
  #print(round(explained_var * 100, 2))  # as percentages
  
  # Add PC1–PC3 to sf object
  # result_sf$PC1 <- pca_result$x[, 1]
  #result_sf$PC2 <- pca_result$x[, 2]
  #result_sf$PC3 <- pca_result$x[, 3]
  
  return(result_sf)
}

#collect paths - save your own paths to a file called paths.R that is ignored by git (.gitignore) 

source("../paths.R")

#set working directory 

setwd(wd)

#load lsoa data and then restrict to English LSOAS by filtering out LSOA codes starting with W (Wales)

england <- st_read(file.path("./LSOA 2021/LSOA/LSOA_2021_EW_BGC.shp"))

england <- england %>%
  filter(!str_starts(LSOA21CD, "W"))

#link pesticide data and do principal components analysis on it

pest_folder <- "./UK_Pesticides/Land-Cover-plus-Pesticides_6100584"

pesticides_england <- pesticides_data(pest_folder, england)

st_write(pesticides_england, "./linked/england_pesticides.shp", delete_dsn = TRUE)
write.csv(st_drop_geometry(pesticides_england), "./linked/england_pesticides_CSV.csv", row.names = FALSE)


