# Contributing

This document details environment setup steps for different aspects of the repository. There are sections that can be expanded and troubleshooting tips.

This document covers setup steps for Windows/Mac/Linux, specifically how to install the required development tools. While this document provides instruction on how to set up the initial development and contribute to the overall development, additional documentation may be required for development of specific components.

> 📝 If you are using WSL for development, follow the Mac/Linux instructions for each step. This can be done in a terminal after installing WSL, such as in a terminal through [VS Code](https://code.visualstudio.com/docs/remote/wsl). For WSL development, all instructions in this document should be done in a terminal with WSL active.
> <details><summary>Using WSL in VS Code</summary>
>
> 1) Coordinate with IT to install WSL and VS Code.
> 2) Open VS Code, then navigate to extensions (`Ctrl+Shift+X` or the use the Extensions icon) and to search for and install the WSL extension from Microsoft.
> 3) Within a powershell session, run `wsl` to launch a wsl session.
> 4) `cd` to your project folder.
> 5) Run `code .` to open VS Code in the current directory.
> 6) You may now execute terminal commands, develop, and run code in WSL. You may need to open a new terminal in VS Code using `` Ctrl+Shift+` `` or go to `Terminal > New`.
>
> </details>

## Ubuntu Quickstart

Currently this repository includes a setup script (specifically for dagster development in `./scripts`).

You may run this script with `./scripts/bootstrap-dev` for general development using Ubuntu, or `.scripts/bootstrap-avd` for development on an AVD VM. Both will provide you with a functioning dev environment. **Do not run this script as sudo/root**. You will be prompted for your sudo password when the script executes in order to install some specific packages via `apt install`.

## Contents

- [Environment Requirements](#environment-requirements)
- [Environment Setup](#environment-setup)
  - [Development Environment Setup](#development-environment-setup)
  - [Project Structure and Dependencies](#project-structure-and-dependencies)
  - [VS Code Configuration](#vs-code-configuration)
- [Local Development and Analysis](#local-development-and-analysis)
- [Development Workflow](#development-workflow)
  - [GitHub Issues](#github-issues)
  - [Git Commits, Branches, Pull Requests](#git)
- [Documentation](#documentation)
- [Testing](#testing)

## Environment Requirements

This repository uses `uv` for dependency management and `pre-commit` for enforcing code quality. This is to ensure a consistent development experience. Follow below guidance on how to set up and maintain your development environment.

pre-commit is also configured to run as a GitHub action. If you make a push to a branch and the action fails (❌) check the Actions log. You may need to manually re-run `pre-commit run --all-files` or `pre-commit run --files path/to/some/file` to properly lint and fix issues.

The GitHub action will not automatically fix issues.

In the event you have an urgent need to push to a branch for an urgent fix, you can include `[skip ci]` in your commit message.

### Prerequisites

Before setting up your environment, ensure you have the following installed:

<details>
<summary>Python 3.10 or later</summary>

- **Python 3.10 or later** (as specified in pyproject.toml)
  - For Windows users:
    - Download Python from [python.org](https://www.python.org/downloads/)
      - Note: [AGENCY] laptop users may not have access to the Microsoft Store, which is the default way Windows tries to install Python. Always use the direct download from python.org.
    - During installation, check "Add Python to PATH"
    - Open PowerShell and verify installation with:

      ```powershell
      python --version
      ```

</details>

<details>
<summary>VS Code (Recommended IDE)</summary>

- Download from [code.visualstudio.com](https://code.visualstudio.com/download) ([AGENCY] laptop users should use this direct download method)
- Install the recommended extensions when prompted, or manually install them from `.vscode/extensions.json`.
- For Windows users: Ensure you're using PowerShell as your default terminal in VS Code

</details>

<details>
<summary>Git (Version Control)</summary>

- Download from [git-scm.com](https://git-scm.com/downloads/win)
- Recommended installation options:
  - Choose VS Code as the default editor if you're using it
  - Set `main` as the default branch name
  - Enable "Git from the command line and also from 3rd-party software" (adds Git to PATH)
  - For line endings, [AGENCY] developers may prefer "Checkout as-is, commit Unix-style" to maintain consistency with the repository
  - For `git pull` behavior, the default "Fast-forward or merge" is recommended, though some developers may prefer "Rebase"

</details>
<details><summary>uv (Dependency Management)</summary>

- If `uv` is not installed, install it using one of the OS specific options below. If you are installing via WSL, follow the Mac/Linux instructions within a WSL terminal. Otherwise, follow the Windows instructions.

    ```sh
    # Mac/Linux per [uv installation documentation](https://docs.astral.sh/uv/getting-started/installation/)
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ```

  For Windows, the recommended installation methods are:

  ```powershell
  # Windows PowerShell script (recommended)
  irm https://astral.sh/uv/install.ps1 | iex
  ```

  ```powershell
  # Windows via winget
  winget install astral.uv
  ```

  ```powershell
  # Windows via pip (alternative)
  # Note: When installing via pip, it's recommended to use an isolated environment
  python -m pip install uv
  ```

  See the [official uv installation documentation](https://docs.astral.sh/uv/getting-started/installation/#windows) for more details on Windows installation.

- Verify the installation with:

  ```sh
  uv --version
  ```

</details>

<details><summary>Linters and pre-commit tooling</summary>

This project makes use of several tools to automate code quality checks. These tools include the items below and may be automatically installed.

Linters are not automatically configured by `uv` when syncing project requirements. See [Environment Setup](#environment-setup) for linter and package installation steps.

- `ruff` - linter/formatter for Python code
- `sqlfluff` - linter/formatter for SQL code
- `pre-commit` - runs code quality checks and linting prior to commiting code to repository
- `sphinx` - builds documentation from documentation files and code docstrings

</details>

#### Windows-Specific Setup Notes

Specific Windows setup and troubleshooting is included in the [Workflow Wiki]([link redacted]). This document details specific setup and troubleshooting steps that may be useful during initial environment setup and configuration.

## Environment Setup

After installing the required tooling (ex: git, WSL if desired), you can clone the repository and install packages that are needed for development work.

### Development Environment Setup

This repository uses `uv` to manage Python dependencies and virtual environments.

#### 1. Clone the Repository

```sh
git clone https://github.com/[ORGANIZATION]/[project-name].git
cd [project-name]
```

#### 2. Create and Activate the Virtual Environment

```sh
uv venv


# Then activate the environment with the command for your OS 
.venv\Scripts\activate  # Windows
# OR
source .venv/bin/activate  # Mac/Linux
```

If you don't see the directory name (e.g., `([project-name])`) as a prefix, your environment is not activated. Either activate it using the commands above, or use the `uv run` prefix for all commands.
</details>

> **⚠️ IMPORTANT:** Activating the virtual environment is a critical step. When activated, your command prompt should show the directory name (e.g., `([project-name])`) at the beginning. If you skip this step, commands like `dbt` and `duckdb` will not work directly.

#### 3. Install Dependencies

For most users, simply run:

```sh
uv sync # Installs all core development dependencies
```

This repository also uses dependency groups for specific use cases, such as documentation generation, dagster deployment, or dbt development. uv dependency groups are defined subsets of dependencies that can be targeted when needed. You can view all available dependency groups in the `[tool.uv.groups]` section of `pyproject.toml`. Example dependency groups are:

```sh
# Examples of specific dependency groups
uv sync --group docs      # Documentation building dependencies
uv sync --group dagster   # Production Dagster dependencies only
uv sync --group dbt-dev   # dbt-specific development tools
```

#### 4. Verify the Installation

To confirm all dependencies are installed correctly:

```sh
uv pip list # your terminal should show a number of packages as being installed
```

#### 5. Install pre-commit

Pre-commit has an additional install step to install it within the project.

```sh
pre-commit install # Note: you must have the virtual environment activated
```

<details><summary>Verify pre-commit was installed</summary>

Ensure that you are in the project root and run:

```sh
pre-commit run --all-files
```

You should see a console output that pre-commit is installing the various tools that this project depends on. This may take a minute or two to run. You'll then see status updates of the various linting tools running against the project files, using the configuration specified in `pyproject.toml`.

</details>

### Project Structure and Dependencies

This repository has a nested structure with two Python projects, though they share a .venv:

Github Repository ([project-name]/):

- Has a project-wide `uv.lock` with dependency groups
- `uv sync` is sufficient for most users
- Each dependency group provides different packages
- The `dagster-dev` group contains everything for dbt and dagster development work
- The `dbt-dev` group contains everything for dbt-specific work
- The `dagster` and `dbt` groups contain things to run those specific services, but not necessarily develop
- The `docs` and `linters` groups contain tools focused around generating docs or linting code

> **Note**: You will need to `cd` into the `warehouse/` directory to run dbt commands. `dagster` commands should be run from the project root.

#### Linting and Formatting

This repository ensures consistent code formatting through pre-commit hooks that run automatically on each commit:

- `ruff`: Handles Python linting and formatting
- `sqlfluff`: Handles SQL linting and formatting, including support for dbt/templated SQL files
- `markdownlint` - Ensures that markdown is formatted appropriately
- `nbstripout` - Removes output cells from Jupyter Notebook cells
- `merge conflicts` - Checks for git merge conflicts in staged files

The pre-commit steps also run as a GitHub action. PRs will be unable to be merged until the actions pass.

<details>
<summary>Running Hooks Manually</summary>

While the hooks run automatically on commit, you can also run them manually:

```sh
# Run all pre-commit hooks
pre-commit run --all-files

# see what would be fixed without making changes, like a dry run
pre-commit run --all-files --show-diff-on-failure

# Or run individual tools directly (with activated environment)
ruff check . --fix
sqlfluff fix . --dialect duckdb

# Or run individual tools directly (without activated environment)
uv run ruff check . --fix
uv run sqlfluff fix . --dialect duckdb
```

</details>

### VS Code Configuration

#### Recommended Extensions

When you open this repository in VS Code, you will be prompted to install the recommended extensions. If not, install them manually from `.vscode/extensions.json`.

#### Key Settings

The repository enforces IDE settings via `.vscode/settings.json`.

<details><summary>Setting Usage and Troubleshooting</summary>

- Ensure the correct formatters and linters are applied.
- Configure editor settings for Python and SQL development.
- Standardize Python and SQL configurations.

If you experience issues, check that:

- You have installed all extensions listed in `.vscode/extensions.json`.
- Your VS Code settings match `.vscode/settings.json`.
- You restarted VS Code after updating dependencies.
- If working in WSL, ensure that you have connected to the WSL session (**Ctrl+Shift+P** > **Connect to WSL in New Window**)

</details>

#### Windows (non-WSL) vscode configuration

The project's `.vscode/settings.json` file configures the IDE for use with the project's tooling, but the default Python interpreter path uses a unix-style path that is appropriate for WSL, mac, or linux operating systems generally. For sqlfluff linting to behave correctly when running vscode in a Windows environment without wsl, you'll need to add the following line below to your user settings. Open settings with Ctrl+Shift+P and search for "Preferences: Open User Settings (JSON)", then add this line below.

```json
  "sqlfluff.executablePath": "${workspaceFolder}\\.venv\\Scripts\\sqlfluff.exe"
```

Note: this can affect other repositories and vscode workspaces that use sqlfluff, so consider the impacts.

## Local Development and Analysis

### Working with Sample Data

For information on working with sample data, including pre-loaded DuckDB files for analysts and loading from ZIP files for developers, please refer to the [Warehouse README](warehouse/README.md#2-working-with-sample-data).

> **⚠️ IMPORTANT:** Never commit sample data or database files to GitHub. The .gitignore is configured to prevent this, but be careful when making changes to these patterns.

### Personal Work and Analysis

For exploratory work, personal analysis, and other files that should not be committed to the repository, use the `scratch/` directory. This directory is already included in the repository (with `.gitkeep`) and is configured in `.gitignore` so its contents will not be tracked by Git.

```sh
# Use the scratch directory for exploratory notebooks, analysis scripts, etc.
# For example:
touch scratch/my_analysis.ipynb
touch scratch/data_exploration.py
```

All files in the `scratch/` directory will be ignored by Git, allowing you to work freely without worrying about accidentally committing personal or exploratory work.

## Development Workflow

This project makes extensive use of GitHub Issues, and git branches and pull requests to structure and coordinate work.

### GitHub Issues

- **Creating Issues**: Task leads will create issues; others can submit tickets to relevant task leads or raise during backlog management or sprint planning sessions.
- **Writing Issues**: Use one of the provided issue templates. Essential elements for an issue are described there.
- **Updating Issue Status**: Ensure the issue is added to the related Github Project [[project-name]](https://github.com/orgs/[ORGANIZATION]/projects/2). There is no need to separately add pull requests related to an issue in the Github Project. The issue's status can be updated in the following way:  
  - *Backlog*: For issues not yet assigned to a sprint.
  - *Ready*: When an issue is selected for development for a sprint, update its status from Backlog to Ready.
  - *In Progress*: When being actively worked on. You need not create a draft PR as soon as you've picked up the task.
  - *In Review*: When a PR has been created (for issues addressing features or bugs) or otherwise handed off for review. For this project, in a given sprint we strive to move tasks to from "Ready" to "In Review"; review and completion of the task can occur in subsequent sprints. When an issue is moved to "In Review", it should remain assigned to the individual originally assigned the task, not the reviewer. We will not create separate review tasks.
  - *Complete*: Once the PR has been approved by the relevant reviewers, the original author/assignee can merge the PR and mark the task as complete.
- **Subtasks**: Should be avoided, though checkbox lists are good simple alternatives.

### Git

#### Commits

- **Pre-commit**: Pre-commit hooks are provided for the repository--make sure you've set them up as described in **Environment Setup for Development**.
- **Commit Message Style**:  Use [conventional commits](https://www.conventionalcommits.org/). Similar prefixes like `eda:` are also fine. No need to add a scope in parentheses (e.g., `feat(rail movement): ...`) or an exclamation for breaking changes (e.g., `feat!: updated schema ...`).
- **Commit Habits**: Following the [conventional commits strategy](https://www.conventionalcommits.org/), use frequent, small commits while developing.
- **Squashing Commits**: If you need to clean up your git history somewhat, you can squash selected commits within a feature branch before merging--just avoid squashing the entire feature branch after the PR is approved (see **Pull Requests, Reviews, and Merging** below).

#### Branching

- **Branch Naming**: Try to create branches from the Issue itself to auto-generate the name, such that branch is prefixed with the issue number and includes a bit of the title (e.g., `6-create-contributing-md`).
- **Branching Strategy**: Branch directly from main using a trunk-based development strategy.
- **Branch Lifecycle**: Keep branches short-lived (i.e., ideally merged within a sprint or shortly thereafter) and focused on a single issue.

#### Pull Requests, Reviews, and Merging

- **Keeping Branches Updated**:
  - If your branch falls behind main, `rebase` the feature on main first; you will want to do this regularly to avoid more painful situations later (`git rebase origin/main`).
  - Avoid merging main into your branch or using built in branch 'update' features. Be sure to resolve and test any rebase issues locally.
- **Setting Up for a Review**:
  - For an issue assigned during a sprint, the goal is to move the issue to a PR before the end of the sprint
  - Open a pull request using the pull request template.
  - Assign reviewers based on the guidance in the PR template. At a later date, the project may consider implementing GitHub's code owners functionality to automatically assign reviewers to code that modifies particular items.
- **Reviewing PRs**:
  - If a pull request is draft, other contributors should hold off on reviewing.
  - Review may occur in the following sprint, especially if the reviewer is from a task team that may be engaged with the project only sporadically.
  - More detailed code review guidance is forthcoming, but should focus on:
    - *Maintainability*: Code:
      - is readable and documented
      - conforms to standards defined by linters and stylers
      - is testable through testing functionality in the project's stack
      - adheres to security practices
    - *Reliability*: Code is resilient to errors and uncommon circumstances
    - *Efficiency*: Code makes efficient use of compute resources and executes in a timely fashion
    - *Reusability*: Wherever possible, transformations are agnostic to a source data system's vendor and supportive of the project's open source goals

- **Addressing Comments and Merging PRs**:
  - Address comments with new commits, not editing previous ones.
  - When merging a PR, do not squash commits on the branch; rather, preserve commit history. If you need to, you can still squash selected commits on the feature branch during development.

## Documentation

Documentation for Python code is available in the `docs` directory but must be built. The command below exports html documentation to docs/sphinx/build as html files.

Docs may be viewed by opening index.html in your browser. A docs site is available at [https://[ORGANIZATION].github.io/[project-name]](https://[ORGANIZATION].github.io/[project-name]).

When making changes to documentation, you should generate a local docs site. This is useful as a way to test that the doc site generation succeeds without errors, and helps to test the documentation build process prior to pushing to main:

```sh
uv run docs/sphinx/build.py 
```

> The next few sections are in-progress and will undergo more development as the project progresses.

## Testing

*In Progress*: Testing will be elaborated on at a later date.

Note: the tests discussed here are development and CI tests, not runtime assertions.

### Testing Principles and practices

### dbt

Guidance on using built-in dbt tests and writing singular tests is included in the [dbt testing and quality guidance]('warehouse/dbt_tests_quality.md') document. This document details best practices for creating dbt tests, including preferred utilities, functions, and patterns.

### Python (esp. Dagster)

See [dagster testing README](./pipelines/tests/README.md)