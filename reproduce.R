# run this script to reproduce analysis in this repo and knit html summary doc

library(tidyverse)
library(rstan)
library(rmarkdown)

source("./analysis/fit-sr-stan.R")

render("./doc/fraser-pinks.Rmd")
