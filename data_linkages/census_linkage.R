library(dplyr)
library(purrr)


#collect paths - save your own paths to a file called paths.R that is ignored by git (.gitignore) 

source("../paths.R")

#set working directory 

setwd(wd)

#set folder path

path <- file.path(getwd(), "Census 2021")

# List all CSV files
files <- list.files(path, pattern = "\\.csv$", full.names = TRUE)

# Loop through files and assign each to a dataframe named after the file
for (f in files) {
  name <- tools::file_path_sans_ext(basename(f))  # remove folder + .csv
  assign(name, read.csv(f, stringsAsFactors = FALSE))
}

#create age percentages

age_perc <- age %>%
  mutate(
    LSOA21CD = geography.code,
    under19  = (u4 + a5_9 + a10_14 + a15_19) / popn * 100,
    a20_29   = (a20_24 + a25_29) / popn * 100,
    a30_39   = (a30_34 + a35_39) / popn * 100,
    a40_49   = (a40_44 + a45_49) / popn * 100,
    a50_64   = (a50_54 + a55_59 + a60_64) / popn * 100,
    over64   = (a65_69 + a70_74 + a75_79 + a80_84 + o85) / popn * 100
  )%>%
  select(LSOA21CD, popn, under19, a20_29, a30_39, a40_49, a50_64, over64)

#employment percentages 
unemp_perc <- employment %>%
  mutate(
    LSOA21CD = geography.code,
    unemp = unemployed/popn *100
  ) %>%
  select(LSOA21CD, popn, unemp)

#ethnicity percentages
ethnicity_perc <- ethnicity %>%
  mutate(
    LSOA21CD = geography.code,
    asian  = asian / popn * 100,
    black  = black / popn * 100,
    mixed  = mixed / popn * 100,
    white  = white / popn * 100,
    other  = other / popn * 100
  ) %>%
  select(LSOA21CD, popn, asian, black, mixed, white, other)

#self rated health percentages
srh_perc <- srh %>%
  mutate(
    LSOA21CD = geography.code,
    good_health = (srh_vg + srh_g) / popn * 100,
    fair_health = srh_f / popn * 100,
    poor_health = (srh_b + srh_vb) / popn * 100
  ) %>%
  select(LSOA21CD, popn, good_health, fair_health, poor_health)

#gender
gender_perc <- gender %>%
  mutate(
    LSOA21CD = geography.code,
    female = female / popn * 100
  ) %>%
  select(LSOA21CD, popn, female)

#ruc, keep only classification
ruc_class <- ruc %>%
  mutate(
    urban_rural = Urban_rural_flag
  ) %>%
  select(LSOA21CD, urban_rural)

#fix index column names for population density and households

households <- households %>%
  mutate(LSOA21CD = geography.code) %>%
  select(LSOA21CD, households)

popden <- popden %>%
  mutate(LSOA21CD = geography.code) %>%
  select(LSOA21CD, popden)

#load in IMD25
imd25 <- read.csv("IoD25_csv.csv")


#combine
all_census <- list(
  unemp_perc,
  srh_perc,
  ethnicity_perc,
  age_perc,
  households,
  popden,
  imd25,
  ruc_class
) %>%
  reduce(left_join, by = "LSOA21CD")

#keep only English LSOAs
all_census <- all_census %>%
  filter(!str_starts(LSOA21CD, "W"))


#save as a csv
write.csv(all_census, "./linked/england_census_CSV.csv", row.names = FALSE)
