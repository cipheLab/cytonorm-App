# CytoNorm2 Shiny App

This Shiny application provides a user-friendly interface for **normalizing cytometry data using CytoNorm2**.  
It allows users to upload multiple batches of FCS files, select reference files per batch, apply compensation and arcsinh transformations, test FlowSOM clustering, and normalize all batches using the CytoNorm2 workflow.

## Key Features

- Batch-wise file upload with easy selection of reference samples  
- Arcsinh transformation with global or per-marker cofactors  
- FlowSOM clustering to determine optimal number of clusters  
- Training and running CytoNorm2 models for batch normalization  
- Export of normalized FCS files (optionally decompensated and detransformed)  

## Installation (Docker Recommended)

### 1. Install Docker

Install Docker on your system:

https://docs.docker.com/get-docker/

### 2. Clone the repository

```bash
git clone https://github.com/your-username/your-repository.git
cd your-repository
```

### 3. Build the Docker image

```bash
docker build -t cytonorm2-shiny .
```
### 4. Run the container 

```bash
docker run -p 3838:3838 \
  -v /path/to/your/fcs_folder:/data \
  cytonorm2-shiny
```
### 5. Open the application
Open your browser and go to:

http://localhost:3838

## Installation (Run without Docker )
If you prefer to run the app locally in R, install the required packages:

```r
install.packages(c(
  "shiny", "shinydashboard", "shinycssloaders", "DT", "openxlsx", "rhandsontable", "shinyjs"
))

if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install(c(
  "flowCore", "CytoNorm", "FlowCIPHE"
))
```
Then launch:

```r
shiny::runApp("path_to_app")
```
## Usage

1. Upload your FCS files batch by batch.
2. **Select reference files for each batch** (required for proper normalization).
3. Apply compensation and arcsinh transformations if needed.
4. Test FlowSOM clustering to optimize cluster numbers.
5. Train the CytoNorm2 model and normalize all batches.
6. Download normalized FCS files.

## Note

This Shiny app is an interface for the **CytoNorm2 algorithm** described in:

**PMID: 39871681 – Van Gassen et al., CytoNorm2: A method for batch normalization of cytometry data, 2023.**

The normalization method comes from this publication and is **not original work of the repository author**.


