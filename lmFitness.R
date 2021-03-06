###-----------------------------------------------------------------------------
#-----INDIVIDUAL PROJECT MT5763 SOFTWARE FOR DATA ANALYSIS----------------------
#-----ID: 180029941-------------------------------------------------------------
#-----BUILD A MODEL THAT PREDICTS OXYGEN INTAKE RATES---------------------------
#-----VARIABLES-----------------------------------------------------------------
#-----Age - Age in years--------------------------------------------------------
#-----Weight - Weight in kg-----------------------------------------------------
#-----Oxygen - Oxygen intake rate, ml per kg body weight per minute-------------
#-----RunTime -time to run 1.5 miles in minutes---------------------------------
#-----RestPulse - heart rate while resting--------------------------------------
#-----RunPulse - heart rayte at the end of a run--------------------------------
#-----MaxPulse - maximum heart rate recorded while running----------------------
###-----------------------------------------------------------------------------
#-----Use the dataset fitness.csv to fit a linear model predicting the variable 
#oxygen. Perform a model disgnostics and take whatever remedial actions is required 
#to give a good model.
###-----------------------------------------------------------------------------

#-----Libraries-----------------------------------------------------------------
library(stats)
library(tidyverse)
library(ggplot2)
library(car)
library(effects)
library(doParallel)
library(parallel)


#-----Load Data fitness---------------------------------------------------------

fitness <- read.csv("data/fitness.csv", header = T)
head(fitness)


#-----Original Model------------------------------------------------------------
#-----CONCLUSIONS---------------------------------------------------------------
#-----(Intercept) value of 102.93448 - This value represents the value of the 
#intercept B0 value all the other Betas are zero.-------------------------------
#Therefore y = Oxygen = B0 = 102.93448------------------------------------------
#-----RunTime = -2.62865, meaning that everytime RunTime increases by 1 unit, the
#Oxygen level decreases by 2.6--------------------------------------------------

fitnessLM <- lm(Oxygen ~ Age + Weight + RunTime + RestPulse + RunPulse + MaxPulse, 
                data = fitness)

fitnessLM


#See page 17, point 2.5 - Model Selection
#-----fitnessLM summary---------------------------------------------------------
#-----CONCLUSIONS---------------------------------------------------------------
#-----Residual standard error gives us an idea of how far the Oxygen levels are
#from the fitted model.---------------------------------------------------------
#-----Multiple R-Squared = 0.8487. Almost 85% of the variation in Oxygen can be 
#explained  y our model.--------------------------------------------------------
#p-value = 9.715e-09. This value is extremelly small, smaller than 0.05. Therefore, 
# we reject the H0 which assumes that all the model coeficients (B0, B1,   Bn) are
#zero(0).-----------------------------------------------------------------------
#-----Pr(>|t|) gives you the p-value for the t-test. In this case, all the values
#which are below 0.05 are of interest to our model as it can be improved by those. 
#In this particular case, and looking at the value of Weight (0.18687) it can be 
#observed that it is greater than 0.05. Therefore, it fails to reject the 
#H0 (Null Hypothesis based on the assumption that all Betas are zero). In this 
#scenario, having to remove a variable from the model, Weight would be one of 
#the possibilities.

summary (fitnessLM)


#-----Collinearity---------------------------------------------------------------
#it can be said that, when 2 variables are highly correlated, then there is 
#collinearity. In fact, at this stage, what we want is to "exclude variables that 
#offer essentially the same information about response, i.e., we want to avoid 
#collinearity. 

# vif: Calculates variance-inflation and generalized variance-inflation factors 
#for linear, generalized linear, and other models. In this case RunPulse (8.437273)
#and MaxPulse (8.743848) have very similar values, meaning that they are correlated.
#Therefore, these variables offer, essencially, the same information. So, the varible
#with the highest value (MaxPulse) can be omitted.
#display if bigger than 5 they are correlated therefore give same info and we 

vif(fitnessLM)
vif(fitnessLM) > 5  
# bololean TRUE remove Max Pulse


# updated model removed MaxPulse - we now have the new fit for the original model

fitnessLM <- lm(Oxygen ~ Age + Weight + RunTime + RestPulse + RunPulse, 
                data = fitness)
fitnessLM  

#-----final Model---------------------------------------------------------------
#The main objective is to find a balance and have a good set of covariates 
#within our model. If we look only at a few set of variables we are likely to be
#disregarding valuable information. On the other way around, if we include, 
#in our model, both essential and non-essential variables in a model, the standard
#error, confidence interval and, p-values tend to be larger. (g17, 2.5.1)
#In order to determine the finalModel, it will be used the function step(), which
#uses the Akaike Information Criterion (AIC) to select the model,based in the 
#following rule: the lower the AIC the better the model.
#-----using command step()------------------------------------------------------

finalModel <- step(fitnessLM)

#now i have the final model with RunPulse, Age, RunTime
#The AIC value is now (59.04). Removing either RunPulse, or Age, or RunTime would 
#result in a much higher AIC. Therefore it is better to keep the model as it is.

#-----CHECKING THE MODEL ASSUMPTIONS--------------------------------------------
#-----I) ASSESSING LINEARITY----------------------------------------------------
#conclude about the plot -  age and RunPulse are similar and close to zero. 
#The steeper the slop the better,
#the covariate RunTime gives us more info about the selected model so Runtime 
#is the most important variable within the model.

par(mfrow = c(3,2))
termplot(finalModel, se = T)
termplot(finalModel, se = T, partial.resid = TRUE, col.res = 'blue')

#-----Partial Residual Plots----------------------------------------------------
# pg 19 ...points 1 to 4) we have add on the residuals to model and once again 
#RunTime seem to present the the best fit to the model as the residuals tend to 
#be more concentrated along the slope line. pg. 19

plot(effect("Age", finalModel, rug = TRUE)) 
  
plot(effect("RunPulse", finalModel, rug = TRUE)) 

plot(effect("RunTime", finalModel, rug = TRUE))

#the smother the line the better the variable contribution to the model.
#once again runtime - assessing the constant variance pg 21


#-----II) ASSESSING CONSTANT VARIANCE - HOMOSCEDASTICITY------------------------
#-----The Plot of the finalModel - pg 21 - 2.6.3--------------------------------

par(mfrow = c(2,2))
plot(finalModel)

#Scale-location - the red line is almost straight and the residual points are 
#randomly spread across the line.
#this way we can validate the constant variance assumption homoscedasticity.


#-----III) ASSESSING INDEPENDENCE-----------------------------------------------
#ASSESSING THE INDEPENDENCE pg24 paragraph 2.6.4
#revise this part if necessary


durbinWatsonTest(resid(finalModel))

#teste durbin watson 
#H0 correlation of the errors equal to zero
#pvalue > 0.05 fail to reject the H0 the indepence assumption is verified

#-----IV) NORMALITY P26 , 2.6.5-----------------------------------------------------

#QQ NORM
par(mfrow = c(2,2))
plot(finalModel)


#QQ PLOT the residuals follow the normal distribution

#shapiro test

shapiro.test(resid(finalModel))
#fail to reject h0 which is the residuals are normally distributed

######PART TWO################
#Create a function for bootstrapping algorithm to use inside other functions
bootLM <- function(samples, inputData, index){
  #Purpose: Generate the linear regression beta coefficients
  #Inputs: samples: a dataframe containing the indices for the bootstrap samples
  #        inputData: a dataframe containing the response variable, which must be 
  #        in the first column of the dataframe, and the covariates of interest
  #        index: the index of the position in the BootResults that Bootlm 
  #        should be applied to
  #Outputs: Beta: An matrix containing the parameter estimates from a linear 
  #         regression
  
  bootData <- inputData[samples[, index], ]
  Xmat <- bootData[, -1]
  Ymat <- bootData[, 1]
  beta <- solve(t(Xmat)%*%Xmat)%*%t(Xmat)%*%Ymat
  return(beta)
}

lmBoot_par <- function(inputData, nBoot){
  #Purpose: Generate a large number of linear regression beta coefficients using
  #         bootstrap methods.
  #Inputs: inputData: a dataframe containing the response variable, which must be 
  #        in the first column of the dataframe, and the covariates of interest
  #        nBoot: the number of bootstrap samples to generate.
  #Outputs: BootResults: An arraycontaing the parameter estimates of each 
  #         each bootstrap sample.
  #         ConfidenceIntervals: A matrix containing 95% confidence intervals 
  #         for each parameter.
  
  #Calculate the number of observations in the dataset 
  nObs <- nrow(inputData)
  
  #Create the sample data with 1s for the intercept
  sampleData <- as.matrix(cbind(inputData[, 1], 1, inputData[, -1]))
  
  #Set up parallisation
  nCores <- detectCores()
  myClust <- makeCluster(nCores - 1, type = "PSOCK")
  registerDoParallel(myClust)
  
  # Create the a matrix of indices for the bootstrap samples
  bootSamples <- matrix(sample(1:nrow(inputData), nObs * nBoot, replace = T), 
                        nrow = nObs, ncol = nBoot)
  
  #Use parallised sapply to apply bootLM to bootResults matrix
  bootResults <- matrix(NA, nBoot, ncol(sampleData[, -1]))
  bootResults <- parSapply(myClust, 1:nBoot, bootLM, inputData = sampleData, 
                           samples = bootSamples)
  
  #Close parallisation
  stopCluster(myClust)
  
  return(t(bootResults))
}

filteredData <- fitness %>% select(Oxygen, Age, RunTime, RunPulse)
bootRes <- lmBoot_par(filteredData,  1e4)

bootResCI <- matrix(NA, ncol(bootRes), 2, byrow = T)
for(i in 1:ncol(bootRes)){
  bootResCI[i, ] <- quantile(bootRes[, i], probs = c(0.025, 0.975))
}
colnames(bootResCI) <- c('2.5%', '97.5%')
rownames(bootResCI) <- c('intercept', 'Age', 'RunTime', 'RunPulse')
bootResCI
#the fact that there is no zero within the CI we can reject the H0 being b0=b1=bn
#explain boostrap google
#
######PART THREE################

randFunc <- function(nRand){
  set.seed(180029941)
  fitness <- read.csv("data/fitness.csv", header = T)
  estimatedCoef <- coef(lm(Oxygen ~ Age + RunTime + RunPulse, data = fitness))
  
  simResults <- matrix(NA, nRand + 1, 4)
  simData <- fitness
  
  for(i in 2:(nRand + 1)) {
    simData$Oxygen <- sample(fitness$Oxygen, nrow(fitness), replace = F)
    simLm <- lm(Oxygen ~ Age + RunTime + RunPulse, data = simData)
    simResults[i, ] <- coef(simLm)
  }
  
  simResults[1, ] <- estimatedCoef
  colnames(simResults) <- c('intercept', 'Age', 'RunTime', 'RunPulse')
  
  simPvalues <- matrix(NA, 1, 4)
  for(i in 1:4){
    locEst <- c(1, rep(0, 999))
    locEst <- locEst[order(simResults[, i])]
    k <- which(locEst == 1)
    simPvalues[i] <- min(k / (nRand + 1), 1 - k / (nRand + 1)) * 2
  }
  colnames(simPvalues) <- c('intercept', 'Age', 'RunTime', 'RunPulse')
  return(simPvalues)
}
randFunc(1000)



