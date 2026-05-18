# Glossary

There are important core concepts to understand when managing data using iceberg tables. These core concepts generally are used across services, but some terms are mixed across services. This glossary spells out these concepts at a high level.

## Iceberg tables

Tables using the iceberg format, which supports snapshotting and schema evolution, among other functionality.

## Warehouse (Iceberg)

This is the compute layer and storage component. This is only specified within the context actual iceberg interface (such as pyiceberg) which connects to a warehouse which is on a host. One warehouse can host multiple catalogs.

Neither trino or dbt have a concept of a warehouse specifically, though they connect to it by referring to it as the catalog. They specify a catalog to connect to, which is iceberg’s warehouse.

- Meaning you have a warehouse called “datahub”, and trino connects to the “datahub” catalog.

### Warehouse Components

An Iceberg warehouse encompasses:

- **Storage Layer**: The actual data files (Parquet, ORC, Avro) stored in object storage or distributed filesystems
- **Metadata Store**: Table schemas, partition information, and snapshot metadata
- **Catalog Service**: The interface for managing namespaces, table data, and metadata operations

## Catalog

In the [Project Name], [Lakekeeper](lakekeeper.md) serves as the Iceberg REST catalog. It manages warehouse and namespace metadata, and coordinates access to Iceberg tables stored in ADLS Gen2.

### Iceberg - Catalog

Within iceberg, a catalog is the data and metadata management layer. A catalog can host multiple namespaces. A catalog doesn't necessarily even show up in the Lakekeeper UI as it's just a management layer for organizing data. ACID operations are coordinated through the catalog layer.

The catalog serves as a shared metadata layer that multiple compute engines can access simultaneously. This enables:

- Multi-engine access: Different query engines can all query the same Iceberg tables
- Consistent metadata: Schema evolution and table changes are visible across all engines
- Transactional consistency: ACID operations are coordinated through the catalog layer

### Trino - Catalog

Within trino, the catalog is a synonym for the warehouse you are connecting to and querying. For example, `SHOW CATALOGS` will return a list of the specific Iceberg warehouses (e.g., datahub, system, tcph) rather than a catalog created to store a namespace.

### dbt - Catalog

dbt connects via a sql engine, so the `catalog` is actually the iceberg warehouse, which is used as part of the trino connection profile.

## Namespace

Namespaces and schemas are essentially interchangeable within the different contexts. What varies is how the different services parse them.

### Iceberg - Namespaces

Iceberg can nest namespaces, such as `ns1.ns2.my_table`. You can load tables into ns1 or ns2 as needed.

### Trino - Namepsaces

The namespace is equivalent to a schema. Trino queries a schema from a catalog (the iceberg warehouse). Nested namespace support requires configuration within trino.

### dbt - Namespaces

The namespace is equivalent to a schema. dbt should support nested namespaces via the trino connector.

## Table Structure and Operations

Data is stored in a tabular format within all of the services. In this case, tables exist as several different file structures. Data is stored in several file structures within the source file system.

- Data - `table_name\data\data_files.files`
- Metadata - `table_name\metadata\metadata_files.files`

### Data (Iceberg)

Table data is stored in data files in the filesystem.

### Metadata (Iceberg)

Metadata about tables is stored in the file system. This identifies changes to the tables, data locations, and other features.

### Snapshots (Iceberg)

Changes to the table are managed via snapshots. Snapshots store incremental table modifications, such as APPEND/INSERT/DELETE. Snapshots can be used to roll a table back to a specific point. This differs from dbt snapshots as dbt snapshots facilitate slowly changing dimensions, while iceberg snapshots enable:

- Time Travel: Query historical versions of data
- Concurrent Operations: Multiple writers can work safely through concurrency
- Data Recovery: Rollback to previous table states

### Snapshot Lifetimes (Iceberg)

Snapshots can be expired after a specific time, at which point the snapshot, and its associated data/metadata files are deleted and cannot be used for rolling back.You cannot expire snapshots below a specific number of days specified in the iceberg service configuration.

### Snapshot Retention Quantity (Iceberg)

A minimum number of snapshots is retained (ordered from newest to oldest) so that expiring a snapshots older than a period does not delete the entire table.