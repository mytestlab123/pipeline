# Nextflow Offline Execution Demo - Documentation

## Overview
This documentation provides guidance for running Nextflow pipelines (specifically nf-core pipelines) in offline environments on AWS EC2 instances.

## Architecture

### Two-Phase Workflow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Online Phase  │    │  Asset Storage  │    │  Offline Phase  │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Download     │ │───▶│ │Docker Hub   │ │───▶│ │Load Assets  │ │
│ │Pipeline     │ │    │ │or S3 Bucket │ │    │ │& Run        │ │
│ │Assets       │ │    │ │             │ │    │ │Pipeline     │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Generate     │ │    │ │Pipeline     │ │    │ │Execute      │ │
│ │Image List   │ │    │ │Code (GitLab)│ │    │ │with -offline│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ │flag         │ │
│                 │    │                 │    │ └─────────────┘ │
│ ┌─────────────┐ │    │                 │    │                 │
│ │Pull & Save  │ │    │                 │    │                 │
│ │Docker Images│ │    │                 │    │                 │
│ └─────────────┘ │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
     Internet              Shared Storage         Private Subnet
    Connection                                   (No Internet)
```

### Component Overview

#### Online Machine (Internet Access)
- **Pipeline Download**: Retrieves nf-core/demo pipeline from GitLab
- **Image Discovery**: Scans pipeline for required Docker images
- **Asset Preparation**: Downloads and packages all dependencies
- **Image Management**: Pulls Docker images and saves to shared location

#### Offline Machine (Private Subnet)
- **Asset Loading**: Retrieves pre-downloaded assets from shared storage
- **Image Loading**: Loads Docker images from shared location
- **Pipeline Execution**: Runs pipeline with `-offline` flag
- **Result Processing**: Handles pipeline outputs and logs

## Key Technologies

### Core Components
- **Shell Scripts**: Primary automation and orchestration
- **Docker/Podman**: Container runtime for pipeline execution
- **Nextflow**: Workflow management system
- **nf-core**: Pipeline framework and tooling

### AWS Services
- **EC2**: Compute instances for online and offline phases
- **S3**: Shared storage for assets and Docker images
- **VPC**: Network isolation for offline environment

## Quick Start

### Prerequisites
- AWS EC2 instances (online and offline)
- Docker or Podman installed
- Nextflow installation
- S3 bucket for asset storage

### Basic Usage
1. **Online Phase**: Run preparation scripts on internet-connected machine
2. **Transfer**: Move assets to shared storage (S3 or Docker Hub)
3. **Offline Phase**: Execute pipeline on isolated machine

See `../test/` directory for detailed testing scripts and examples.