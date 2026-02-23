FROM rocker/shiny:latest

# System dependencies
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libgit2-dev \
    libglpk-dev \
    libgsl-dev \
    libfontconfig1-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CRAN packages
RUN R -e "install.packages(c('shiny', 'shinydashboard', 'DT', 'rhandsontable', 'shinyjs', 'shinycssloaders', 'openxlsx'), repos='https://cloud.r-project.org/')"

# Install Bioconductor packages
RUN R -e "if (!requireNamespace('BiocManager', quietly=TRUE)) install.packages('BiocManager'); \
          BiocManager::install(c('flowCore', 'CytoNorm'))"

# Copy entire app folder
COPY . /srv/shiny-server/

# Permissions
RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]