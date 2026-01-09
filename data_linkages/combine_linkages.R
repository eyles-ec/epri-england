library(sf)
library(dplyr)
library(readr)

#quick join function
join_topics <- function(sf_obj, topic) {
  df <- read_csv(paste0("./linked/england_", topic, "_CSV.csv"))
  sf_obj %>% left_join(df, by = "LSOA21CD")
}

source("../paths.R")

#set working directory 

setwd(wd)

#load lsoa data and then restrict to English LSOAS by filtering out LSOA codes starting with W (Wales)

england <- st_read(file.path("./LSOA 2021/LSOA/LSOA_2021_EW_BGC.shp"))
#Projected CRS: OSGB36 / British National Grid

england <- england %>%
  filter(!str_starts(LSOA21CD, "W"))

#list CSV topics in order desired for file
topics <- c("census", "power", "pollution", "landuse", "radon", "pesticides")

#run join function
for (t in topics) {
  england <- join_topics(england, t)
}

#shp isn't possible currently as field names are too long, but don't need it for feature maps
#st_write(england, "./linked/all_england_combined.shp", delete_dsn = TRUE)

#write it all to a csv
write.csv(st_drop_geometry(england), "./linked/all_england_combined_CSV.csv", row.names = FALSE)
