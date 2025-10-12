# Load required libraries
library(shiny)
library(shinyjs)
library(bslib)
library(httr)
library(jsonlite)
library(plotly)
library(DT)
library(dplyr)
library(lubridate)
library(readr)



# Source the UI and server components
source("utils.R")
source("ui.R")
source("server.R")

# Create the Shiny app
app <- shinyApp(ui = ui, server = server)

# Run the Shiny app with specific host and port
runApp(app, host = "0.0.0.0", port = 8787)