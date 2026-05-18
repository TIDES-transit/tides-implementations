# Documentation

## Notebooks

Demonstration Jupyter notebooks are available in `.docs/demo`.

## Sphinx Documentation

Documentation is built using `sphinx`. You will need to have run `uv sync` to ensure that sphinx and associated extensions are installed.

## Building Documentation

`cd` into `./docs/sphinx` and then run `uv run build.py`. Sphinx will output the contents of the documentation to several HTML files into `.docs/build`. Open `index.html` and navigate as needed.

This will copy some markdown files (see `./docs/sphinx/build.py` for details) from other repository locations into the `.docs/sphinx/source` directory, and overwrite if they currently exist there. You should only make edits to the original files, not these copied files.

> NOTE: Cross-document anchor links should now work properly since CONTRIBUTING.md has been moved to the docs/ folder and can be referenced relatively.

## Sphinx background

Sphinx creates documentation from a mix of:

- sphinx documentation site markdown files (using an extension) located in `.docs/source`
- copied markdown files from different repository locations
- docstrings from Python processing code, stored using numpy format

VS Code extensions, settings, and linter configurations are used to recommend the docstring and enforce docstring formatting.
