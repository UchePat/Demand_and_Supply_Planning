# Demand & Supply Planning with R
# Presentation of the 3 functions of the package planr for Demand and Supply Planning using R:
# - to calculate projected inventories and coverages : light_proj_inv()
# - to calculate and analyze projected inventories and coverages : proj_inv()
# - to calculate a Replenishment Plan (also called DRP : Distribution Requirement Planning) : drp()

library(dplyr)
library(lubridate)
library(planr)
library(tidyverse)
library(shiny)

# for the tables
library(reactable)
library(reactablefmtr)

# for the charts
library(highcharter)

# Part 1 : Calculation of Projected Inventories & Coverages
# 1.1) Data Template
Period <- c("1/1/2020", "2/1/2020", "3/1/2020", "4/1/2020", "5/1/2020", 
            "6/1/2020", "7/1/2020", "8/1/2020", "9/1/2020", "10/1/2020", 
            "11/1/2020", "12/1/2020","1/1/2021", "2/1/2021", "3/1/2021", 
            "4/1/2021", "5/1/2021", "6/1/2021", "7/1/2021", "8/1/2021", 
            "9/1/2021", "10/1/2021", "11/1/2021", "12/1/2021")

Demand <- c(360, 458,300,264,140,233,229,208,260,336,295,226,336,434,276,
            240,116,209,205,183,235,312,270,201)

Opening_Inventories <- c(1310,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)

Supply_Plan <- c(0,0,0,0,0,2500,0,0,0,0,0,0,0,0,0,2000,0,0,0,0,0,0,0,0)


# assemble
my_demand_and_suppply <- data.frame(Period,
                                    Demand,
                                    Opening_Inventories,
                                    Supply_Plan)
head(my_demand_and_suppply)

# let's add a Product column with its value to d dataframe
my_demand_and_suppply$DFU <- "Product A"

# format the Period as a date
my_demand_and_suppply$Period <- as.Date(as.character(my_demand_and_suppply$Period), 
                                        format = '%m/%d/%Y')


# let's have a look at it
head(my_demand_and_suppply)
glimpse(my_demand_and_suppply)
# It contains some basic features:
# - a Product: it's an item, a SKU (Storage Keeping Unit), or a SKU at a location, also called a DFU (Demand Forecast Unit)
# - a Period of time : for example monthly or weekly buckets
# - a Demand : could be some sales forecasts, expressed in units
# - an Opening Inventory : what we hold as available inventories at the beginning of the horizon, expressed in units
# - a Supply Plan : the supplies that we plan to receive, expressed in units


# 1.2) Calculation
# Let's apply the light_proj_inv().
# We are going to calculate 2 new features for each DFU:
# - projected inventories
# - projected coverages, based on the Demand Forecasts
calculated_projection <- light_proj_inv(dataset = my_demand_and_suppply, 
                                        DFU = DFU, 
                                        Period = Period, 
                                        Demand =  Demand, 
                                        Opening = Opening_Inventories, 
                                        Supply = Supply_Plan)
calculated_projection


# 1.3) A nicer display
# We will use the libraries reactable and reactablefmtr to create a nice table.

# set a working df
df1 <- calculated_projection

# keep only the needed columns
df2 <- df1 %>% select(Period,
                      Demand,
                      Calculated.Coverage.in.Periods,
                      Projected.Inventories.Qty,
                      Supply)
head(df2)

# Using case_when() to format the values of d stated column using colors
df3 <- df2 %>% 
  mutate(f_colorpal = case_when(Calculated.Coverage.in.Periods > 6 ~ "#FFA500",
                                Calculated.Coverage.in.Periods > 2 ~ "#32CD32",
                                Calculated.Coverage.in.Periods > 0 ~ "#FFFF99",
                                TRUE ~ "#FF0000" ))



# create reactable
reactable(df3, resizable = TRUE, showPageSizeOptions = TRUE,
          
          striped = TRUE, highlight = TRUE, compact = TRUE,
          defaultPageSize = 20,
          
          columns = list(
            
            Demand = colDef(
              name = "Demand (units)",
              
              cell = data_bars(df3,                  # creates horizontal bar for each value
                               fill_color = "#3fc1c9",
                               text_position = "outside-end"
              )
              
            ),
            
            Calculated.Coverage.in.Periods = colDef(
              name = "Coverage (Periods)",
              maxWidth = 90,
              cell= color_tiles(df3, color_ref = "f_colorpal")
            ),
            
            f_colorpal = colDef(show = FALSE), # show = FALSE means its hidden. We did dis bcus f_colorpal object already used in color_tiles() above
            
            `Projected.Inventories.Qty`= colDef(
              name = "Projected Inventories (units)",
              format = colFormat(separators = TRUE, digits=0),
              
              style = function(value) {  # color coding the values using IF statements
                if (value > 0) {
                  color <- "#008000"
                } else if (value < 0) {
                  color <- "#e00000"
                } else {
                  color <- "#777"
                }
                list(color = color
                     #fontWeight = "bold"
                )
              }
            ),
            
            Supply = colDef(
              name = "Supply (units)",
              cell = data_bars(df3,
                               fill_color = "#3CB371",
                               text_position = "outside-end"
              )
            )
            
          ), # close columns lits
          
          columnGroups = list(
            colGroup(name = "Projected Inventories", 
                     columns = c("Calculated.Coverage.in.Periods",
                                 "Projected.Inventories.Qty"))
            
          )
          
) # close reactable


# 1.4) A little chart
# set a working df
df1 <- calculated_projection

# keep only the needed columns
df4 <- df1 %>% select(Period,
                      Projected.Inventories.Qty)

# create a value.index
df4$Value.Index <- if_else(df4$Projected.Inventories.Qty < 0, "Shortage", 
                           "Stock")


# spread
df5 <- df4 %>% spread(Value.Index, Projected.Inventories.Qty)
df5


#----------------------------------------------------

# Chart: Creating Connected dots chart/Bar chart denoting -ve values.
u <- highchart() %>% 
  hc_title(text = "Projected Inventories") %>%
  hc_subtitle(text = "in units") %>% 
  hc_add_theme(hc_theme_google()) %>%
  
  hc_xAxis(categories = df5$Period) %>%   # using Period column
  
  hc_add_series(name = "Stock",    # displays nothing since there's no Stock column/values
                color = "#32CD32",
                #dataLabels = list(align = "center", enabled = TRUE),
                data = df5$Stock) %>% 
  
  hc_add_series(name = "Shortage",   # creates connected dots chart using Shortage column values
                color = "#dc3220",
                #dataLabels = list(align = "center", enabled = TRUE),
                data = df5$Shortage) %>% 
  
  hc_chart(type = "column") %>%   # turns d connected dots chart into Bar chart
  hc_plotOptions(series = list(stacking = "normal"))

u 



# Part 2 : Calculation & analysis
# Now, let's consider some parameters such as : 
# - a target of minimum stock level 
# - a target of maximum stock level
# And then calculate the projected inventories and coverages - analyze those values vs those defined targets
# First, let's add some parameters to our initial database.

# 2.1) Data Template
# Define min & max coverages, through 2 parameters: 
# - Min.Stocks.Coverage 
# - Max.Stocks.Coverage
# Expressed in number of periods of coverages. 
# The periods can be in monthly buckets, weekly buckets, etc.
my_data_with_parameters <- my_demand_and_suppply

my_data_with_parameters$Min_Stocks_Coverage <- 2  # creates a new column with d stated value
my_data_with_parameters$Max_Stocks_Coverage <- 4

head(my_data_with_parameters)


# 2.2) Calculation
# Let's apply the proj_inv() function
mydata <- proj_inv(data = my_data_with_parameters, 
                   DFU = DFU, 
                   Period = Period, 
                   Demand =  Demand, 
                   Opening = Opening_Inventories, 
                   Supply = Supply_Plan,
                   Min.Cov = Min_Stocks_Coverage, 
                   Max.Cov = Max_Stocks_Coverage)

# see results
calculated_projection_and_analysis <- mydata

head(calculated_projection_and_analysis)


# 2.3) A nicer display
# First, let's create a function status_PI.Index()

# create a function status.PI.Index
status_PI.Index <- function(color = "#aaa", width = "0.55rem", 
                            height = width) {
  span(style = list(
    display = "inline-block",
    marginRight = "0.5rem",
    width = width,
    height = height,
    backgroundColor = color,
    borderRadius = "50%"
  ))
}

# And now let's create a reactable:
  
# set a working df
df6 <- calculated_projection_and_analysis


# remove not needed column
df7 <- df6[ , -which(names(df6) %in% c("DFU"))]


# create a f_colorpal field
df7 <- df7 %>% mutate(f_colorpal = case_when( Calculated.Coverage.in.Periods > 6 ~ "#FFA500", 
                                              Calculated.Coverage.in.Periods > 2 ~ "#32CD32",
                                              Calculated.Coverage.in.Periods > 0 ~ "#FFFF99",
                                              TRUE ~ "#FF0000" ))



#-------------------------
# Create reactable Table
reactable(df7, resizable = TRUE, showPageSizeOptions = TRUE, 
          
          striped = TRUE, highlight = TRUE, compact = TRUE, 
          defaultPageSize = 20,
          
          columns = list(
            
            
            Demand = colDef(
              name = "Demand (units)",
              
              cell = data_bars(df7, 
                               #round_edges = TRUE
                               #value <- format(value, big.mark = ","),
                               #number_fmt = big.mark = ",",
                               fill_color = "#3fc1c9",
                               #fill_opacity = 0.8, 
                               text_position = "outside-end"
              )
              
            ),
            
            
            
            Calculated.Coverage.in.Periods = colDef(
              name = "Coverage (Periods)",
              maxWidth = 90,
              
              cell= color_tiles(df7, color_ref = "f_colorpal")
            ),
            
            
            f_colorpal = colDef(show = FALSE), # hidden, just used for the coverages
            
            
            
            `Projected.Inventories.Qty`= colDef(
              name = "Projected Inventories (units)",
              format = colFormat(separators = TRUE, digits=0),
              
              style = function(value) {
                if (value > 0) {
                  color <- "#008000"
                } else if (value < 0) {
                  color <- "#e00000"
                } else {
                  color <- "#777"
                }
                list(color = color
                     #fontWeight = "bold"
                )
              }
            ),
            
            
            
            Supply.Plan = colDef(
              name = "Supply (units)",
              cell = data_bars(df7, 
                               
                               #round_edges = TRUE
                               #value <- format(value, big.mark = ","),
                               #number_fmt = big.mark = ",",
                               fill_color = "#3CB371",
                               #fill_opacity = 0.8, 
                               text_position = "outside-end"
              )
              #format = colFormat(separators = TRUE, digits=0)
              #number_fmt = big.mark = ","
            ),
            
            
            
            PI.Index = colDef(
              name = "Analysis",
              
              cell = function(value) {
                color <- switch(
                  value,
                  TBC = "hsl(154, 3%, 50%)",
                  OverStock = "hsl(214, 45%, 50%)",
                  OK = "hsl(154, 64%, 50%)",
                  Alert = "hsl(30, 97%, 70%)",
                  Shortage = "hsl(3, 69%, 50%)"
                )
                PI.Index <- status_PI.Index(color = color)
                tagList(PI.Index, value)
              }),
            
            
            
            `Safety.Stocks`= colDef(
              name = "Safety Stocks (units)",
              format = colFormat(separators = TRUE, digits=0)
            ),
            
            `Maximum.Stocks`= colDef(
              name = "Maximum Stocks (units)",
              format = colFormat(separators = TRUE, digits=0)
            ),
            
            `Opening.Inventories`= colDef(
              name = "Opening Inventories (units)",
              format = colFormat(separators = TRUE, digits=0)
            ),
            
            
            `Min.Stocks.Coverage`= colDef(name = "Min Stocks Coverage (Periods)"),
            
            `Max.Stocks.Coverage`= colDef(name = "Maximum Stocks Coverage (Periods)"),
            
            
            # ratios
            `Ratio.PI.vs.min`= colDef(name = "Ratio PI vs min"),
            
            `Ratio.PI.vs.Max`= colDef(name = "Ratio PI vs Max")
            
            
            
            
          ), # close columns lits
          
          columnGroups = list(
            colGroup(name = "Projected Inventories", columns = c("Calculated.Coverage.in.Periods", 
                                                                 "Projected.Inventories.Qty")),
            
            colGroup(name = "Stocks Levels Parameters", columns = c("Min.Stocks.Coverage", 
                                                                    "Max.Stocks.Coverage",
                                                                    "Safety.Stocks",
                                                                    "Maximum.Stocks")),
            
            colGroup(name = "Analysis Features", columns = c("PI.Index", 
                                                             "Ratio.PI.vs.min",
                                                             "Ratio.PI.vs.Max"))
            
          )
          
) # close reactable
# Compared to the previous table, we have here some additional information available: the calculated fields [Analysis Features] - based on safety & maximum stocks targets - useful for a mass analysis (Cockpit / Supply Risks Alarm), but perhaps too detailed for a focus on a SKU
# We also can notice that the minimum and maximum stocks coverages, initially expressed in Periods (of coverage) are converted in units. It's quite useful to chart the projected inventories vs those 2 thresholds for example.

# 2.4) A little chart
# set a working df
df6 <- calculated_projection_and_analysis

# Chart
p <- highchart() %>% 
  hc_add_series(name = "Max", color = "crimson", data = df6$Maximum.Stocks) %>% 
  hc_add_series(name = "min", color = "lightblue", data = df6$Safety.Stocks) %>% 
  hc_add_series(name = "Projected Inventories", color = "gold", data = df6$Projected.Inventories.Qty) %>% 
  
  hc_title(text = "Projected Inventories") %>%
  hc_subtitle(text = "in units") %>% 
  hc_xAxis(categories = df6$Period) %>% 
  #hc_yAxis(title = list(text = "Sales (units)")) %>% 
  hc_add_theme(hc_theme_google())

p
# We can visualize the periods when we are in Alert & OverStock, comparing to the minimum and Maximum stocks levels.


# Part 3) Replenishment Plan
# 3.1) Data Template
# Let's now add a few parameters to the initial database "my_demand_and_suppply"

df8 <- my_demand_and_suppply

df8$SSCov <- 2
df8$DRPCovDur <- 3
df8$Reorder.Qty <- 1
df8$DRP.Grid <- c("Frozen",
                  "Frozen",
                  "Frozen",
                  "Frozen",
                  "Frozen",
                  "Frozen",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free",
                  "Free")


# get Results
my_drp_template <- df8

head(my_drp_template)


# 3.2) Calculation
# Apply drp() function

# set a working df
df8 <- my_drp_template

# calculate drp
demo_drp <- drp(data = df8,
                DFU = DFU,
                Period = Period,
                Demand =  Demand,
                Opening = Opening_Inventories,
                Supply = Supply_Plan,
                SSCov = SSCov,
                DRPCovDur = DRPCovDur,
                MOQ = Reorder.Qty,
                FH = DRP.Grid
)

demo_drp


# 3.3) A nicer display
# set a working df
df9 <- demo_drp

# keep only the needed columns
df10 <- df9 %>% select(Period,
                      Demand,
                      DRP.Calculated.Coverage.in.Periods,
                      DRP.Projected.Inventories.Qty,
                      DRP.plan)

# replace missing values by zero
df10$DRP.plan[is.na(df10$DRP.plan)] <- 0
df10$DRP.Projected.Inventories.Qty[is.na(df10$DRP.Projected.Inventories.Qty)] <- 0

# create a f_colorpal field
df10 <- df10 %>% mutate(f_colorpal = case_when( DRP.Calculated.Coverage.in.Periods > 8 ~ "#FFA500",
                                              DRP.Calculated.Coverage.in.Periods > 2 ~ "#32CD32",
                                              DRP.Calculated.Coverage.in.Periods > 0 ~ "#FFFF99",
                                              TRUE ~ "#FF0000" ))



# create reactable
reactable(df10, resizable = TRUE, showPageSizeOptions = TRUE,
          
          striped = TRUE, highlight = TRUE, compact = TRUE,
          defaultPageSize = 20,
          
          columns = list(
            
            Demand = colDef(
              name = "Demand (units)",
              
              cell = data_bars(df10,
                               fill_color = "#3fc1c9",
                               text_position = "outside-end"
              )
              
            ),
            
            DRP.Calculated.Coverage.in.Periods = colDef(
              name = "Coverage (Periods)",
              maxWidth = 90,
              cell= color_tiles(df10, color_ref = "f_colorpal")
            ),
            
            f_colorpal = colDef(show = FALSE), # hidden, just used for the coverages
            
            `DRP.Projected.Inventories.Qty`= colDef(
              name = "Projected Inventories (units)",
              format = colFormat(separators = TRUE, digits=0),
              
              style = function(value) {
                if (value > 0) {
                  color <- "#008000"
                } else if (value < 0) {
                  color <- "#e00000"
                } else {
                  color <- "#777"
                }
                list(color = color
                     #fontWeight = "bold"
                )
              }
            ),
            
            DRP.plan = colDef(
              name = "Replenishment (units)",
              cell = data_bars(df10,
                               fill_color = "#3CB371",
                               text_position = "outside-end"
              )
            )
            
          ), # close columns lits
          
          columnGroups = list(
            colGroup(name = "Projected Inventories", columns = c("DRP.Calculated.Coverage.in.Periods",
                                                                 "DRP.Projected.Inventories.Qty"))
            
          )
          
) # close reactable


# 4.4) A little chart
# set a working df
df9 <- demo_drp



# Chart
p <- highchart() %>% 
  hc_add_series(name = "Max", color = "crimson", data = df9$Maximum.Stocks) %>% 
  hc_add_series(name = "min", color = "lightblue", data = df9$Safety.Stocks) %>% 
  hc_add_series(name = "Projected Inventories", color = "gold", data = df9$DRP.Projected.Inventories.Qty) %>% 
  
  hc_title(text = "(DRP) Projected Inventories") %>%
  hc_subtitle(text = "in units") %>% 
  hc_xAxis(categories = df9$Period) %>% 
  #hc_yAxis(title = list(text = "Sales (units)")) %>% 
  hc_add_theme(hc_theme_google())

p