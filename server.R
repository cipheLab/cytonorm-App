library(shiny)
library(CytoNorm)
library(flowCore)
library(DT)
library(shinycssloaders)
library(openxlsx)
library(shinydashboard)


options(expressions = 5e5, shiny.maxRequestSize = 100 * 1024^3)

server <- function(input, output, session) {
  
  arcsinhCIPHE <- function(flow.frame, marker, args) {
    raw <- exprs(flow.frame)
    for (i in seq_along(marker)) {
      raw[, marker[i]] <- asinh(raw[, marker[i]] / args[i])
    }
    exprs(flow.frame) <- raw
    return(flow.frame)
  }
  inverseArcsinhCIPHE <- function(flow.frame, marker = NULL, args) {
    raw <- flow.frame@exprs
    if (is.null(marker) || length(marker) < 1) {
      marker <- colnames(flow.frame)
    }
    for (i in seq_along(marker)) {
      mat <- raw[, marker[i]]
      mat <- sinh(mat) * args[i]
      raw[, marker[i]] <- mat
    }
    flow.frame@exprs <- raw
    return(flow.frame)
  }
  
  rv <- reactiveValues(
    fs_list = list(),
    design = data.frame(),
    log = "",
    transfoTable=NULL
  )
  output$batch_upload_ui <- renderUI({
    req(input$n_batches)
    
    tagList(
  
      
      # Upload batch par batch
      lapply(1:input$n_batches, function(i) {
        box(
          title = paste("Batch", i),
          width = 12,
          fileInput(
            paste0("batch_", i),
            paste("Upload files for batch", i),
            multiple = TRUE,
            accept = ".fcs"
          ),
          uiOutput(paste0("ref_ui_", i))
        )
      }),
      

      box(
        title = "What is a Goal Reference?",
        width = 6,
        status = "primary",
        solidHeader = TRUE,
        collapsed = TRUE,
        p("The goal reference batch is the batch whose distribution will be used as the target for normalization."),
        p("All other batches will be normalized towards this batch."),
        p("If none is selected, normalization will not use a fixed target batch.")
      ),
      
      # S??lecteur du goal reference (avec possibilit?? NONE)
      radioButtons(
        inputId = "goal_ref_batch",
        label   = "Choose batch as goal reference:",
        choices = c("None", paste("Batch", 1:input$n_batches)),
        selected = if (input$n_batches >= 1) "Batch 1" else "None",
        inline = TRUE
      )
    )
  })
  goal_batch <- reactive({
    
    if (input$goal_ref_batch == "None") {
      return(NULL)
    }
    
    as.numeric(gsub("Batch ", "", input$goal_ref_batch))
  })
  # ObserveEvent pour chaque batch
  observe({
    req(input$n_batches)
    for (i in 1:input$n_batches) {
      local({
        batch_i <- i
        observeEvent(input[[paste0("batch_", batch_i)]], {
          files_input <- input[[paste0("batch_", batch_i)]]
          req(files_input)
          
          fs_list <- lapply(seq_len(nrow(files_input)), function(j) {
            read.FCS(files_input$datapath[j],
                     transformation = FALSE,
                     truncate_max_range = FALSE)
          })
          rv$fs_list[[batch_i]] <- fs_list
          
          # Mettre ?? jour le design
          rv$design <- rv$design[rv$design$Batch != batch_i, ]
          new_rows <- data.frame(
            Batch = batch_i,
            File = files_input$name,
            Type = "Sample",
            stringsAsFactors = FALSE
          )
          rv$design <- rbind(rv$design, new_rows)
          rownames( rv$design)<-NULL
          markers<-colnames(exprs(rv$fs_list[[1]][[1]]))
          names(markers)<-NULL
          rv$transfoTable <- data.frame(
            Fluo =  markers,
            Arg = rep("none", length(markers))
          )
          # UI Reference pour ce batch
          output[[paste0("ref_ui_", batch_i)]] <- renderUI({
            selectInput(paste0("ref_files_", batch_i),
                        "Select reference file(s)",
                        choices = files_input$name,
                        multiple = TRUE)
            
     
          })
        }, ignoreNULL = TRUE)
      })
    }
  })
  

  # Mise ?? jour Type (Reference/Sample)
  observe({
    req(input$n_batches)
    for (i in 1:input$n_batches) {
      local({
        batch_i <- i
        ref_input_id <- paste0("ref_files_", batch_i)
        selected_ref <- input[[ref_input_id]]
        if (!is.null(selected_ref)) {
          idx <- rv$design$Batch == batch_i
          rv$design$Type[idx] <- ifelse(rv$design$File[idx] %in% selected_ref,
                                        "Reference", "Sample")
        }
      })
    }
  })
  output$exportTransformation <- downloadHandler(
    
    filename = function() {
      paste("transf_table.xlsx", sep="")
    },
    content = function(file) {
      write.xlsx(rv$transfoTable, file)
    }
  )
  
  observeEvent(input$table_group_transfo, {
    
    req(input$table_group_transfo)
    updated_table <- hot_to_r(input$table_group_transfo)
    rv$transfoTable<-updated_table
  })
  
  
  # Table design
  output$design_table <- renderDT({
    req(nrow(rv$design) > 0)
    datatable(rv$design, editable = TRUE)
  })
  
  observe({
    if (length(rv$fs_list) >= 1 && length(rv$fs_list[[1]]) >= 1) {
      
      ff <- rv$fs_list[[1]][[1]]
      param_data <- ff@parameters@data
      
      marker_names <- param_data$name
      marker_desc  <- param_data$desc
      
      # Affichage : desc (name)
      marker_labels <- ifelse(
        is.na(marker_desc) | marker_desc == "",
        marker_names,
        paste0(marker_desc, " (", marker_names, ")")
      )
      
      # Filtrer FSC / SSC / Time sur les NAMES
      keep <- !grepl("^(time|fsc|ssc)", marker_names, ignore.case = TRUE)
      
      marker_names  <- marker_names[keep]
      marker_labels <- marker_labels[keep]
      
      # Garder s??lection existante si d??j?? d??finie
      selected_markers <- isolate(input$markers)
      
      if (is.null(selected_markers)) {
        selected_markers <- marker_names
      }
      
      output$marker_ui <- renderUI({
        selectInput(
          "markers",
          "Markers for analysis",
          choices = setNames(marker_names, marker_labels),
          selected = selected_markers,
          multiple = TRUE
        )
      })
    }
  })
 
  observeEvent(input$uploadTransformation,{
    tryCatch({
      
      rv$transfoTable<-read.xlsx(input$uploadTransformation$datapath)
      
      
    }, error = function(e) {
      
      showModal(modalDialog(
        title = "Error",
        paste("An error occurred:", e$message),
        easyClose = TRUE
      ))
    })
    
    
  })
  output$table_group_transfo <- renderRHandsontable({
    req(length(rv$fs_list) > 0)
    req(rv$transfoTable)
    
    ff <- rv$fs_list[[1]][[1]]
    param_data <- ff@parameters@data
    
    marker_names <- param_data$name
    marker_desc  <- param_data$desc
    
    # Desc seule (si NA ??? name)
    marker_only <- ifelse(
      is.na(marker_desc) | marker_desc == "",
      marker_names,
      marker_desc
    )
    
    # Mapping name -> desc
    desc_map <- setNames(marker_only, marker_names)
    
    df <- as.data.frame(rv$transfoTable)
    
    # Ajouter colonne Marker (desc)
    df$Marker <- desc_map[df$Fluo]
    
    # R??organiser colonnes
    df <- df[, c("Marker", "Fluo", "Arg")]
    
    rhandsontable::rhandsontable(
      df,
      width = 600,
      rowHeaders = NULL,
      useTypes = TRUE,
      stretchH = "none"
    ) %>%
      rhandsontable::hot_col("Marker",
                             width = 200,
                             readOnly = TRUE) %>%
      rhandsontable::hot_col("Fluo",
                             width = 200,
                             readOnly = TRUE) %>%
      rhandsontable::hot_col("Arg",
                             width = 150,
                             readOnly = FALSE)
  })
  cofactor_values <- reactiveVal(NULL)

  observeEvent(input$apply_transform, {
    tryCatch({
    showModal(modalDialog(
      title = "Apply Transformation on all files...",
      tags$div(
        style = "text-align: center;",
        tags$p("Please wait."),
      ),
      footer = NULL,
      easyClose = FALSE
    ))
    req(input$markers)
    req(length(rv$fs_list) > 0)
    
    shinyjs::disable("apply_transform")
    
    if (input$transform_mode == "global") {
      args <- rep(input$global_cofactor, length(input$markers))
      markers<-input$markers
    } else {
     
      args <- c(rv$transfoTable[, 2])
      numeric_rows <- grepl("^[0-9]+(\\.[0-9]+)?$", args)
 
      filtered_table <- rv$transfoTable[
        suppressWarnings(!is.na(as.numeric(as.character(rv$transfoTable$Arg)))), 
        , 
        drop = FALSE
      ]
      markers <- filtered_table$Fluo
      args <- as.numeric(filtered_table[, 3])

     
    }
    
    total_batches <- length(rv$fs_list)

    rv$args <- args  
      
      for (i in seq_along(rv$fs_list)) {
        
        # D??tail du batch
        incProgress(0, detail = paste("Processing batch", i))
        
        rv$fs_list[[i]] <- lapply(rv$fs_list[[i]], function(ff) {
          req(inherits(ff, "flowFrame"))  # V??rifie que c'est bien un flowFrame
          
          if (input$apply_comp) {
            spill <- FlowCIPHE::found.spill.CIPHE(ff)
            if (!is.null(spill)) {
              spill<-spill[1]
              ff <- flowCore::compensate(ff, ff@description[[spill]])
            }
          }
          
          ff <- arcsinhCIPHE(ff, marker = markers, args = args)
          print("after transfo")
          print(ff@exprs)
          return(ff)  
        })
        
        
      }
      
  
 
    showNotification("Transformation completed", type = "message")
    shinyjs::enable("apply_transform")
    removeModal()
  }, error = function(e) {
    showModal(modalDialog(
      title = "Error",
      paste("An error occurred:", e$message),
      easyClose = TRUE
    ))
  })
  })
  
  # Validation
  validate_design <- reactive({
    
    req(input$n_batches)
    
    # Force d??pendance aux s??lections de r??f??rences
    for (i in 1:input$n_batches) {
      input[[paste0("ref_files_", i)]]
    }
    
    d <- rv$design
    
    if (nrow(d) == 0)
      return("No files uploaded")
    
    refs_per_batch <- tapply(d$Type == "Reference", d$Batch, sum)
    
    if (any(is.na(refs_per_batch)) || any(refs_per_batch == 0))
      return("Each batch must have at least 1 Reference")
    
    if (length(unique(d$Batch)) < 2)
      return("At least 2 batches required")
    
    if (is.null(input$markers) || length(input$markers) == 0)
      return("Select markers")
    
    return("Design valid")
  })
  
  observeEvent(input$test_clusters, {
    
    req(validate_design() == "Design valid")
    
    showModal(modalDialog(
      title = "Testing cluster numbers",
      "Preparing FlowSOM...",
      footer = NULL
    ))
    
    # -----------------------------
    # Pr??parer r??f??rences en FlowSet
    # -----------------------------
    ref_files <- list()
    ref_labels <- c()
    
    for (i in 1:input$n_batches) {
      d <- rv$design[rv$design$Batch == i, ]
      ref_idx <- which(d$Type == "Reference")
      if (length(ref_idx) > 0) {
        ref_files <- c(ref_files, rv$fs_list[[i]][ref_idx])
        ref_labels <- c(ref_labels, rep(i, length(ref_idx)))
      }
    }
    
    # Convertir en FlowSet
    ref_fs <- as(ref_files, "flowSet")
    print("before testCV")
    ff <- ref_fs[[1]]         # premier flowFrame
    expr_matrix <- exprs(ff)  # matrice des valeurs
   print(expr_matrix)
    # -----------------------------
    # Pr??parer FlowSOM sur les marqueurs de clustering seulement
    # -----------------------------
    fsom <- CytoNorm::prepareFlowSOM(
      ref_fs,
      input$markers_clust,   # <-- marqueurs utilis??s pour le clustering
      nCells = 6000,
      FlowSOM.params = list(
        xdim = 5,
        ydim = 5,
        scale = FALSE
      ),
      transformList = NULL,
      seed = 1
    )

    # -----------------------------
    # Tester plusieurs nombres de clusters
    # -----------------------------
    cluster_range <- seq(input$cluster_min,
                         input$cluster_max,
                         input$cluster_step)
    
    cvs <- CytoNorm::testCV(
      fsom,
      cluster_values = cluster_range
    )
    
    rv$cvs <- cvs
    
    removeModal()
  })
  
  output$marker_clust_ui <- renderUI({
    
    req(length(rv$fs_list) >= 1)
    req(length(rv$fs_list[[1]]) >= 1)
    
    ff <- rv$fs_list[[1]][[1]]
    param_data <- ff@parameters@data
    
    marker_names <- param_data$name
    marker_desc  <- param_data$desc
    
    # Si desc vide ou NA ??? fallback sur name
    marker_labels <- ifelse(
      is.na(marker_desc) | marker_desc == "",
      marker_names,
      paste0(marker_desc, " (", marker_names, ")")
    )
    
    # Filtrer FSC / SSC / Time sur les NAMES
    keep <- !grepl("^(time|fsc|ssc)", marker_names, ignore.case = TRUE)
    
    marker_names  <- marker_names[keep]
    marker_labels <- marker_labels[keep]
    
    # S??lection par d??faut = markers s??lectionn??s pour l???analyse
    selected_markers <- isolate(input$markers)
    
    if (is.null(selected_markers)) {
      selected_markers <- marker_names
    }
    
    selectInput(
      "markers_clust",
      "Markers for clustering",
      choices = setNames(marker_names, marker_labels),
      selected = selected_markers,
      multiple = TRUE
    )
  })

output$cluster_test_plot <- renderPlot({
  req(rv$cvs)

  # Extraire les clusters test??s
  cluster_vals <- as.numeric(names(rv$cvs$cvs))  # 5,10,15,...
  
  # Calculer le CV moyen pour chaque cluster
  mean_CV <- sapply(rv$cvs$cvs, mean)
  
  # V??rifier qu'il n'y a pas de NA / Inf
  valid_idx <- which(is.finite(mean_CV))
  cluster_vals <- cluster_vals[valid_idx]
  mean_CV <- mean_CV[valid_idx]
  
  req(length(cluster_vals) > 0)  # sinon on ne trace pas
  
  # Plot simple
  plot(cluster_vals,
       mean_CV,
       type = "b",
       pch = 19,
       col = "blue",
       xlab = "Number of clusters",
       ylab = "Mean CV",
       main = "FlowSOM cluster stability")
  
  # Marquer le meilleur cluster (CV minimum)
  best_idx <- which.min(mean_CV)
  points(cluster_vals[best_idx], mean_CV[best_idx], col = "red", pch = 19, cex = 1.5)
  text(cluster_vals[best_idx], mean_CV[best_idx],
       labels = paste0("Best: ", cluster_vals[best_idx]),
       pos = 3)
})
  
  output$validation_status <- renderText({
    validate_design()
  })
  observeEvent(input$run_cytonorm, {
    req(validate_design() == "Design valid")
    
    shinyjs::disable("run_cytonorm")
    
    total_batches <- input$n_batches
    
    # ----------------------------
    # Show modal: Training model
    # ----------------------------
    showModal(modalDialog(
      title = "CytoNorm in progress",
      "Training the global model on reference samples...",
      footer = NULL
    ))
    
    # ----------------------------
    # Prepare reference files and labels
    # ----------------------------
    ref_files <- list()
    ref_labels <- c()
    
    for (i in 1:total_batches) {
      d <- rv$design[rv$design$Batch == i, ]
      ref_idx <- which(d$Type == "Reference")
      if (length(ref_idx) > 0) {
        ref_files <- c(ref_files, rv$fs_list[[i]][ref_idx])
        ref_labels <- c(ref_labels, rep(i, length(ref_idx)))
      }
    }
    
    library(flowCore)
  print(input$goal_ref_batch)
    ref_fs <- as(ref_files, "flowSet")
    
    print(input$goal_ref_batch)
    
    if(input$goal_ref_batch != "None"){
      goal <- gsub("Batch ", "",input$goal_ref_batch)
      
   print(goal)
      
    model <- CytoNorm.train(
      files = ref_fs,
      labels = ref_labels,
      channels = input$markers,
      nClusters = input$nClusters,
      nQ = 99,
      transformList = NULL,
      FlowSOM.params = list(
        nCells = 50000,
        nClus = input$nClusters,
        colsToUse = input$markers_clust
      ),
      normParams = list(goal =  goal),
      seed=2026,
      verbose = TRUE,
      recompute = TRUE
    )

      }else{
  
        model <- CytoNorm.train(
          files = ref_fs,
          labels = ref_labels,
          channels = input$markers,
          nClusters = input$nClusters,
          nQ = 99,
          transformList = NULL,
          FlowSOM.params = list(
            nCells = 50000, # safer for Shiny
            nClus = input$nClusters,
            colsToUse = input$markers_clust
          ),
      
          verbose = TRUE,
          recompute = TRUE
        )
      
      }
    

    # ----------------------------
    # Train CytoNorm model
    # ----------------------------
   #    
   # print(ref_labels)
   #  model <- CytoNorm.train(
   #    files = ref_fs,
   #    labels = ref_labels,
   #    channels = input$markers,
   #    nClusters = input$nClusters,
   #    nQ = 99,
   #    transformList = NULL,
   #    FlowSOM.params = list(
   #      nCells = 50000, # safer for Shiny
   #      nClus = input$nClusters,
   #      colsToUse = input$markers_clust 
   #    ),
   #    normParams = list(goal = "1"),
   #    verbose = TRUE,
   #    recompute = TRUE
   #  )
   #  
    # ----------------------------
    # Show modal: Normalizing batches
    # ----------------------------
    removeModal() # close previous modal
    showModal(modalDialog(
      title = "CytoNorm in progress",
      "Normalizing all batches, please wait...",
      footer = NULL
    ))
    
    # ----------------------------
    # Normalize each batch
    # ----------------------------
    for (i in 1:total_batches) {
      fs_list <- as(rv$fs_list[[i]], "flowSet")
      labels_batch <- rep(i, length(fs_list))
      
      norm_list <- CytoNorm.normalize(
        model = model,
        files = fs_list,
        labels = labels_batch,
        transformList = NULL,
        transformList.reverse = NULL
      )
      
      # Replace batch with normalized files
      rv$fs_list[[i]] <- norm_list
    }
    
    removeModal() # close modal when done
  
    # ----------------------------
    # Notify user
    # ----------------------------
    showModal(modalDialog(
      title = "CytoNorm finished",
      "All batches have been successfully normalized.",
      easyClose = TRUE,
      footer = modalButton("Close")
    ))

    shinyjs::enable("run_cytonorm")
  })
  # Logs
  output$console <- renderText({
    rv$log
  })

  output$download_norm <- downloadHandler(
    filename = function() {
      paste0("Normalized_FlowFrames.zip")
    },
    content = function(file) {
      # ----------------------------
      # Show modal: Preparing download
      # ----------------------------
      showModal(modalDialog(
        title = "Preparing download",
        "Please wait while the normalized files are being processed...",
        footer = NULL
      ))
      
      # ----------------------------
      # Temporary folder
      # ----------------------------
      tmpdir <- tempdir()
      outdir <- file.path(tmpdir, "Normalized")
      if (dir.exists(outdir)) unlink(outdir, recursive = TRUE)
      dir.create(outdir, showWarnings = FALSE)
      if (input$transform_mode == "global") {
        args <- rep(input$global_cofactor, length(input$markers))
        markers<-input$markers
      } else {
        
        args <- c(rv$transfoTable[, 2])
        numeric_rows <- grepl("^[0-9]+(\\.[0-9]+)?$", args)
        
        filtered_table <- rv$transfoTable[
          suppressWarnings(!is.na(as.numeric(as.character(rv$transfoTable$Arg)))), 
          , 
          drop = FALSE
        ]
        markers <- filtered_table$Fluo
        args <- as.numeric(filtered_table[, 2])
        
        
        
      }
      # ----------------------------
      # Process each batch
      # ----------------------------
      for (i in seq_along(rv$fs_list)) {
        batch_fs <- rv$fs_list[[i]]
        batch_design <- rv$design[rv$design$Batch == i, ]
        
        for (j in seq_along(batch_fs)) {
          ff <- batch_fs[[j]]
          original_name <- batch_design$File[j]
          safe_name <- gsub("[^A-Za-z0-9_.-]", "_", original_name)
          
          # -------------------------------
          # Mode inverse
          # -------------------------------
          if (!is.null(input$download_mode) && input$download_mode == "inverse") {
      

            # 2. D??s-transformation arcsinh
            if (!is.null(args) && length(args) == length(markers)) {
              print("start inv arcsinh")
              print(markers)
              print(args)
              ff <- inverseArcsinhCIPHE(ff, marker = markers, args =args)
              print(ff@exprs)
            }

            # 1. D??s-compensation si disponible
            spill <- FlowCIPHE::found.spill.CIPHE(ff)

            if (!is.null(spill)) {
              spill<-spill[1]

              ff <- flowCore::decompensate(ff, ff@description[[spill]])
            }
          }
          
          # Nom du fichier
          fcs_name <- paste0("Norm_", safe_name)
          write.FCS(ff, filename = file.path(outdir, fcs_name))
        }
      }
    
      # ----------------------------
      # Create zip
      # ----------------------------
      old_wd <- setwd(outdir)
      on.exit(setwd(old_wd))
      zip(zipfile = file, files = list.files())
      
      # ----------------------------
      # Close modal
      # ----------------------------
      removeModal()
    }
  )
  
}