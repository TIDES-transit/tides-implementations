# Data Warehouse

This dbt project manages the data warehouse for [AGENCY]'s TIDES system using DuckDB.

## Getting Started

### 1. Set Up Virtual Environment

First, ensure you have the warehouse virtual environment set up and activated:

> **⚠️ IMPORTANT:** Activating the virtual environment is a critical step. All commands in this guide assume you have an activated environment. If you skip this step, commands like `dbt` and `duckdb` will not work directly.

**Mac/Linux:**

```sh
# Navigate to the warehouse directory
cd [project-name]/warehouse

# Create the virtual environment (if not already created)
uv venv

# Activate the environment (CRITICAL STEP)
source .venv/bin/activate
```

**Windows (PowerShell):**

```powershell
# Navigate to the warehouse directory
cd [project-name]\warehouse

# Create the virtual environment (one-time only; do if not already created)
uv venv

# Activate the environment (CRITICAL STEP)
.venv\Scripts\activate

# If you encounter a PowerShell execution policy error, run:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Alternative Approach: Using `uv run`

If you have trouble activating the virtual environment or prefer not to activate it, you can prefix all commands with `uv run`. Ensure that you are in the `.warehouse/` directory, otherwise `dbt` commands will not work.

**Mac/Linux or Windows:**

```sh
# Instead of running dbt directly:
uv run dbt run

# Instead of running duckdb directly:
uv run duckdb warehouse.duckdb

# Instead of running python directly:
uv run python data-load-scripts/load_sample_data.py path/to/sample-data.zip
```

This approach runs the command within the virtual environment without requiring activation. This can be useful if you're switching between multiple projects or if you encounter issues with activation.

### 2. Working with Sample Data

For more detailed, step-by-step instructions on working with sample data, including alternative approaches for analysts, troubleshooting, and best practices, see the [Sample Data Workflow](sample_data_workflow.md) guide.

### 3. Common dbt Commands

Here are some common dbt commands you can run:

> **Note:** All commands below assume your virtual environment is activated. If not, prefix each command with `uv run`.

- `dbt run` - Execute all models
- `dbt run --select model_name` - Execute a specific model (in this case, `model_name`; note `.sql` suffix not present)
- `dbt test` - Run all tests - see [the dbt testing and quality overview]('dbt_tests_quality.md') for information on writing dbt tests.
- `dbt docs generate` - Generate documentation
- `dbt docs serve` - View documentation in a web browser

### 4. dbt and vscode

#### Extensions

The project recommends the use of the Power User for dbt extension.

Once activated, use the new Query Results, Lineage, Documenation Editor, and Actions panels to edit faster.

You can select the contents of a model, hit "Ctrl+Enter", and it will render the sql, execute it, and preview results.

#### Tasks

Several vscode tasks to run the currently opened model with `dbt run` and to run the upstream dependencies of a model are provided.

In the command prompt, write 'Tasks: Run Task` and choose one of the given options. You can load these tasks as keyboard shortcuts by going to `Preferences: Open Keyboard Shortcuts (JSON)` and adding the following:

```json
{
    "key": "ctrl+shift+enter",
    "command": "workbench.action.tasks.runTask",
    "args": "Run current dbt model",
    "when": "editorLangId == 'jinja-sql' && resourceExtname == '.sql'"
  },
  {
    "key": "ctrl+alt+enter",
    "command": "workbench.action.tasks.runTask",
    "args": "Run current dbt model and upstream dependencies",
    "when": "editorLangId == 'jinja-sql' && resourceExtname == '.sql'"
  }
```

Note that this should be surrounded by square brackets if you have no other custom shortcuts.

### 5. GUI Tools for DuckDB

For analysts and DBAs who prefer graphical interfaces over command-line tools, there are several options for working with DuckDB databases.

#### DBeaver

DBeaver is a popular, free, and cross-platform database tool that supports DuckDB.

**Installation:**

1. **Download and install DBeaver:**
   - Download from [dbeaver.io](https://dbeaver.io/download/)
   - Windows: Run the installer.  Note: no administrative permissions needed if installed only for current user.
   - Mac: Drag to Applications folder
   - Linux: Use the appropriate package for your distribution

2. **Connect to DuckDB:**
   - Open DBeaver
   - Click "New Database Connection" (database+ icon)
   - Search for and select "DuckDB"
   - If prompted to download the driver, click "Download"
   - For "Database", browse to your `warehouse.duckdb` file
   - Test the connection and click "Finish"

3. **Using DBeaver:**
   - Browse schemas and tables in the Database Navigator
   - Double-click on tables to view data
   - Create SQL queries using the SQL Editor
   - Execute queries and view results
   - Export data in various formats
   - Note that if you are connected to the warehouse duckdb file with dbeaver, you cannot execute `dbt run`, vscode dbt extensions, and similar commands from the command line because multiple read-write processes are not supported. It is also not possible to switch *only* the dbeaver connection to read-only mode. For more details, see [Concurrency](https://duckdb.org/docs/stable/connect/concurrency.html#writing-to-duckdb-from-multiple-processes) in the duckdb documentation.

**Detailed Instructions:**
For more detailed instructions, see the [DuckDB documentation on DBeaver](https://duckdb.org/docs/guides/sql_editors/dbeaver.html).

#### DuckDB Local UI (Future Option)

DuckDB recently [released a built-in web UI](https://duckdb.org/2025/03/12/duckdb-ui.html) that provides a powerful interface for working with DuckDB databases. When our project upgrades to DuckDB v1.2.1 or later, you'll be able to use this interface.

### Troubleshooting

#### "Command not found" Errors

If you see errors like `dbt: command not found` or `duckdb: command not found`:

1. **Check if your virtual environment is activated**
   - Your command prompt should show the directory name (e.g., `(warehouse)`) at the beginning
   - If not, activate it with `source .venv/bin/activate` (Mac/Linux) or `.venv\Scripts\activate` (Windows)

2. **Use the `uv run` prefix**
   - If activation doesn't work, prefix commands with `uv run`:
   - Example: `uv run dbt run` instead of `dbt run`

3. **Verify installation**
   - Run `uv pip list` to verify that dbt and duckdb are installed
   - If not, run `uv sync --group dagster-dev` to install all dependencies. See [CONTRIBUTING](<../CONTRIBUTING.md>) for examples of other environment options.

#### Windows-Specific Issues

1. **PowerShell Execution Policy**
   - If you can't activate the environment, run:
   - `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

2. **Path Separators**
   - Use backslashes (`\`) instead of forward slashes (`/`) in file paths
   - Example: `C:\path\to\file` instead of `C:/path/to/file`

3. **DuckDB CLI Issues**
   - If `duckdb` doesn't work, try `uv run duckdb`
   - If that doesn't work, try the full path: `.venv\Scripts\duckdb.exe`

### Resources

- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- DuckDB documentation: [DuckDB Docs](https://duckdb.org/docs/)
- Example project with similar setup: [duckdb-dbt-challenge](https://github.com/dscovr/duckdb-dbt-challenge)