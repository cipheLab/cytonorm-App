library(shinydashboard)
library(rhandsontable)
library(shinyjs)
library(shiny)
library(CytoNorm)
library(flowCore)
library(DT)
library(shinycssloaders)


ui <- dashboardPage(
  skin = "blue",
  
  dashboardHeader(title = "CytoNorm "),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Data", tabName = "data", icon = icon("folder-open")),
      menuItem("Run cytoNorm", tabName = "run", icon = icon("play"))

    )
  ),
  
  dashboardBody(
    tabItems(
      
      # ================= DATA TAB =================
      
      tabItem(tabName = "data",
              fluidPage(
              box(width = 10,
                  tags$h3(
                    "Upload data",
                    style = "font-weight: bold; background-color: #fff9c4; padding: 4px; display: inline-block;"
                  ),
                  numericInput("n_batches",
                               "Number of batches",
                               value = 2,
                               min = 1),
                  uiOutput("batch_upload_ui"),
              ),
 
              box(width = 10,

                  DTOutput("design_table",width = "50%", height = "auto"),
                  br(),
                  uiOutput("marker_ui"),
              ),
              
          
              box(
                width = 10,
      
                
                fluidRow(
                  # ================= Colonne gauche =================
                  column(width = 10,
                         # S??lection des marqueurs
                      
                         tags$h3(
                           "Compensation and transformation",
                           style = "font-weight: bold; background-color: #fff9c4; padding: 4px; display: inline-block;"
                         ),
                         br(),
                         
                         # Checkbox pour compensation
                         checkboxInput(
                           "apply_comp",
                           "Apply compensation if available",
                           value = TRUE
                         )
                  )
                ),
                fluidRow(
                  # ================= Colonne droite =================
                  column(width = 6,
                         # Mode cofactor
                         radioButtons(
                           "transform_mode",
                           "Cofactor mode",
                           choices = c(
                             "Same value for all markers" = "global",
                             "One value per marker" = "individual"
                           ),
                           selected = "global"
                         ),
                         
                         # Si global, saisir valeur unique
                         conditionalPanel(
                           condition = "input.transform_mode == 'global'",
                           numericInput("global_cofactor",
                                        "Cofactor value",
                                        value = 500,
                                        min = 0.1)
                         ),
                         
                         # Si individuel, interface dynamique
                         # Dans la box "Arcsinh transformation", ?? la place de uiOutput("individual_cofactor_ui")
                         conditionalPanel(
                           condition = "input.transform_mode == 'individual'",
                           fileInput("uploadTransformation", "(Option) Upload EXCEL transformation file", accept = ".xlsx", width = "100%"),
                           
                           downloadButton("exportTransformation", "Export transfo table"),
                           tags$br(),
                           rHandsontableOutput('table_group_transfo', width="500px")
                         )
                  ) ,
                  column(6,
                  # Bouton Apply transformation
                  actionButton(
                    "apply_transform",
                    "Apply transformation",
                    class = "btn-primary",
                  ))
                )
              ))
      ),

      # ================= RUN TAB =================
      
      tabItem(tabName = "run",
              fluidPage(
              box(width = 6,
                  tags$h3(
                    "Clustering settings",
                    style = "font-weight: bold; background-color: #fff9c4; padding: 4px; display: inline-block;"
                  ),
                  uiOutput("marker_clust_ui"),
         
                  br(),
                  h4("FlowSOM cluster selection"),
                  
                  fluidRow(
                    column(4,
                           numericInput("cluster_min",
                                        "Min clusters",
                                        value = 5,
                                        min = 2)
                    ),
                    column(4,
                           numericInput("cluster_max",
                                        "Max clusters",
                                        value = 20,
                                        min = 5)
                    ),
                    column(4,
                           numericInput("cluster_step",
                                        "Step",
                                        value = 5,
                                        min = 1)
                    )
                  ),
                  
                  br(),
                  
                  actionButton("test_clusters",
                               "Test cluster numbers",
                               class = "btn-primary"),
                  
                  br(), br(),
                  
                  plotOutput("cluster_test_plot", height = "300px"),
                  
                  hr(),
                  
                  tags$h3(
                    "Run Cytonorm",
                    style = "font-weight: bold; background-color: #fff9c4; padding: 4px; display: inline-block;"
                  ),
                  
                  numericInput("nClusters",
                               "Number of clusters (final run)",
                               value = 10,
                               min = 2),
                  
                  actionButton("run_cytonorm",
                               "Run CytoNorm",
                               class = "btn-primary"),
                  
                  br(), br(),
                  tags$h3(
                    "Export normalized files",
                    style = "font-weight: bold; background-color: #fff9c4; padding: 4px; display: inline-block;"
                  ),
                  selectInput(
                    "download_mode",
                    "Download mode:",
                    choices = c(
                      "Compensated & transformed" = "norm",
                      "Decompensated & detransformed" = "inverse"
                    ),
                    selected = "inverse"
                  ),
                  
                  downloadButton("download_norm", "Download normalized files")
              ),
              box(width= 6,
                  
                  uiOutput("norm_visualization_ui")
                  
                  
                  ),
              box(width = 6,
                  tags$h3(
                    "LOGs",
                    style = "font-weight: bold; background-color: #fff9c4; padding: 4px; display: inline-block;"
                  ),
                  verbatimTextOutput("validation_status")
              )
      )
      )
    )
  )
)