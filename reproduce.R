# run this script to reproduce analysis in this repo and knit html summary doc
# uncomment the alt-param versions for model with Umsy and lnSmsy as leading parameters instead of lnalpha and beta

library(tidyverse)
library(ggpubr)
library(rstan)
library(rmarkdown)

source("./analysis/fit-sr-stan.R")
#source("./analysis/fit-sr-stan-alt-param.R")

render("./doc/fraser-pinks.Rmd")
#render("./doc/fraser-pinks-alt-param.Rmd")
