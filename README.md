CytoNorm2 Shiny App

This Shiny application provides a user-friendly interface for normalizing cytometry data using CytoNorm2. It allows users to upload multiple batches of FCS files, select reference files per batch, apply compensation and arcsinh transformations, test FlowSOM clustering, and normalize all batches using the CytoNorm2 workflow.

Key features include:

Batch-wise file upload with easy selection of reference samples

Arcsinh transformation with global or per-marker cofactors

FlowSOM clustering to determine optimal number of clusters

Training and running CytoNorm2 models for batch normalization

Export of normalized FCS files (optionally decompensated and detransformed)

Note: This app is a Shiny implementation interface for the CytoNorm2 algorithm described in:
PMID: 39871681 – Van Gassen et al., CytoNorm2: A method for batch normalization of cytometry data, 2023.
The underlying normalization method comes from this publication and is not original work of this repository’s author.
