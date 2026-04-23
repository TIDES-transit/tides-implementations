# Sphinx Documentation System

This directory contains the Sphinx documentation build system for the [Project Name] project.

## Overview

The documentation system uses a **template-based approach** where:

- **Templates** (tracked in git) define the documentation structure
- **Generated content** (ignored by git) is copied from various sources during build
- **Built HTML** (ignored by git) is the final output

## Building Documentation

### Quick Build

```bash
# From project root - runs build script, and emits docs
uv run python docs/sphinx/build.py
```

View documentation in `docs/sphinx/build/index.html`.

## Directory Structure

```text
docs/sphinx/
├── build.py              # Build script - generates docs from templates
├── templates/            # Source templates (tracked in git)
│   ├── conf.py          # Sphinx configuration
│   ├── index.md         # Homepage template
│   ├── _static/         # Static assets (CSS, images)
│   └── */index.md       # Section index templates
├── source/              # Generated source files (ignored by git)
│   ├── conf.py          # Copied from templates/
│   ├── index.md         # Copied from templates/
│   ├── _static/         # Copied from templates/
│   ├── README.md        # Copied from project root
│   ├── CONTRIBUTING.md  # Copied from docs/
│   └── */               # Copied from docs/ subdirectories
└── build/               # Built HTML output (ignored by git)
    └── index.html       # Final documentation site
```

## How It Works

The build process (`build.py`) performs these steps:

1. **Clean and setup** the `source/` directory
2. **Copy templates** from `templates/` to `source/`
3. **Copy root files** (README.md from root, CONTRIBUTING.md from docs/) to `source/`
4. **Copy documentation** from `docs/*/` directories to `source/`
5. **Run Sphinx** to generate HTML in `build/`

## Maintaining Documentation

### Adding New Sections

1. **Create content** in `docs/your-section/` directory
2. **Create template** at `docs/sphinx/templates/your-section/index.md` with toctree
3. **Add to navigation** in `docs/sphinx/templates/index.md` (hidden toctree)
4. **Build and test** with `uv run python docs/sphinx/build.py`

### Toctree Syntax

Section index templates use MyST toctree directives:

```text
# Section Name

{toctree}
:maxdepth: 2

page-name
subfolder/page-name
```

### Adding Root Files

Edit `build.py` and add files to the `root_files_to_copy` list to include additional root-level files like LICENSE or CHANGELOG.

## Configuration

Key configuration in `templates/conf.py`:

- MyST parser with Mermaid support
- Essential mock imports only (`oracledb`, `dagster_dbt`)
- Warning suppression for clean builds
- Sphinx Book Theme with custom CSS

## Git Workflow

### Tracked Files

- `docs/sphinx/templates/` - All template files
- `docs/sphinx/build.py` - Build script
- `docs/sphinx/Makefile` - Make configuration
- `docs/sphinx/README.md` - This documentation

### Ignored Files

- `docs/sphinx/source/` - Generated content
- `docs/sphinx/build/` - Built HTML output

Files are automatically ignored by `.gitignore` patterns.

## Troubleshooting

### Common Issues

- **Import errors**: Add problematic modules to `autodoc_mock_imports` in `templates/conf.py`
- **Missing navigation**: Ensure pages are included in toctree directives
- **Broken links**: Use relative paths with `.md` extension: `[Text](../path/file.md)`

### Development Commands

```bash
# Build documentation
uv run python docs/sphinx/build.py
```