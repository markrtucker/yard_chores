# Server logic
server <- function(input, output, session) {
  chores_file <- "/home/shiny/yard_chores/yard_chores.csv"

  
  # Function to save chores to file
  save_chores <- function(chores_df) {
    write_csv(chores_df, chores_file)
    
  }
  
  # Function to load chores from file
  load_chores <- function() {
    if (file.exists(chores_file)) {
      tryCatch({
        df <- read_csv(chores_file)
        # Migration: Add base_on_completion column if it doesn't exist
        if (!"base_on_completion" %in% names(df)) {
          df$base_on_completion <- FALSE
        }
        df
      }, error = function(e) {
        # Return empty data frame if file is corrupted
        data.frame(
          id = integer(0),
          name = character(0),
          frequency = character(0),
          description = character(0),
          due_date = as.Date(character(0)),
          base_on_completion = logical(0),
          stringsAsFactors = FALSE
        )
      })
    } else {
      # Return empty data frame if file doesn't exist
      data.frame(
        id = integer(0),
        name = character(0),
        frequency = character(0),
        description = character(0),
        due_date = as.Date(character(0)),
        base_on_completion = logical(0),
        stringsAsFactors = FALSE
      )
    }
  }
  
  # Helper function to update chores and save to file
  update_and_save_chores <- function(new_chores) {
    chores(new_chores)
    save_chores(new_chores)
  }

  # Initialize reactive values to store chores - load from file on startup
  loaded_chores <- load_chores()
  # If no saved chores exist, use initial sample data
  if (nrow(loaded_chores) == 0) {
    loaded_chores <- data.frame(
      id = integer(0),
      name = character(0),
      frequency = character(0),
      description = character(0),
      due_date = as.Date(character(0)),
      base_on_completion = logical(0),
      stringsAsFactors = FALSE
    )
    save_chores(loaded_chores)
  }
  
  # Initialize reactive values to store chores - load from file on startup
  chores <- reactiveVal(load_chores())

  # Reactive value to store weather data
  weather_data <- reactiveVal(NULL)

  # Generate unique ID for new chores
  # next_id <- reactiveVal(max(chores()$id) + 1)

  # Fetch data on app start
  observe({
    weather_data(fetch_weather_data())
  })
  
  # Refresh data when button is clicked
  observeEvent(input$refresh_data, {
    showNotification("Refreshing weather data...", type = "message")
    weather_data(fetch_weather_data())
  })
  
  # Current temperature output
  output$current_temp <- renderText({
    data <- weather_data()
    if (!is.null(data) && !is.null(data$current)) {
      paste0(round(data$current$temperature_2m, 1), "°F")
    } else {
      "Loading..."
    }
  })
  
  # Temperature trends plot
  output$temp_plot <- renderPlotly({
    data <- weather_data()
    if (!is.null(data)) {
      create_temperature_plot(data$hourly, data$daily)
    }
  })
  
  # Soil data plot
  output$soil_plot <- renderPlotly({
    data <- weather_data()
    if (!is.null(data)) {
      create_soil_plot(data$hourly, data$daily, data$weekly)
    }
  })
  
  # Precipitation plot
  output$precip_plot <- renderPlotly({
    data <- weather_data()
    if (!is.null(data)) {
      create_precipitation_plot(data$hourly)
    }
  })
  
  # Data table
  output$data_table <- DT::renderDataTable({
    data <- weather_data()
    if (!is.null(data)) {
      create_data_table(data$hourly)
    }
  })

  
  # Render upcoming chores
  output$chores_list <- renderUI({
    current_chores <- chores()
    today <- Sys.Date()
    
    if (nrow(current_chores) == 0) {
      return(div(
        class = "text-center text-muted p-4",
        h4("No chores scheduled!"),
        p("Add some chores in the Manage tab.")
      ))
    }
    
    # Sort by due date
    current_chores <- current_chores[order(current_chores$due_date), ]
    
    chore_items <- lapply(1:nrow(current_chores), function(i) {
      chore <- current_chores[i, ]
      is_overdue <- chore$due_date < today
      due_today <- chore$due_date == today
      
      # Determine card class based on due date
      card_class <- if (is_overdue) {
        "border-danger bg-danger-subtle"
      } else if (due_today) {
        "border-warning bg-warning-subtle"
      } else {
        "border-secondary"
      }
      
      # Format due date display
      due_text <- if (is_overdue) {
        paste("OVERDUE:", format(chore$due_date, "%B %d, %Y"))
      } else if (due_today) {
        "DUE TODAY"
      } else {
        paste("Due:", format(chore$due_date, "%B %d, %Y"))
      }
      
      div(
        class = paste("card mb-3", card_class),
        div(
          class = "card-body",
          div(
            class = "d-flex justify-content-between align-items-start",
            div(
              h5(chore$name, class = "card-title"),
              p(due_text, class = if(is_overdue) "text-danger fw-bold" else if(due_today) "text-warning fw-bold" else "text-muted"),
              p(paste("Frequency:", chore$frequency), class = "text-muted small")
            ),
            actionButton(
              inputId = paste0("complete_", chore$id),
              label = "Mark Complete",
              class = "btn btn-success btn-sm"
            )
          )
        )
      )
    })
    
    do.call(tagList, chore_items)
  })

  # Handle completing chores with a simpler approach
  # Use a reactive value to track the last processed button value for each button
  last_button_values <- reactiveVal(list())
  
  observeEvent(reactiveValuesToList(input), {
    current_chores <- chores()
    last_vals <- last_button_values()
    
    # Get all input names that start with "complete_"
    input_list <- reactiveValuesToList(input)
    complete_button_names <- names(input_list)[grepl("^complete_", names(input_list))]
    
    for (button_name in complete_button_names) {
      button_value <- input_list[[button_name]]
      
      # Only process if button value is > 0 and different from last processed value
      if (!is.null(button_value) && button_value > 0) {
        last_value <- last_vals[[button_name]]
        
        if (is.null(last_value) || button_value != last_value) {
          # Update the last processed value for this button
          last_vals[[button_name]] <- button_value
          last_button_values(last_vals)
          
          # Extract chore ID from button name
          chore_id <- as.numeric(gsub("complete_", "", button_name))
          
          # Find the completed task
          completed_task <- current_chores[current_chores$id == chore_id, ]
          
          if (nrow(completed_task) > 0) {
            # Check if it's a recurring task
            if ("frequency" %in% names(completed_task) &&
                !is.na(completed_task$frequency) &&
                completed_task$frequency != "once") {

              # Determine base date for calculation
              base_date <- if ("base_on_completion" %in% names(completed_task) && completed_task$base_on_completion) {
                Sys.Date()  # Use today (completion date)
              } else {
                completed_task$due_date  # Use original due date (current behavior)
              }

              # Calculate next due date
              next_due_date <- calculate_next_due_date(completed_task$due_date, completed_task$frequency, base_date)

              # Update the task with new due date
              current_chores[current_chores$id == chore_id, "due_date"] <- next_due_date
              update_and_save_chores(current_chores)
              
              showNotification(
                paste("Recurring task completed! Next due:", format(next_due_date, "%Y-%m-%d")), 
                type = "message",
                duration = 5
              )
            } else {
              # Remove the one-time completed chore
              updated_chores <- current_chores[current_chores$id != chore_id, ]
              update_and_save_chores(updated_chores)
              
              showNotification(
                paste("Task completed!"), 
                type = "message",
                duration = 3
              )
            }
          }
        }
      }
    }
  }, ignoreInit = TRUE)
  
  # Task Management Page Logic
  
  # Reactive value to track if we're editing a task
  editing_task <- reactiveVal(NULL)
  
  # Render chores table for management page
  output$chores_table <- DT::renderDataTable({
    current_chores <- chores()
    
    if (nrow(current_chores) > 0) {
      # Add action buttons to each row
      current_chores$Actions <- sapply(current_chores$id, function(id) {
        paste0(
          '<button class="btn btn-sm btn-warning edit-btn" data-id="', id, '">Edit</button> ',
          '<button class="btn btn-sm btn-danger delete-btn" data-id="', id, '">Delete</button>'
        )
      })
    }
    
    DT::datatable(
      current_chores,
      escape = FALSE,
      options = list(
        columnDefs = list(
          list(targets = c(0), visible = FALSE) # Hide ID column
        ),
        pageLength = 10,
        dom = 'frtip'
      ),
      callback = DT::JS("
        table.on('click', '.edit-btn', function() {
          var id = $(this).data('id');
          Shiny.setInputValue('edit_task_id', id);
        });
        table.on('click', '.delete-btn', function() {
          var id = $(this).data('id');
          Shiny.setInputValue('delete_task_id', id);
        });
      ")
    )
  })
  
  # Add new task
  observeEvent(input$add_task_btn, {
    req(input$task_name)
    
    current_chores <- chores()
    new_id <- if(nrow(current_chores) > 0) max(current_chores$id) + 1 else 1
    
    new_task <- data.frame(
      id = new_id,
      name = input$task_name,
      due_date = as.Date(input$task_due_date),
      frequency = input$task_frequency,
      description = ifelse(is.null(input$task_description) || input$task_description == "",
                          "", input$task_description),
      base_on_completion = input$task_base_on_completion,
      stringsAsFactors = FALSE
    )
    
    updated_chores <- rbind(current_chores, new_task)
    update_and_save_chores(updated_chores)
    
    # Clear form
    updateTextInput(session, "task_name", value = "")
    updateTextAreaInput(session, "task_description", value = "")
    updateDateInput(session, "task_due_date", value = Sys.Date())
    updateSelectInput(session, "task_frequency", selected = "once")
    updateCheckboxInput(session, "task_base_on_completion", value = TRUE)

    showNotification("Task added successfully!", type = "message")
  })
  
  # Handle edit task
  observeEvent(input$edit_task_id, {
    current_chores <- chores()
    task_to_edit <- current_chores[current_chores$id == input$edit_task_id, ]
    
    if (nrow(task_to_edit) > 0) {
      editing_task(input$edit_task_id)
      
      # Populate form with existing data
      updateTextInput(session, "task_name", value = task_to_edit$name)
      updateDateInput(session, "task_due_date", value = as.Date(task_to_edit$due_date))
      updateSelectInput(session, "task_frequency",
                        selected = ifelse("frequency" %in% names(task_to_edit), task_to_edit$frequency, "once"))
      updateCheckboxInput(session, "task_base_on_completion",
                         value = ifelse("base_on_completion" %in% names(task_to_edit), task_to_edit$base_on_completion, FALSE))
      updateTextAreaInput(session, "task_description", value = task_to_edit$description)
      
      # Show/hide buttons
      shinyjs::hide("add_task_btn")
      shinyjs::show("update_task_btn")
      shinyjs::show("cancel_edit_btn")
    }
  })
  
  # Handle update task
  observeEvent(input$update_task_btn, {
    req(editing_task(), input$task_name)
    
    current_chores <- chores()
    task_id <- editing_task()
    
    # Update the task
    current_chores[current_chores$id == task_id, "name"] <- input$task_name
    current_chores[current_chores$id == task_id, "due_date"] <- as.Date(input$task_due_date)
    current_chores[current_chores$id == task_id, "frequency"] <- input$task_frequency
    current_chores[current_chores$id == task_id, "base_on_completion"] <- input$task_base_on_completion
    current_chores[current_chores$id == task_id, "description"] <- ifelse(
      is.null(input$task_description) || input$task_description == "",
      "", input$task_description
    )
    
    update_and_save_chores(current_chores)
    editing_task(NULL)
    
    # Clear form and reset buttons
    updateTextInput(session, "task_name", value = "")
    updateTextAreaInput(session, "task_description", value = "")
    updateDateInput(session, "task_due_date", value = Sys.Date())
    updateSelectInput(session, "task_frequency", selected = "once")
    updateCheckboxInput(session, "task_base_on_completion", value = FALSE)

    shinyjs::show("add_task_btn")
    shinyjs::hide("update_task_btn")
    shinyjs::hide("cancel_edit_btn")

    showNotification("Task updated successfully!", type = "message")
  })
  
  # Handle cancel edit
  observeEvent(input$cancel_edit_btn, {
    editing_task(NULL)

    # Clear form and reset buttons
    updateTextInput(session, "task_name", value = "")
    updateTextAreaInput(session, "task_description", value = "")
    updateDateInput(session, "task_due_date", value = Sys.Date())
    updateSelectInput(session, "task_frequency", selected = "once")
    updateCheckboxInput(session, "task_base_on_completion", value = FALSE)

    shinyjs::show("add_task_btn")
    shinyjs::hide("update_task_btn")
    shinyjs::hide("cancel_edit_btn")
  })
  
  # Handle delete task
  observeEvent(input$delete_task_id, {
    current_chores <- chores()
    updated_chores <- current_chores[current_chores$id != input$delete_task_id, ]
    update_and_save_chores(updated_chores)
    
    showNotification("Task deleted successfully!", type = "message")
  })

}
