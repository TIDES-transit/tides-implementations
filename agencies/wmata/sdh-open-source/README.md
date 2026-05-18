# SMART Data Hub — Open-Source Reference

> **Note:** This is a modified, redacted version of a production repository. It is published as a **reference implementation** for agencies and developers interested in building transit data infrastructure using open standards. Vendor names and other sensitive details have been replaced with generic placeholders.

ELT pipeline for transforming source data into [TIDES (Transit Integrated Data Exchange Specification)](https://tides-transit.org) and analytical tables.

## About

The SMART Data Hub is a transit data lakehouse that ingests data from AVL, fare collection, and GTFS sources, transforms it into TIDES-compliant tables, and serves it for analytics and reporting. This repository contains the full stack: ingestion pipelines, dbt transformations, infrastructure-as-code, and metadata integration.

It is published to demonstrate how these open-source tools can be composed into a working transit data platform.

## Contact

Chum Chancharadeth, <CChancharadeth@wmata.com>.

## Repository Structure

```text
smart-data-hub/
├── docs/                # Documentation and architecture diagrams
├── warehouse/           # dbt project (models, tests, macros, seeds)
├── pipelines/           # Dagster pipelines for ingestion and orchestration
├── tf/                  # Terraform/OpenTofu infrastructure-as-code
├── scripts/             # Convenience scripts for setup or deployment
└── [root level]         # Development tools and configuration
```

## Technology Stack

- **Python 3.12**
- [dbt](https://docs.getdbt.com/) with [DuckDB](https://duckdb.org/) (local dev) and [Trino](https://trino.io/) (production)
- [Dagster](https://docs.dagster.io) for pipeline orchestration
- [Apache Iceberg](https://iceberg.apache.org/) open table format
- [Lakekeeper](https://lakekeeper.io/) for Iceberg catalog management
- [OpenMetadata](https://open-metadata.org/) for data catalog and governance
- [OpenTofu](https://opentofu.org/) for infrastructure management
- Azure services (Blob Storage, Container Apps, PostgreSQL)
- [uv](https://docs.astral.sh/uv) for dependency management

## Getting Started

### Prerequisites

- Python 3.12+
- [uv](https://docs.astral.sh/uv) package manager
- [DuckDB](https://duckdb.org/) (for local warehouse development)

### Local Development

1. Clone the repository
2. Install dependencies: `uv sync`
3. See [CONTRIBUTING](docs/CONTRIBUTING.md) for environment setup
4. See [warehouse/README](warehouse/README.md) for dbt development with DuckDB

## Key Documentation

- [CONTRIBUTING](docs/CONTRIBUTING.md) — Environment setup and development workflow
- [warehouse/README](warehouse/README.md) — Data warehouse and dbt development guide
- [Sample Data Workflow](docs/warehouse/sample_data_workflow.md) — Working with sample data locally
- [Warehouse Testing](docs/warehouse/dbt_tests_quality.md) — dbt testing guidance and best practices
- [Dagster Deployment](docs/dagster/deployment.md) — Deploying and using Dagster
- [Pipelines Development](docs/pipelines/README.md) — Setting up a development environment for Dagster pipelines

## Architecture

The SMART Data Hub implements a modern data lakehouse architecture that integrates multiple open-source tools to create a unified analytics platform.

<img src="docs/diagrams/architecture.drawio.svg" alt="Diagram for SMART Data Hub data and metadata flow">

### Architecture Components

#### Data Ingestion & Storage

- **Source Data**: GTFS, AVL, and fare collection systems provide raw data
- **Azure Data Storage**: Cloud object storage serves as the data lake foundation
- **Apache Iceberg**: Open table format enabling ACID transactions, time travel, and schema evolution
- **Lakekeeper**: Manages Iceberg table metadata and catalog operations

#### Data Processing & Transformation

- **Trino**: Distributed SQL query engine providing unified access to data lake files and external sources
- **dbt**: Transforms raw data into analytics-ready models using SQL, version-controlled as code
- **Dagster**: Orchestrates data pipelines, manages dependencies, and schedules workflows

#### Governance & Discovery

- **OpenMetadata**: Centralized metadata catalog providing data discovery, lineage tracking, and governance
- Ingests metadata from dbt, Trino, and Dagster to create a unified view of the data catalog

#### Analytics & Data Consumption

- **BI Tools**: Business intelligence platforms connect via Trino for reporting and analytics
- **Data Science**: Analysts and data scientists query data through Trino or directly from the data lake

This architecture separates storage from compute, enables collaboration through version control, and maintains data quality through testing and governance.

#### AI use disclaimer

AI code assistants, primarily Cline and Claude Code, were used to develop, refine, and document the code in this repository.

### License

See [LICENSE.md](LICENSE.md), this repository uses Apache 2.0.
