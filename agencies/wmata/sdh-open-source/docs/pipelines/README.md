# TIDES Infrastructure Dagster Pipelines

This directory contains the Dagster pipeline assets for the [AGENCY] Data Infrastructure project. These pipelines handle data ingestion and storage operations for transit data.

## Pipeline Overview

| Pipeline | Purpose | Source | Destination | Schedule |
|----------|---------|--------|-------------|----------|
| Bus info | Retrieves bus info data for analysis | Oracle DB | Azure Data Lake Storage | Daily at 5 AM ET |
| Real-time bus info | Retrieves real-time bus info data for staging | Oracle DB | Azure Data Lake Storage | Will run every 10 minutes |
| GTFS | Retrieves GTFS data for transit schedules | [AGENCY] API | Azure Data Lake Storage | Daily at 4 AM ET |
| Fare Data | Retrieves faregate_data and FARE data for staging | Oracle DB | Azure Data Lake Storage | Daily at 5 AM ET |
| vendor_2 | Retrieves vendor_2 tables for staging | Oracle DB | Azure Data Lake Storage | Daily at 5 AM ET, though one table runs every 10 minutes |

## Getting Started

To prepare to run these pipelines locally you can run the setup script or use the script `./scripts/setup-dev-env.sh` from the project root. This script is only configured to work with Ubuntu at this time. **Do not run this script as sudo/root**. You will be prompted for your sudo password when the script executes in order to install some specific packages via `apt install`.

1. Set up environment variables using one of these methods:

   **Option A: Pull from Azure Key Vault (recommended for deployed environments)**

   If you have access to a deployed environment's Key Vault, you can pull the environment variables directly:

   ```bash
   # For [AGENCY]-managed environments (dev, stg, prd):
   scripts/pull-dotenv dev    # or stg, prd

   # For the legacy consultant environment:
   scripts/pull-dotenv-legacy
   ```

   **Option B: Manual configuration (for local development)**

   Copy `example.env` in the project root to `.env` and populate as needed:
   - `[Project Name]_ENVIRONMENT`=anything other than the word "consultant"
   - `DAGSTER_HOME`=the full path to your .dagster_home directory (within the project root)
   - `KEY_VAULT_NAME`=the name of the keyvault in Azure - activate JIT permissions and retrieve it
   - `AZURE_GTFS_STORAGE_ACCOUNT`=the name of the storage account in Azure - activate JIT permissions and retrieve it
   - `AZURE_FARE_STORAGE_ACCOUNT`=the name of the storage account in Azure - activate JIT permissions and retrieve it
2. Install oracle instant client (more on this below)
3. Setup dbt
4. Activate the project root virtual environment with `uv sync` and then the activation command based on your OS.
5. Start Dagster UI: `dagster dev`
6. Access the UI at <http://localhost:3000> or other link displayed in your terminal.

### Setup dbt

- `cd` into the `[project-name]/warehouse` directory
- Copy the `profiles.yml.template` to `profiles.yml` - this is how you set what dbt should run against for materializing models
- Run `dbt run` - if this errors, you may need to run `dbt deps` to install dbt-specific dependencies

### Installing Oracle Instant client

Oracle instant client is an external dependency that is used to retrieve data from Oracle SQL servers. This requires retrieving drivers to run queries. For more installation background, see the [oracledb documentation](https://python-oracledb.readthedocs.io/en/latest/user_guide/installation.html).

This process varies based on your OS. A recommended workflow for each is listed below.

To start with, download the [appropriate zip file for your development OS from Oracle](https://www.oracle.com/database/technologies/instant-client/downloads.html). You'll want the Basic package for your OS and 64/32-bit architecture.

#### Testing Install

After you've followed the install instructions below, you can either run `dagster dev` and see if the service launches without errors, OR run:`uv run python -c "import oracledb; oracledb.init_oracle_client()"` to verify the driver loads properly.

#### Windows

> NOTE: You may be required to install a version of Visual Studio to get Oracle Instant Client to work on windows. Refer to [Oracle's Documentation for the exact version](https://python-oracledb.readthedocs.io/en/latest/user_guide/installation.html#id3).

1) Unzip the instantclient archive to a location that the dagster software is allowed to access, such as your Documents folder, or C:\Users\{your_user}\instantclient
2) Add the path to the root instantclient folder to your PATH. You may go to Start > Edit environment variables for your account > select `Path` > Edit > and add New and insert the full path

- You may need to ensure that this is above any other Oracle client libraries, as the PATH is evluated from top to bottom

#### MacOS

This section may warrant further updates, as deployment on Mac varies compared to Linux installation.

1) Unzip the instantclient zip to a location that the pipeline is permitted to acces, such as your user home.
2) Copy this location
3) Run `export LD_LIBRARY_PATH=/the/location/you/copied:$LD_LIBRARY_PATH` and `echo 'export LD_LIBRARY_PATH=/the/location/you/copied:$LD_LIBRARY_PATH' >> ~/.bashrc` so that you don't need to rerun it any time you restart

#### Linux/Ubuntu

Currently this process has only been fully worked through for Ubunutu via WSL and containerized services. These instructions may vary for different linux flavors.

1) Unzip the instantclient zip to a location that the pipeline is permitted to acces, such as your user home.
2) Copy this location
3) Run `export LD_LIBRARY_PATH=/the/location/you/copied:$LD_LIBRARY_PATH` and `echo 'export LD_LIBRARY_PATH=/the/location/you/copied:$LD_LIBRARY_PATH' >> ~/.bashrc` so that you don't need to rerun it any time you restart
4) Run `sudo apt install libaio-dev` to install additional dependencies
5) You may also need to run `sudo ln -s /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/libaio.so.1` set up a symlink to help the driver find necessary files.

## Testing Pipelines

To test the pipelines:

1. Ensure environment variables are configured (see `example.env`)
2. Ensure you have Azure JIT permissions enabled for blob storage and key vault access
3. Run `dagster dev` and open the web UI
4. Select a pipeline and run it indiviudally for testing in development.
5. For partitioned assets, you may need to select a date range. It's recommended to select a range to validate that the pipeline is functioning as expected.
6. View logs and results in the Dagster UI

## Project Structure

Each pipeline contains its own folder (e..g, `./gtfs/`), typically with:

- `assets.py` for assets + asset_checks
- `schedules.py` for scheduling the pipeline to run
- `definitions.py` for defining the pipeline's assets, asset_checks, resource configurations, and schedules/sensors

Within the pipeline root there is also:

- `definitions.py`: The project root definitions.py file which imports definitions files from each pipeline
- `env.py` - Environment-wide configuration or setup, such as checking environment type, or sharing Azure credentials between pipelines
- `common/` - Functions common to assets to asset checks that don't quite fall under a resource
- `housekeeping/` - Cleanup or other data management jobs that dagster runs but are not exposed via the dag
- `resources/`: Shared resources between pipelines, such as for database connections and storage
- `tests/`: Tests for dagster assets and utilities. Generally tests expected outputs and error handling.
  - Run tests with `pytest pipelines/tests` from the root project directory.