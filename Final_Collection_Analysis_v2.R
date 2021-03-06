

library(lmtest)
library(sandwich)
library(multiwayvcov)
library(data.table)
library(stargazer)
library(dplyr)

##Data Preparation

d <- read.csv('Pricing Research Final Collection(normalized)_V2.csv')
d <- data.table(d)

head(d, 20)
length(unique(d$Respondent.ID))


#create variables for blocks (food item), and factors (font family, typography) 

#item number (block)
d[, item_number := substr(Item, 5, 5)]

#font family (factor)
d[, Font_family := case_when(
  substr(Item, 7, 8) == 'Ro' ~ "Roboto",
  substr(Item, 7, 8) == 'Jo' ~ "Josefin",
  substr(Item, 7, 8) == 'PT' ~ "PT")]
d[, Typography := case_when(
  (Font_family == 'Roboto' & substr(Item, 13, 13) == 'S') ~ 'Serif',
  (Font_family == 'Roboto' & substr(Item, 13, 13) != 'S') ~ 'Sans',
  (Font_family == 'Josefin' & substr(Item, 14, 18) != 'Slab') ~ 'Serif',
  (Font_family == 'Josefin' & substr(Item, 14, 18) != 'Sans') ~ 'Sans',
  (Font_family == 'PT' & substr(Item, 9, 13) != 'Serif') ~ 'Serif',
  (Font_family == 'PT' & substr(Item, 9, 13) != 'Sans') ~ 'Sans')]

#treatment variable Serif
d[, Serif := case_when( Typography == 'Serif' ~ 1,
                        Typography == 'Sans' ~ 0)]

#exclude unqualified answers
#1. exclude people who googled
d <- d[substr(Google, 1, 2) == 'No',]

#2. exclude people who used phone or tablet
d <- d[Device.Type != list('iOS Phone / Tablet', 'Other')]

#3. exclude people with $0 answers
d <- d[!(Respondent.ID %in% unique(d[Item_Price == 0, Respondent.ID])),]

length(unique(d$Respondent.ID))
#11 people excluded


#create dummy variable for gender
# unique(d$Gender)
d[, Male := case_when( Gender == 'Male' ~ 1,
                       Gender == 'Female' ~ 0)]



##Model Exploration: Price Index Standardization

# #list item 1 price for standardization
# item1 <- d[item_number == "1", .(Respondent.ID, item1_price = Item_Price, item1_font = paste(Font_family, Typography, sep = "_"))]
# head(item1)
# 
# #check for any zero item1
# item1[item1_price == 0]
# 
# #exclude these two people
# item1 <- item1[item1_price != 0]
# 
# #join item 1 price for standardization
# setkey(d, Respondent.ID)
# setkey(item1, Respondent.ID)
# df <- d[item1, nomatch = 0]
# 
# #create standardized price
# df[, price_index := Item_Price / item1_price]
# 
# head(df)
# 
# ATE_model_Price_Index <- lm(price_index ~ Serif * factor(Font_family) + factor(item_number) + factor(Food_Preference) + Income + Age + Male + factor(Region) + factor(item1_font), data = df)
# 
# ATE_model_Price_Index$cluster1.vcov <- cluster.vcov(ATE_model_Price_Index, ~ Respondent.ID)
# 
# stargazer(
#           ATE_model_Price_Index, 
#           type = "text", 
#           se=list(sqrt(diag(vcovHC(ATE_model_Price_Index))))
#           )

#Treatment Distribution

d[, table(Serif, Font_family)]

hist(d$Age, breaks = 30, main = "", xlab = "Age")
hist(d$Male, breaks = 2, main = "", xlab = "Gender")

summary(d)


#Price

hist(d[, Item_Price], breaks = 30, main = 'Histogram of Price', xlab = 'Price')

hist(df[, price_index], breaks = 10, main = 'Histogram of Price Index', xlab = 'Price Index')
```

#Age Group

hist(d[, Age_Question], breaks = 20, main = 'Histogram of Age', xlab = 'Age', xlim = range(0, 100))


#Income Level

hist(d[, Income_Question], breaks = 30, main = 'Histogram of Income', xlab = 'Income')


#covariate balance check

summary(d$Age_Question)

# age_check <- lm(Age_Question ~ serif + factor(font_family) + factor(item_number), data = d)
# income_check <- lm(Income_Question ~ serif + factor(font_family) + factor(item_number), data = d)

#gender_check <- lm(male ~ serif + factor(font_family) + factor(item_number), data = d)
#region_check <- lm(Region ~ serif + factor(font_family) + factor(item_number), data = d)

#stargazer(age_check, 
#          income_check, 
#          gender_check, 
#          type = "text")

model_simple <- lm(Serif ~ 1, data = d)
model_covariates <- lm(Serif ~ 1 + Age + Income + Male + factor(Region) + factor(Food_Preference), data = d)

anova(model_simple, model_covariates)


#treatment effect

# ATE_model_short <- lm(Item_Price ~ serif + factor(font_family) + factor(item_number) + factor(Food_Preference)+ Income_Question + Age_Question + male, data = d)
# ATE_model_short$cluster1.vcov <- cluster.vcov(ATE_model_short, ~ Respondent.ID)

#short model
ATE_model_short <- lm(Item_Price ~ Serif * factor(Font_family) + factor(item_number) , data = d)

# ATE_model_short <- lm(Item_Price ~ serif * factor(font_family) + factor(Respondent.ID), data = d)
# ATE_model_short$cluster1.vcov <- cluster.vcov(ATE_model_short, ~ Respondent.ID)

#long model
ATE_model_long <- lm(Item_Price ~ Serif * factor(Font_family) + factor(item_number) + Income + Age + Male + factor(Food_Preference) + factor(Region), data = d)

#full model
ATE_model_full <- lm(Item_Price ~ Serif * factor(Font_family) * factor(item_number) + Income + Age + Male + factor(Food_Preference) + factor(Region), data = d)

stargazer(ATE_model_short,
          ATE_model_long,
          ATE_model_full,
          type = "text", 
          intercept.bottom = FALSE,
          se=c(list(sqrt(diag(vcovHC(ATE_model_short)))), list(sqrt(diag(vcovHC(ATE_model_long)))), list(sqrt(diag(vcovHC(ATE_model_full))))),
          omit = c(":"
                   , "Region)M", "Region)E", "Region)N", "Region)P", "Region)S", "Region)West North" #ignore insignificant region
                   , "Food_Preference)O", "Food_Preference)P", "Food_Preference)Vege"), #ignore insignificant food preference
          add.lines = c(list(c("Covariates?", "No", "Yes", "Yes")), list(c("Interaction between Serif and Font?", "No", "Yes", "Yes")) 
                        , list(c("Interaction between Serif, Font, and Item?", "No", "No", "Yes")))
)

coef(ATE_model_full)


#Randomization Inference

d_base <- d[, .(Item_Price, Serif, Font_family, item_number, Income, Age, Male, Food_Preference, Region, Item_Price)]

font_assign <- function(d) d[,  ':='(Font_Family_Assign = sample(c('PT', 'Josefin', 'Roboto'), nrow(d), replace = TRUE)
                                     , Serif_Assign = sample(c(1,0), nrow(d), replace = TRUE))]

# head(font_assign(d_base))
# coef(lm(Item_Price ~ Serif_Assign * factor(Font_Family_Assign) * factor(item_number) + Income + Age + Male, data = font_assign(d)))[2]

est.cace <- function(d) coef(lm(Item_Price ~ Serif_Assign * factor(Font_Family_Assign) * factor(item_number) + Income + Age + Male, data = font_assign(d)))[2]

#simulation
simulation.sharp.null <- replicate(10000, est.cace(d_base))
obs.cace <- coef(ATE_model_full)[2]

plot(density(simulation.sharp.null), main = "")
abline(v=obs.cace, lty = 2)
mean(abs(obs.cace) <= abs(simulation.sharp.null))


#power analysis

library(pwr)
library(effsize)
library(ggplot2)
#effect size
eff_size <- cohen.d(d[Serif == 0,Item_Price], d[Serif == 1,Item_Price], pooled = TRUE)$estimate


#power curve
ptab <- NULL

for (i in seq(0.06,0.995, by = 0.005)){
  pwr_n <- pwr.t.test(sig.level = 0.05, power = i, type = "two.sample",
                      d = eff_size, alternative="two.sided")
  
  ptab <- rbind(ptab, pwr_n$n)
}

i <- seq(0.06,0.995, by = 0.005)

plot(ptab, i, type = "l", xlab = "Sample Size", ylab = "Power")
abline(v = 1446, lty = 2)
abline(h = 0.3925607, lty = 2)
