library(tidyverse)
library(rstan)
library(gsl)

data <- read.csv("./data/fr_pk_spw_har.csv")

stan.data <- list("nyrs" = length(data$year),
                  "nRyrs" = length(data$year) ,
                  "S_obs" = data$spawn/1000000,
                  "H_obs" = data$harvest/1000000,
                  "S_cv" = data$spawn_cv,
                  "H_cv" = data$harvest_cv)

stan.fit <- stan(file = "./analysis/SS-SR_AR1.stan",
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

stan.fit <- readRDS("./analysis/output/SS-SR_AR1.stan.fit.rds")
stan.data <- readRDS("./analysis/output/SS-SR_AR1.stan.data.rds")
model_pars <- rstan::extract(stan.fit)

post_df <- data.frame(
  parameter = factor(rep(c("lnalpha", "beta", "phi","sigma"), each=dim(model_pars$lnalpha))),
  posterior = c(model_pars$lnalpha, model_pars$beta, model_pars$phi, model_pars$sigma_R)
)

ggplot(post_df, aes(x = posterior)) + 
  geom_histogram() +
  facet_wrap(~ parameter, scales="free") +
  theme_bw()

sr_years <- 33
max_samples <- dim(model_pars$lnalpha)

spwn <- exp(model_pars$lnS)
spwn.quant <- apply(spwn, 2, quantile, probs=c(0.05,0.5,0.95))[,1:31]

rec <-exp(model_pars$lnR)
rec.quant <- apply(rec, 2, quantile, probs=c(0.05,0.5,0.95))[,2:32]

brood_t <- as.data.frame(cbind(data$year[1:31],t(spwn.quant), t(rec.quant)))
colnames(brood_t) <- c("BroodYear","S_lwr","S_med","S_upr","R_lwr","R_med","R_upr")

brood_t <- as.data.frame(brood_t)

# SR relationship
spw <- seq(0,max(brood_t[,4]),length.out=100)
SR_pred <- matrix(NA,100,max_samples)

for(i in 1:max_samples){
  r <- sample(seq(1,max_samples),1,replace=T)
  a <- model_pars$lnalpha[r]
  b <- model_pars$beta[r]
  SR_pred[,i] <- (exp(a)*spw*exp(-b*spw))
}

SR_pred <- cbind(spw,t(apply(SR_pred,c(1),quantile,probs=c(0.05,0.5,0.95),na.rm=T)))
colnames(SR_pred) <- c("Spawn", "Rec_lwr","Rec_med","Rec_upr")
SR_pred <- as.data.frame(SR_pred)

ggplot() +
  geom_ribbon(data = SR_pred, aes(x = Spawn, ymin = Rec_lwr, ymax = Rec_upr),
              fill = "grey80", alpha=0.5, linetype=2, colour="gray46") +
  geom_line(data = SR_pred, aes(x = Spawn, y = Rec_med), color="black", size = 1) +
  geom_errorbar(data = brood_t, aes(x= S_med, y = R_med, ymin = R_lwr, ymax = R_upr),
                colour="grey", width=0, size=0.3) +
  geom_errorbarh(data = brood_t, aes(x= S_med, y = R_med, xmin = S_lwr, xmax = S_upr),
                 height=0, colour = "grey", height = 0, size = 0.3) +
  geom_point(data = brood_t, aes(x = S_med, y = R_med, color=BroodYear, width = 0.9), size = 3)+
  coord_cartesian(xlim=c(0, 25), ylim=c(0,max(brood_t[,7]))) +
  scale_colour_viridis_c()+
  xlab("Spawners (millions)") +
  ylab("Recruits (millions)") +
  theme_bw() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.key.size = unit(0.4, "cm"),
        legend.title = element_text(size=9),
        legend.text = element_text(size=8))+
  geom_abline(intercept = 0, slope = 1,col="dark grey")

resid <- model_pars$lnresid
resid.quant <- apply(resid, 2, quantile, probs=c(0.025,0.25,0.5,0.75,0.975))[,1:31]

resids <- as.data.frame(cbind(data$year[1:31], t(resid.quant)))
colnames(resids) <- c("year","lwr","midlwr","mid","midupper","upper")

ggplot(resids, aes(x=year, y = mid), show.legend = F) +
  geom_line(show.legend = F, color = rgb(1,0,0, alpha=0.2), lwd = 1.5) + 
  geom_ribbon(aes(ymin = lwr, ymax = upper), show.legend = F, fill = rgb(1,0,0, alpha=0.2)) +
  geom_ribbon(aes(ymin = midlwr, ymax = midupper), show.legend = F, fill = rgb(1,0,0, alpha=0.2)) +
  coord_cartesian(ylim=c(-3,3)) +
  xlab("Brood year") +
  ylab("Recruitment residuals") +
  theme(legend.position = "none") +
  geom_abline(intercept = 0, slope = 0,col="dark grey", lty=2)+
  theme_bw()

# benchmarks ----
# Sgen function
get_Sgen <- function(a, b, int_lower, int_upper, SMSY) {
  fun_Sgen <- function(Sgen, a, b, SMSY) {Sgen * a * exp( - b*Sgen) - SMSY}
  Sgen <- uniroot(fun_Sgen, interval=c(int_lower, int_upper), a=a, b=b, SMSY=SMSY)$root
}

# Benchmarks
bench <- matrix(NA,1000,3,
                dimnames = list(seq(1:1000),c("sgen","smsy","umsy")))

for(i in 1:1000){
  r <- sample(seq(1,1000),1,replace=T)
  a <- model_pars$lnalpha[r]
  b <- model_pars$beta[r]
  bench[i,2] <- (1 − lambert_W0(exp(1 - a))) / b # smsy
  bench[i,1] <- get_Sgen(exp(a),b,-1,1/b*2,bench[i,2]) # sgen
  bench[i,3] <- (1 − lambert_W0(exp(1 - a)))# umsy
}
  
bench.quant <- apply(bench, 2, quantile, probs=c(0.025,0.25,0.5,0.75,0.975), na.rm=T)

quantile(data$spawn,probs=c(0.25, 0.5))/1000000
  