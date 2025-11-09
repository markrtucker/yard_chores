# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Shiny application for tracking weather conditions and managing yard work tasks. The app integrates multiple weather data sources (Tomorrow.io widgets and Open-Meteo API) with a task management system for scheduling and completing yard chores.

## Running the Application

### Local Development
```r
# From the R/ directory
Rscript app.R
```
The app will start on `http://0.0.0.0:8787`

### Docker
```bash
docker build -t yard-chores .
docker run -p 8787:8787 yard-chores
```

## Architecture

### File Structure
- **R/global.R**: Loads all required libraries and sources UI/server components
- **R/app.R**: Entry point that creates and runs the Shiny app
- **R/ui.R**: UI definition with two main nav panels (Dashboard, Manage Tasks)
- **R/server.R**: Server logic for weather data, task management, and reactive updates
- **R/utils.R**: Utility functions for weather API calls, plotting, and date calculations

### Key Components

**Task Management System**
- Tasks stored in CSV file at `/home/shiny/yard_chores/yard_chores.csv`
- Supports both one-time and recurring tasks (daily, weekly, monthly, quarterly, yearly)
- Recurring tasks automatically calculate next due date when marked complete
- One-time tasks are removed upon completion
- Task IDs are auto-incremented integers

**Weather Data Integration**
- Tomorrow.io: Embedded JavaScript widgets for forecast visualization
- Open-Meteo API: Custom plots for air temperature, soil temperature (0cm, 6cm, 18cm), and precipitation
- API endpoint includes 60 days of historical data + forecast
- Location hardcoded to coordinates: 42.3459, -71.5523

**Reactive Data Flow**
- `chores()` reactiveVal stores task list, automatically persisted to CSV on changes
- `weather_data()` reactiveVal stores API response, refreshed on demand
- Dynamic button generation for task completion uses `observeEvent` with `reactiveValuesToList(input)` to handle dynamically created action buttons
- Button state tracking via `last_button_values()` prevents duplicate completion processing

## Important Implementation Details

### Date Calculations
The `calculate_next_due_date()` function in R/utils.R:157 handles recurring task scheduling. Uses `seq()` with `by` parameter for month/quarter/year increments to properly handle edge cases like month-end dates.

### Dynamic UI Elements
Task completion buttons are generated dynamically in R/server.R:176 with IDs in format `complete_{id}`. The observer pattern at R/server.R:192 monitors all inputs matching the `complete_` prefix pattern.

### Task Editing Flow
- Edit mode controlled by `editing_task()` reactiveVal (stores ID or NULL)
- Clicking Edit populates form and swaps Add/Update/Cancel button visibility via shinyjs
- Edit mode must be cleared before adding new tasks

### Data Persistence
All task operations use `update_and_save_chores()` helper function (R/server.R:42) which updates reactive value AND writes to CSV atomically.

## Dependencies

Key R packages:
- shiny, shinyjs: Core app framework
- bslib: Bootstrap 5 theming
- httr, jsonlite: API communication
- plotly: Interactive plots
- DT: DataTables for task management
- dplyr, lubridate, readr: Data manipulation

## Common Issues

**CSV File Path**: The application expects the CSV file at `/home/shiny/yard_chores/yard_chores.csv`. For local development, this path may need adjustment in R/server.R:3.

**Weather API Coordinates**: Location is hardcoded in R/utils.R:46. Update the API URL latitude/longitude parameters to change location.

**Duplicate Task Completions**: The button tracking mechanism at R/server.R:190-210 prevents the same button click from being processed multiple times by comparing against `last_button_values()`.
