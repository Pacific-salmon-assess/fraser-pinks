data <- read.csv("./data/fr_pk_spw_har.csv")

stan.data <- list("nyrs" = length(data$year),
                  "nRyrs" = length(data$year) ,
                  "S_obs" = data$spawn/1000000,
                  "H_obs" = data$harvest/1000000,
                  "S_cv" = data$spawn_cv,
                  "H_cv" = data$harvest_cv)

stan.fit <- stan(file = "./analysis/ss-sr-ar1.stan",
                 model_name = "SS-SR_AR1",
                 data = stan.data,
                 chains = 4,
                 iter = 500,
                 seed = 42,
                 thin = 1,
                 control = list(adapt_delta = 0.99, max_treedepth = 20))

#shinystan::launch_shinystan(stan.fit) 

saveRDS(stan.fit, file="./analysis/output/SS-SR_AR1.stan.fit.rds")
saveRDS(stan.data, file="./analysis/output/SS-SR_AR1.stan.data.rds")

