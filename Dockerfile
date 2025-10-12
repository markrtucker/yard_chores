# Use a base R image, for example, from the Rocker Project
FROM rocker/shiny:4.3.1

# Install system dependencies if needed (e.g., for certain R packages)
# RUN apt-get update -qq && apt-get install -y \
#     libssl-dev \
#     libcurl4-gnutls-dev \
#     # Add other system dependencies as required

# Copy the Shiny application files into the container
COPY yard /srv/shiny-server/yard_app

# Install R packages required by your Shiny application
# You can list them one by one or use a renv.lock file
# For example, to install 'shiny' and 'ggplot2':
RUN R -e "install.packages(c("shiny", 
    "shinyjs", 
    "bslib", 
    "httr", 
    "jsonlite", 
    "plotly", 
    "DT", 
    "dplyr", 
    "lubridate", 
    "readr", ), repos='https://cran.rstudio.com/')"

# If using renv for package management:
# COPY renv.lock .
# RUN R -e "renv::restore()"

# Expose the default Shiny Server port
EXPOSE 8787

# Command to run Shiny Server when the container starts
CMD ["/usr/bin/shiny-server"]