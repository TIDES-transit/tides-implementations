# TIDES Case Study - WMATA SMART Data Hub
## Prototyping Data Infrastructure With TIDES
### A reference architecture for modular, vendor-agnostic transit data pipelines

The Transit Integrated Data Exchange Specification (TIDES) enables analytics, reporting, and data integration by providing a common data schema that bridges between disparate operational data source systems and provides a stable foundation for downstream data users. To accomplish this, TIDES can be implemented or adopted at several stages of the data lifecycle: in the endpoint exposed by an operational vendor; in the data products returned by a third-party data processing vendor; or by an agency itself within its databases, data warehouse, or data lake.

For WMATA’s pioneering TIDES implementation, we took the third approach. In addition to transforming data into the TIDES format, we prototyped a data lake architecture that can serve as a reference for other agencies seeking to leverage TIDES in the context of an analytics infrastructure modernization effort.

## SMART Data Hub Context

WMATA’s TIDES implementation was funded by a [USDOT Strengthening Mobility and Revolutionizing Transportation (SMART) Grant](https://www.transportation.gov/grants/SMART). The SMART Grant program funds projects to improve transportation safety and efficiency through innovative applications of technology.

In alignment with those goals, the SMART Data Hub project prototyped a new data platform at WMATA to transform several data sources into the TIDES format and calculate ridership metrics from the TIDES-formatted data. By focusing on open-source, modular components and leveraging the TIDES and GTFS data standards, SMART Data Hub provides a replicable template for vendor-agnostic data infrastructure that can improve the efficiency of data reporting and analysis at transit agencies of all sizes.

## Design Principles

The SMART Data Hub architecture is based on a set of design principles:

* **Use version-controlled code to manage data infrastructure and data transformations.** Version-controlled code gives a clear, explicit audit trail for changes and ensures visibility, reducing risk that information gets lost if staff change. Version-controlled code enables a strong environment strategy by making it simple to deploy identical infrastructure in multiple locations. Work done in code can be tested and automatically deployed through robust continuous integration/continuous deployment (CI/CD) processes. 

* **Limit vendor lock-in.** In the spirit of open data standards, data pipelines and infrastructure should use interoperable tools and common languages. Maximize optionality to enable innovation and exploration without compromising compatibility with evolving enterprise infrastructure. 

* **Capture and expose lineage, metadata, and documentation.** One key aspect of interoperability is the exchange of structured metadata, which allows useful information to flow between tools and be surfaced to users. Automating the ingestion and exposure of key metadata allows back-end technical tools to support data governance goals. 

## Prototype Architecture

![Diagram showing SMART Data Hub architecture, a cloud-based data platform hosted in Azure using Dagster, dbt, Iceberg, and Trino](https://github.com/TIDES-transit/tides-implementations/blob/main/agencies/wmata/sdh-writeup/assets/sdh-architecture.png?raw=true)

*Figure 1\. High-level architecture of the SMART Data Hub prototype.*

The SMART Data Hub prototype delivered at WMATA uses the following tools. Note that for each layer there are alternatives available that could achieve similar goals (for example, this architecture could be hosted in Amazon Web Services or Oracle Cloud Infrastructure instead of Microsoft Azure):

| Layer | Component Type | SDH Implementation | Workflow / Use Case |
| :---- | :---- | :---- | :---- |
| **Data** | Data in various states of transformation (not an application) | **TIDES-based transformed data stored in Iceberg** | Connect to reports / use for analyses |
| **ETL /** **Metadata** | Orchestrator | **Dagster** | Building, deploying, maintaining, monitoring data ingest pipelines |
|  | Transformation framework | **dbt** | Writing and testing data transformations; managing data dependencies |
|  | Data catalog | **OpenMetadata** | Hosting data documentation, automated metadata ingest (surfacing quality information), governance |
| **Storage /** **Warehouse** | Data lake table format | **Iceberg \+ Lakekeeper** | Storing data in a structured format that allows database operations (e.g. lifecycle management) |
|  | SQL query engine | **Trino** | Querying data in storage using SQL |
| **Infra /** **Hosting** | Blob storage | **Azure Blob Storage** | Basic storage for execution |
|  | Compute | **Azure Container Apps** | Hosting applications |
|  | Secret management | **Azure Key Vault** | Storing secrets |

At a high level, the pipeline and infrastructure work as follows:

**Dagster** (hosted in Azure Container Apps) executes ingest pipelines, either on a schedule (e.g. daily, hourly) or according to a sensor or trigger (e.g. new data detected in an upstream bucket). These pipelines pull data from an upstream source location and save it in Iceberg-formatted files in Azure Blob Storage. The Dagster pipeline code is written in version-controlled Python.

![A screenshot of a Dagster user interface showing a lineage between different tasks](https://github.com/TIDES-transit/tides-implementations/blob/main/agencies/wmata/sdh-writeup/assets/dagster-lineage.png?raw=true)

*Figure 2\. Dagster ingest pipeline flow.*

After data has arrived in the platform, Dagster executes **dbt**. This step runs version-controlled SQL code to clean data, transform data into useful formats, and calculate aggregations and metrics according to business logic requirements. This includes transforming the raw data into the relevant TIDES format and calculating ridership metrics based on the TIDES-formatted data. These transformations are executed by Trino, the SQL query engine, which interfaces with the Iceberg-formatted data in Blob Storage.

![A screenshot of a file in GitHub with "blame" view showing a history of different user edits](https://github.com/TIDES-transit/tides-implementations/blob/main/agencies/wmata/sdh-writeup/assets/example-git-history.png?raw=true)

*Figure 3\. TIDES dbt model with commit history on GitHub.*

As Dagster and dbt run, metadata is pushed to **OpenMetadata**, the data catalog. This allows end users to see documentation about the data itself (table and column descriptions) alongside information from the pipeline runs, like current test results.

![A screenshot of an OpenMetadata user interface showing table and column descriptions](https://github.com/TIDES-transit/tides-implementations/blob/main/agencies/wmata/sdh-writeup/assets/omd-table-desc-tides-table.png?raw=true)

*Figure 4\. OpenMetadata data catalog showing table and column documentation*

![A screenshot of an OpenMetadata user interface showing some passing test results](https://github.com/TIDES-transit/tides-implementations/blob/main/agencies/wmata/sdh-writeup/assets/omd-test-results-tides-table.png?raw=true)

*Figure 5\. OpenMetadata data catalog showing pipeline metadata.*

## TIDES Models in dbt

Within the dbt project, we are transforming raw data from source systems into TIDES and then using that TIDES-formatted data to calculate ridership metrics.

![A diagram showing a data flow from left to right with data going through bronze, silver, and gold medallion layers with iterative quality refinements to produce a TIDES data table](https://github.com/TIDES-transit/tides-implementations/blob/main/agencies/wmata/sdh-writeup/assets/tides-flow.png?raw=true)

*Figure 5\. dbt model lineage showing medallion architecture.*

This is done in a medallion architecture, with iterative transformations that track the status of each input row so that analysts can also inspect data quality outcomes. For example, if a row is dropped from the final cleaned table because it lacks required attributes, that drop decision is tracked in a quality model so that dropped rows can be investigated to identify root causes for missing data.

## Summary

The SMART Data Hub prototype offers a reference implementation for a modular data lake architecture hosting data pipelines that transform data from multiple sources into TIDES formats and calculate metrics from the TIDES-formatted data. The underlying design goals could be achieved with a different technology stack, but we strongly recommend leveraging version-controlled code for infrastructure and data transformations; limiting vendor lock-in with thoughtful component selection; and extracting value from metadata exchanged between components to facilitate data governance.

## Learn More

TIDES is a community-governed open standard for transit operational data. To learn more about the specification, explore implementation resources, or get involved:

* TIDES specification and documentation: [tides-transit.org](https://tides-transit.org)

* TIDES on GitHub: [github.com/TIDES-transit](https://github.com/TIDES-transit)

* The WMATA SMART Data Hub project was funded by the [USDOT SMART Grant program](https://www.transportation.gov/grants/SMART) and its open-source code is available in the [github.com/TIDES-transit/tides-implementations repository](https://github.com/TIDES-transit/tides-implementations/tree/main/agencies/wmata/sdh-open-source)

## About the Author

Laurie Merrell is the Transit Data Practice Lead at Jarvus Innovations and served as the technical lead for the WMATA SMART Data Hub implementation – the first TIDES implementation at a major transit agency.