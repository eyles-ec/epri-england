# epri-england

Code from the EPRI project to examine power infrastructure, a geographic exposome, and cancer

## Directory

## Workflow

First the data were linked to English LSOAs (2021 version). If the data were provided with linked LSOAs, often in Excel format, they were converted into CSVs for linkage (for example, land use). If like for the Census, individual variables were provided in separate CSVs, they were linked into one file to link into the main LSOA dataset.

## Data sources

| Data | Source | License |
|----|----|----|
| Pesticides | UKCEH Land Cover plus Pesticides, <https://doi.org/10.5285/99a2d3a8-1c7d-421e-ac9f-87a2c37bda62> | Spatial data licensed from the UK Centre for Ecology & Hydrology via the [EDINA digimap consortium.](https://digimap.edina.ac.uk/help/copyright-and-licensing/environment_eula/printable/) |
| Power | Open Infrastructure Map, via [Infrageomatics](https://www.infrageomatics.com/products/osm-export) | Open Data Commons Open Database License (ODbL), from [Open Street Map](https://www.openstreetmap.org/copyright) |
| Census 2021 | [Nomis](https://www.nomisweb.co.uk/sources/census_2021_bulk), using the bulk data download | [Open Government License](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) (OGL), Office for National Statistics |
| (English) Indices of Multiple Deprivation 2025 (IMD25) | [Gov.UK](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025) accredited official statistics. | [Open Government License](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) (OGL), Ministry of Housing, Communities, & Local Government |
| Land Use | [Gov.UK](https://www.gov.uk/government/statistics/land-use-in-england-2022/land-use-statistics-england-2022) official statistics | [Open Government License](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) (OGL), Ministry of Housing, Communities, & Local Government, as Department for Levelling up, Housing and Communities |
| Pollution | [DEFRA](https://uk-air.defra.gov.uk/data/pcm-data) modelled background pollution data | [Open Government License](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)(OGL), Department for Environment, Food & Rural Affairs |
| Radon | [British Geographical Survey](https://www.bgs.ac.uk/download/radon-potential-indicative-atlas-data-for-great-britain/) | ‘Contains British Geological Survey materials © UKRI 2022. Radon Potential classification UK Health Security Agency © Crown copyright 2022’ (i.e. OGL) |
| Roads | [Ordnance Survey Open Roads](https://osdatahub.os.uk/data/downloads/open/OpenRoads) | [Open Government License](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)(OGL), Ordnance Survey |
| Residential Mobility Index (churn) | [Geographic Data Service](https://data.geods.ac.uk/dataset/residential-mobility-index) | [Open Government License](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)(OGL), Geographic Data Service (a Smart Data Research UK Investment: ES/Z504464/1) |
