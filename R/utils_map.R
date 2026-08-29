#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Shared Helpers - ISO3-to-Map-Region Crosswalk and Region Abbreviations
#------------------------------------------------------------------------------------------


# Shared helper for joining this repo's ISO3 country codes onto the `maps`
# package's world polygon names (used by figures 1 and 2). `maps`/`mapdata`
# were used instead of sf + rnaturalearth: the latter pulls in `terra`,
# which failed to build from source in this environment (missing libtiff/
# PROJ linkage), while `maps` has no system-library dependency at all.
#
# countrycode::countrycode() handles most of the 185 countries in the
# dataset, but `maps` uses its own, sometimes dated or split, place names.
# The 16 mismatches were found by comparing countrycode's output against
# `maps`' region names directly and are hand-fixed here. Antigua & Barbuda
# and Trinidad & Tobago are two separate polygons in `maps`; only the
# larger island (Antigua, Trinidad) is colored, which is a cosmetic
# limitation, not a missing country.

library(countrycode)
library(dplyr)

MAP_NAME_FIXES <- c(
  CIV = "Ivory Coast",
  COD = "Democratic Republic of the Congo",
  COG = "Republic of Congo",
  STP = "Sao Tome and Principe",
  SWZ = "Swaziland",
  ATG = "Antigua",
  LCA = "Saint Lucia",
  TTO = "Trinidad",
  USA = "USA",
  VCT = "Saint Vincent",
  PSE = "Palestine",
  BIH = "Bosnia and Herzegovina",
  CZE = "Czech Republic",
  GBR = "UK",
  MMR = "Myanmar",
  FSM = "Micronesia"
)

iso3_to_map_region <- function(iso3) {
  nm <- countrycode(iso3, "iso3c", "country.name")
  fixed <- MAP_NAME_FIXES[iso3]
  ifelse(!is.na(fixed), unname(fixed), nm)
}

# Short codes for the 6 WHO regions, used on axes where the full names
# don't fit horizontally. Guide: AFR = Africa, AMR = Americas,
# EMR = Eastern Mediterranean, EUR = Europe, SEA = South-East Asia,
# WP = Western Pacific.
REGION_ABBR <- c(
  "Africa" = "AFR",
  "Americas" = "AMR",
  "Eastern Mediterranean" = "EMR",
  "Europe" = "EUR",
  "South-East Asia" = "SEA",
  "Western Pacific" = "WP"
)

REGION_ABBR_GUIDE <- "AFR = Africa, AMR = Americas, EMR = Eastern Mediterranean, EUR = Europe, SEA = South-East Asia, WP = Western Pacific"
