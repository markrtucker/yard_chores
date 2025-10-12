

today <- Sys.Date()
initial_chores <- data.frame(
  id = 1:5,
  name = c("Mow lawn once", "Water plants daily", "Trim hedges weekly", "Fertilize grass monthly", "Clean gutters quarterly"),
  due_date = c(today - 2, today + 3, today - 1, today + 5, today + 10),  # Mix of overdue and upcoming
  frequency = c("once", "daily", "weekly", "monthly", "quarterly"),
  description = c("Cut grass in front and back yard", "Water all flower beds", 
                  "Trim hedge along driveway", "Apply spring fertilizer", 
                  "Remove leaves and debris"),
  stringsAsFactors = FALSE
)

# Calculate next due date for recurring tasks
calculate_next_due_date <- function(current_due_date, frequency) {
  current_date <- as.Date(current_due_date)
  
  switch(frequency,
    "daily" = current_date + 1,
    "weekly" = current_date + 7,
    "monthly" = {
      # Add one month, handling month-end dates properly
      next_month <- seq(current_date, by = "month", length.out = 2)[2]
      next_month
    },
    "quarterly" = {
      # Add 3 months
      next_quarter <- seq(current_date, by = "3 months", length.out = 2)[2]
      next_quarter
    },
    "yearly" = {
      # Add one year
      next_year <- seq(current_date, by = "year", length.out = 2)[2]
      next_year
    },
    current_date  # fallback for "once" or unknown frequency
  )
}

# Utility functions for the weather app

# Function to fetch weather data from Open-Meteo API
# Function to fetch weather data from Open-Meteo API
fetch_weather_data <- function() {
    api_url <- "https://api.open-meteo.com/v1/forecast?latitude=42.3459&longitude=-71.5523&hourly=temperature_2m,soil_temperature_6cm,soil_moisture_0_to_1cm,soil_moisture_1_to_3cm,soil_moisture_3_to_9cm,dew_point_2m,precipitation_probability,precipitation,soil_temperature_0cm,soil_temperature_18cm&current=temperature_2m&timezone=America%2FNew_York&past_days=60&wind_speed_unit=mph&temperature_unit=fahrenheit&precipitation_unit=inch"
  
  tryCatch({
    response <- GET(api_url)
    if (status_code(response) == 200) {
      data <- fromJSON(content(response, "text", encoding = "UTF-8"))
      
      # Create a data frame from hourly data
      hourly_df <- data.frame(
        datetime = lubridate::ymd_hm(data$hourly$time),
        temperature_2m = data$hourly$temperature_2m,
        dew_point_2m = data$hourly$dew_point_2m,
        precipitation_probability = data$hourly$precipitation_probability,
        precipitation = data$hourly$precipitation,
        soil_temp_0cm = data$hourly$soil_temperature_0cm,
        soil_temp_6cm = data$hourly$soil_temperature_6cm,
        soil_temp_18cm = data$hourly$soil_temperature_18cm
      )

      daily_avg <- hourly_df %>%
        mutate(date = as.Date(datetime)) %>%
        group_by(date) %>%
        summarise(
          avg_soil_temp_0cm = mean(soil_temp_0cm, na.rm = TRUE),
          avg_soil_temp_6cm = mean(soil_temp_6cm, na.rm = TRUE),
          max_temp = max(temperature_2m, na.rm = TRUE),
          min_temp = min(temperature_2m, na.rm = TRUE),
          # avg_soil_temp_combined = mean((soil_temp_0cm + soil_temp_6cm) / 2, na.rm = TRUE),
          .groups = "drop") %>%
        mutate(datetime_mid = as.POSIXct(paste(date, "12:00:00"))) # Move this outside summarise
      
      # # Calculate weekly averages  
      weekly_avg <- hourly_df %>%
        mutate(
          date = as.Date(datetime),
          week = floor_date(date, "week", week_start = 1)
        ) %>%
        group_by(week) %>%
        summarise(
          avg_soil_temp_combined = mean((soil_temp_0cm + soil_temp_6cm) / 2, na.rm = TRUE),
          .groups = "drop") %>%
        mutate(datetime_mid = as.POSIXct(paste(week + 3, "12:00:00"))) # Move this outside summarise
      
      list(
        current = data$current,
        hourly = hourly_df,
        daily = daily_avg,
        weekly = weekly_avg
      )
    } else {
      NULL
    }
  }, error = function(e) {
    print(e)
    NULL
  })
}

# Function to create soil plot
create_soil_plot <- function(hourly_data, daily_data, weekly_data) {
  plot_ly() %>%
    add_trace(data = daily_data, x = ~datetime_mid, y = ~avg_soil_temp_0cm, 
              type = 'scatter', mode = 'lines', name = 'Daily Avg (0cm)',
              line = list(color = 'darkblue', width = 1)) %>% 
    add_trace(data = daily_data, x = ~datetime_mid, y = ~avg_soil_temp_6cm,
              type = 'scatter', mode = 'lines', name = 'Daily Avg (6cm)',
              line = list(color = 'darkgreen', width = 1)) %>%
    add_trace(data = weekly_data, x = ~datetime_mid, y = ~avg_soil_temp_combined,
              type = 'scatter', mode = 'lines', name = 'Weekly Avg (0cm & 6cm)',
              line = list(color = 'navy', width = 4, dash = 'dash')) %>%
    layout(title = "Combined Soil Temperature Trends (0cm & 6cm)",
           xaxis = list(title = ""),
           yaxis = list(title = "Soil Temperature (°F)"),
           shapes = list(
            list(
              type = "line",
              x0 = min(daily_data$datetime_mid),
              x1 = max(daily_data$datetime_mid),
              y0 = 50,
              y1 = 50,
              line = list(color = "red", width = 1, dash = "dash")
            )
          ),
           legend = list(
             y = 0.5,       # Vertically center the legend (0.5 = middle)
             yanchor = 'middle'  # Anchor the legend at its middle point
           ))
  
}

# Function to create temperature plot
# Function to create temperature plot
create_temperature_plot <- function(hourly_data, daily_data) {
  plot_ly() %>%
    add_trace(data = hourly_data, x = ~datetime, y = ~dew_point_2m, 
              name = 'Dew Point', mode = 'lines',
              line = list(color = 'lightblue', width = 1)) %>%
    add_trace(data = daily_data, x = ~datetime_mid, y = ~max_temp,
              type = 'scatter', mode = 'lines', name = 'Daily High',
              line = list(color = 'maroon', width = 3)) %>%
    add_trace(data = daily_data, x = ~datetime_mid, y = ~min_temp,
              type = 'scatter', mode = 'lines', name = 'Daily Low',
              line = list(color = 'darkblue', width = 3)) %>%
    layout(title = "Temperature Trends (Daily Highs/Lows + Dew Point)",
           xaxis = list(title = ""),
           yaxis = list(title = "Temperature (°F)"),
           legend = list(
             y = 0.5,       # Vertically center the legend (0.5 = middle)
             yanchor = 'middle'  # Anchor the legend at its middle point
           ))
}
