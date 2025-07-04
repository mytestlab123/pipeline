# Nextflow Offline Execution Demo – Plan

## Project Type

MVP (small working demo)

## Project Name

Nextflow Offline Execution Demo

## Code Repository

[https://github.com/mytestlab123/pipeline.git](https://github.com/mytestlab123/pipeline.git)

## Issue Tracking

`issues.md`

## Development Environment

AWS Cloud9 (Amazon Linux 2)

## Technology Stack

* Shell Script
* GitHub
* Docker Hub
* Linux

## Constraints

* Linux/Shell Script
* podman
* Use only open‑source tools
* Docker Hub (for hosting)

## Milestones

* Demo in 2 hours

## Objective

This project provides scripts to demonstrate running Nextflow pipelines (specifically nf‑core pipelines using Docker) in an environment without internet access on AWS EC2.

Required components:

* Nextflow pipeline code hosted on GitLab
* Nextflow Docker images hosted on Docker Hub (accessed via Nexus repository proxy)
* Other required files stored in an S3 bucket

## Goal

Enable running Nextflow pipelines on an **offline** machine (e.g., an EC2 instance in a private subnet with no internet gateway) by:

1. Using an **online** machine to download the pipeline assets and generate a list of required Docker images.
2. Using the **online** machine again with the generated list to pull the Docker images and either:

   * save them to a shared S3 location, **or**
   * push/copy them to [https://hub.docker.com/u/mytestlab123](https://hub.docker.com/u/mytestlab123).
3. Using the **offline** machine to load the assets and Docker images from Docker Hub and run the pipeline with the `-offline` flag.

## Developer Opinion

Using shell scripts and [https://nf-co.re/demo/](https://nf-co.re/demo/) this can be completed in 30 mins

## External Links (Knowledge / Documentation)

* [https://nf-co.re/demo/1.0.2/](https://nf-co.re/demo/1.0.2/)
* [https://github.com/nf-core/demo/tree/1.0.2](https://github.com/nf-core/demo/tree/1.0.2)
* [https://nf-co.re/docs/usage/getting\_started/offline](https://nf-co.re/docs/usage/getting_started/offline)

