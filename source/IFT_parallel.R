###########################
# Run model in parallel
# Christopher Gandrud
# 19 February 2014
# MIT License
###########################

# Load packages
library(repmis)
library(DataCombine)
library(reshape2)
library(dplyr)
library(devtools)
library(rstan)
library(parallel)

# Set working directory. Change as needed.
setwd('/git_repositories/IFTIndex/')

## Set out width
options('width' = 200)

# Load function to subset the data frame to countries that report 
# at least 1 item.
source_url('https://raw.githubusercontent.com/FGCH/FRTIndex/master/source/miscFunctions/report_min_once.R')

# Load data
BaseSub <- 'source/data_cleaned/wdi_fiscal.csv' %>%
    read.csv(stringsAsFactors = FALSE)

# ---------------------------------------------------------------------------- #
#### Keep only countries that report at least 1 item for the entire period  ####
BaseSub <- report_min_once(BaseSub)

#### Data description ####
# Create country/year numbers
BaseSub$countrynum <- as.numeric(as.factor(BaseSub$country))
BaseSub$yearnum <- as.numeric(as.factor(BaseSub$year))

#### Clean up ####
# Keep only complete variables
binary_vars <- names(BaseSub)[grep('^Rep_', names(BaseSub))]
BaseStanVars <- BaseSub[, c('countrynum', 'yearnum', binary_vars)]

# Data descriptions
NCountry <- max(BaseStanVars$countrynum)
NYear <- max(BaseStanVars$yearnum)
NItems <- length(binary_vars)

# Melt data so that it is easy to enter into Stan data list
MoltenBase <- melt(BaseStanVars, id.vars = c('countrynum', 'yearnum'))

# Convert item names to numeric
MoltenBase$variable <- as.factor(MoltenBase$variable) %>% as.numeric()

# Order data
MoltenReady <- arrange(MoltenBase, countrynum, yearnum, variable)

# ---------------------------------------------------------------------------- #
#### Specify Model ####
ift_code <- 'source/IFT.stan'

#### Create data list for Stan ####
ift_data <- list(
    C = NCountry,
    T = NYear,
    K = NItems,
    N = nrow(MoltenReady),
    cc = MoltenReady$countrynum,
    tt = MoltenReady$yearnum,
    kk = MoltenReady$variable,
    y = MoltenReady$value
)

# Create Empty Stan model (so it only needs to compile once)
empty_stan <- stan(file = ift_code, data = ift_data, chains = 0)

# Run on 4 cores (w)
sflist <-
    mclapply(1:4, mc.cores = 4,
             function(i) stan(fit = empty_stan, data = ift_data,
                              seed = i, chains = 1,
                              iter = 100, chain_id = i,
                              pars = c('delta', 'alpha', 'beta', 'log_gamma')
                              #,
                              #diagnostic_file = paste0(
                              #    'ift_sims_diagnostic', Sys.Date())
             )
    )

# Collect in to Stan fit object
fit <- sflist2stanfit(sflist)

# Save Stan fit object
save(fit, file = paste0('fit_', Sys.Date(), '.RData'))