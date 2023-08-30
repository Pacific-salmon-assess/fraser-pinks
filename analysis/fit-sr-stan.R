library(here)

# load data ----
data <- read.csv(here("data/fr_pk_spw_har.csv"))

# fit model ----
stan.data <- list("nyrs" = length(data$year),
                  "nRyrs" = length(data$year) ,
                  "S_obs" = data$spawn/1000000,
                  "H_obs" = data$harvest/1000000,
                  "S_cv" = data$spawn_cv,
                  "H_cv" = data$harvest_cv)

stan.fit <- rstan::stan(file = here("analysis/ss-sr-ar1.stan"),
                 model_name = "SS-SR_AR1",
                 data = stan.data,
                 chains = 4,
                 iter = 500,
                 seed = 42,
                 thin = 1,
                 control = list(adapt_delta = 0.99, max_treedepth = 20))

#shinystan::launch_shinystan(stan.fit) 

if(file.exists(here("analysis/output"))){
} else{
  dir.create("./analysis/output")
}

saveRDS(stan.fit, file="./analysis/output/SS-SR_AR1.stan.fit.rds")
saveRDS(stan.data, file="./analysis/output/SS-SR_AR1.stan.data.rds")

# basic diagnostics ----
model.summary <- data.frame(summary(stan.fit)$summary)

# Ideally effective sample sizes for individual parameters are > 0.1 (i.e., 10%); values at zero can be ignored as these are unsampled parameters.
hist(model.summary$n_eff/1000, 
     col="red", 
     breaks=50, 
     main="",
     yaxt="n",
     xlab="Effective sample size/iterations")
axis(2,las=2)
box(col="grey")

# If chains have not mixed well (i.e., the between- and within-chain estimates don't agree), R-hat is > 1. Only using the sample if R-hat is less than 1.05.
hist(model.summary$Rhat, 
     col="royalblue", 
     breaks=50, 
     main="",
     yaxt="n",
     xlab="R-hat")
axis(2,las=2)
box(col="grey")

# how do correlations in lnalpha and beta posteriors look? 
pairs(stan.fit, pars = c("lnalpha", "beta", "sigma_R", "phi"))
