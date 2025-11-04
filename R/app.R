

# Create the Shiny app
app <- shinyApp(ui = ui, server = server)

# Run the Shiny app with specific host and port

runApp(app, host = "0.0.0.0", port = 8787)
