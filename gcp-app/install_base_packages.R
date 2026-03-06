#!/usr/bin/env Rscript
# install_base_packages.R
#
# Purpose: Install all base R packages for the gcp-app image and snapshot
#          a fresh renv.lock. Run this script inside a container (or locally
#          with R installed) to regenerate renv.lock after version updates.
#
# Usage:
#   docker run --rm -v $(pwd):/out <image> \
#     Rscript install_base_packages.R --snapshot /out/renv.lock
#
#   Or locally:  Rscript install_base_packages.R

library(renv)

lib <- Sys.getenv("RENV_PATHS_LIBRARY", unset = "/renv/library")

pkgs <- c(
  # GCP integration
  "bigrquery",
  "googleCloudStorageR",
  "gargle",

  # Core data manipulation
  "tidyverse",   # includes dplyr, tidyr, ggplot2, readr, purrr, stringr, …
  "DBI",
  "lubridate",
  "janitor",

  # Excel I/O
  "openxlsx",

  # Reporting
  "rmarkdown",
  "knitr",

  # Shiny app framework
  "shiny",
  "bslib",
  "DT",
  "plotly",
  "shinycssloaders"
)

message("Installing R packages into: ", lib)
renv::install(pkgs, library = lib, prompt = FALSE)

# Snapshot only if --snapshot flag supplied (used during image authoring)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 2 && args[1] == "--snapshot") {
  lockfile <- args[2]
  message("Snapshotting to: ", lockfile)
  renv::snapshot(
    library  = lib,
    lockfile = lockfile,
    type     = "all",
    prompt   = FALSE
  )
  message("Done — commit the updated renv.lock.")
}
