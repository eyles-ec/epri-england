#mobility index

library(dplyr)
library(purrr)

#collect paths - save your own paths to a file called paths.R that is ignored by git (.gitignore) 

source("../paths.R")

#set working directory 

setwd(wd)

#load mobility/churn index
churn <- read.csv("./mobility index/mobility_lsoa11_25.csv")

#rename column to match codes
churn <- churn %>%
  rename(LSOA11CD = area)

#load lsoa data and then restrict to English LSOAS by filtering out LSOA codes starting with W (Wales)

england <- st_read(file.path("./LSOA 2021/LSOA/LSOA_2021_EW_BGC.shp"))

england <- england %>%
  filter(!str_starts(LSOA21CD, "W"))

#load in LSOA2011 to LSOA 2021 linkage

lookup <- read.csv("./LSOA 2021/lsoa2011_lsoa2021.csv")

#add LSOA11CD to the england sf
england <- england %>%
  left_join(
    lookup %>% select(LSOA21CD, LSOA11CD),
    by = "LSOA21CD"
  )

#join in 2024 churn (there are previous years up to 1997 if desired, just join without the select line)

england <- england %>%
  left_join(
    churn %>% select(LSOA11CD, chn2024),
    by = "LSOA11CD"
  )


#write files 
st_write(england, "./linked/england_churn.shp", delete_dsn = TRUE)
write.csv(st_drop_geometry(england), "./linked/england_churn_CSV.csv", row.names = FALSE)
