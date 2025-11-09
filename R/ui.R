# UI definition
ui <- page_navbar(
  title = "Weather Dashboard",
  theme = bs_theme(version = 5),

  useShinyjs(),
  
  # Include the JavaScript SDK once for both widgets
  tags$script(HTML('
    (function(d, s, id) {
        if (d.getElementById(id)) {
            if (window.__TOMORROW__) {
                window.__TOMORROW__.renderWidget();
            }
            return;
        }
        const fjs = d.getElementsByTagName(s)[0];
        const js = d.createElement(s);
        js.id = id;
        js.src = "https://www.tomorrow.io/v1/widget/sdk/sdk.bundle.min.js";

        fjs.parentNode.insertBefore(js, fjs);
    })(document, "script", "tomorrow-sdk");
  ')),
  
  # Main dashboard page
  nav_panel(
    title = "Dashboard",
    value = "main",
    
    # First row with Tomorrow.io widgets
    layout_columns(
      col_widths = c(8, 4),
      # row_heights = c(3, 3, 3),
      
      # Weather forecast widget
      div(
        card(
          card_header("Weather Forecast (tomorrow.io)"),
          card_body(
            HTML('
              <div class="tomorrow"
                data-location-id="121280"
                data-language="EN"
                data-unit-system="IMPERIAL"
                data-skin="light"
                data-widget-type="upcoming"
                style="padding-bottom:22px;position:relative;"
              >
                <a
                  href="https://weather.tomorrow.io/"
                  rel="nofollow noopener noreferrer"
                  target="_blank"
                  style="position: absolute; bottom: 0; transform: translateX(-50%); left: 50%;"
                >
                  <img
                    alt="Powered by Tomorrow.io"
                    src="https://weather-website-client.tomorrow.io/img/powered-by.svg"
                    width="250"
                    height="18"
                  />
                </a>
              </div>
            ')
          )
        ),

        card(
          card_header("Air Temp Trends (Open-Meteo API)"),
          card_body(
            plotlyOutput("temp_plot", height = "268px")
          )
        ),

        card(
          card_header("Soil Temp Trends (Open-Meteo API)"),
          card_body(
            plotlyOutput("soil_plot", height = "268px")
          )
        )
      ),
      
      # Right column - Next Tasks
      card(
        card_header("Next Tasks"),
        card_body(
          uiOutput("chores_list")
        )
      )
    )
  ),
  
  # Task management page
  nav_panel(
    title = "Manage Tasks",
    value = "manage",
    
    layout_columns(
      col_widths = c(4, 8),
      
      # Add/Edit task form
      card(
        card_header("Add/Edit Task"),
        card_body(
          textInput("task_name", "Task Name:", placeholder = "Enter task name"),
          selectInput("task_frequency", "Frequency:",
            choices = c(
              "One-time" = "once",
              "Daily" = "daily",
              "Weekly" = "weekly",
              "Monthly" = "monthly",
              "Quarterly" = "quarterly",
              "Yearly" = "yearly"
            ),
            selected = "once"),
          checkboxInput("task_base_on_completion",
                       "Calculate next due date from completion date (not original due date)",
                       value = TRUE),
          dateInput("task_due_date", "Due Date:", value = Sys.Date()),
          textAreaInput("task_description", "Description:", 
                       placeholder = "Optional task description", 
                       rows = 3),
          br(),
          actionButton("add_task_btn", "Add Task", class = "btn-primary"),
          actionButton("update_task_btn", "Update Task", class = "btn-warning", style = "display: none;"),
          actionButton("cancel_edit_btn", "Cancel Edit", class = "btn-secondary", style = "display: none;")
        )
      ),
      
      # Task list table
      card(
        card_header("All Tasks"),
        card_body(
          DT::dataTableOutput("chores_table")
        )
      )
    )
  ) 
)