#radon data

library(sf)
library(dplyr)

#collect paths - save your own paths to a file called paths.R that is ignored by git (.gitignore) 

source("../paths.R")

#set working directory 

setwd(wd)

#load lsoa data and then restrict to English LSOAS by filtering out LSOA codes starting with W (Wales)

england <- st_read(file.path("./LSOA 2021/LSOA/LSOA_2021_EW_BGC.shp"))
#Projected CRS: OSGB36 / British National Grid

england <- england %>%
  filter(!str_starts(LSOA21CD, "W"))

radon <- st_read("./radon/Radon_Indicative_Atlas_v3.shp") 
#Projected CRS: OSGB36 / British National Grid

#create action based classifcations

radon <- radon %>%
  mutate(
    no_action    = CLASS_MAX %in% 1:2,
    basic_action = CLASS_MAX %in% 3:4,
    full_action  = CLASS_MAX %in% 5:6
  )

#intersect radon polygons with LSOAs
radon_lsoa <- st_intersection(
  england %>% select(LSOA21CD),
  radon %>% select(CLASS_MAX, no_action, basic_action, full_action)
)

#as the polygons don't match geographically, calculate area weights
#the radon areas are smaller than LSOAs
radon_lsoa <- radon_lsoa %>%
  mutate(
    area = st_area(geometry),
    area_numeric = as.numeric(area)
  )

#create an area-weighted summary by LSOA of the radon groups - as they're logical, they need converting to numeric
radon_summary <- radon_lsoa %>%
  group_by(LSOA21CD) %>%
  summarise(
    radon_no_action =
      sum(as.numeric(no_action) * area_numeric) /
      sum(area_numeric),
    
    radon_basic_action =
      sum(as.numeric(basic_action) * area_numeric) /
      sum(area_numeric),
    
    radon_full_action =
      sum(as.numeric(full_action) * area_numeric) /
      sum(area_numeric)
  )


#save as a shp and csv

st_write(radon_summary, "./linked/england_radon.shp", delete_dsn = TRUE)
write.csv(st_drop_geometry(radon_summary), "./linked/england_radon_CSV.csv", row.names = FALSE)

