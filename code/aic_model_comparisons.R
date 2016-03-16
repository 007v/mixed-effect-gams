library(mgcv)
library(MASS)
library(cowplot)
library(ggplot2)
library(dplyr)
library(tidyr)

source("code/functions.R")

set.seed(1)
#starting parameters  ####  
n_data = 150 #number of data points per group
n_groups = 12 # number of groups

total_amp = 1
noise  = total_amp/3 #variance of random noise around main function

# variability of the main and individual level functions. Equal to the variance
# of individual points drawn from the function at large distances from one another.
# set so that the variance of the main and individual level-functions will sum
# to a fixed value
main_func_amp = 0.5
indiv_func_amp = total_amp-main_func_amp #var

# The length-scale parameter for the main and individual-level functions. Points
# with x-values that are more distant from each other than the length scale
# will be only weakly correlated
main_func_scale= 0.1
func_scale_diff= 0.5 #vary this parameter to move from similar smoothnesses (0) to 
#large differences in smoothness (Inf). I would keep this between 0 and 1. 
indiv_func_scale = 0.1*(1:n_groups)^(-func_scale_diff*seq(-1,1,length=n_groups))


x = seq(0,1,length=n_data)

#generating main function and group-level functions ####
#Functions are genated using a Gaussian process with 
main_func = generate_smooth_func(x,n_funcs = 1,main_func_scale,main_func_amp)
indiv_func = matrix(0, nrow=n_data, ncol=n_groups)
for(i in 1:n_groups){
  indiv_func[,i] = generate_smooth_func(x,1,indiv_func_scale[i],
                                  indiv_func_amp)
}

#Plots the global and individual-level functions
matplot(x, indiv_func,type='l',ylim = range(cbind(main_func,indiv_func)))
points(x, main_func[,1],type="l",lwd= 2)

full_func = indiv_func

#adding individual and global functions together
for(i in 1:n_groups){
  full_func[,i] = full_func[,i] + main_func[,1]
}
colnames(full_func) = paste("G",1:n_groups,sep="")

full_data = full_func %>% 
  as.data.frame(.) %>%
  mutate(x = x, global_func = main_func[,1],
         indiv = 1:n_data)%>%
  gather(group,func_val, -x, -global_func, -indiv) %>%
  mutate(y= rnorm(n(),func_val,sqrt(noise)),
         indiv = paste(group, indiv, sep="_"))

#### Fitting different variants of the 5 main models
model_1 = bam(y~s(x,k=15),data=full_data,method="fREML", select=T)
model_2a = update(model_1,formula. = y~s(x,k=15)+s(x,group,bs="fs",k=15))
model_2b = update(model_1,formula. = y~s(x,k=15)+s(x,group,bs="fs",m=1,k=15))
model_2c = update(model_1,formula. = y~ti(x,k=15)+ti(x,group,bs=c("tp","re"),k=c(15,n_groups))+
                    ti(group,bs="re",k=n_groups))
model_3a = update(model_1,formula. = y~s(x,k=15)+s(x,by=group,k=15)+group)
model_3b = update(model_1,formula. = y~s(x,k=15)+s(x,by=group,m=1,k=15)+group)
model_4a = update(model_1,formula. = y~s(x,group,bs="fs",k=15))
model_4b = update(model_1,formula. = y~s(x,group,bs="fs",m=1,k=15))
model_4c = update(model_1,formula. = y~te(x,group,bs=c("tp","re"),k=c(15,n_groups))+
                    te(group,bs="re",k=n_groups))
model_5 = update(model_1,formula. = y~s(x,by=group,k=15))


#### AIC table for model fits
AIC_table = AIC(model_1, model_2a,model_2b,model_2c,
                model_3a, model_3b,model_4a,model_4b,model_4c,model_5)
AIC_table$delta_AIC = round(AIC_table$AIC-min(AIC_table$AIC))
AIC_table$dev_expl = unlist(lapply(list(model_1, model_2a,model_2b,model_2c,
                                   model_3a, model_3b,model_4a,model_4b,model_4c,model_5),
                                   get_r2))
AIC_table$dev_expl = round(AIC_table$dev_expl,3)