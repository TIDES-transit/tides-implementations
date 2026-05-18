# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

from __future__ import annotations

import sys
import os
from pathlib import Path
import warnings

from pygments.lexers import TextLexer
from sphinx.highlighting import lexer_classes


project = "[Project Name]"
copyright = "2025, [AGENCY]"
author = "[AGENCY]"
sys.path.insert(0, os.path.abspath("../../.."))

# Add the docs directories to the source paths
docs_root = Path(__file__).parent.parent.parent
# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.napoleon",
    "sphinx.ext.viewcode",
    "myst_parser",
    "sphinxcontrib.mermaid",
]

myst_enable_extensions = [
    # "linkify",
    "colon_fence"
]
myst_fence_as_directive = ["mermaid"]  # Treat mermaid code blocks as directives


# Mock only essential imports that cause hard failures during doc builds
autodoc_mock_imports = [
    "oracledb",  # Oracle client library - hard requirement that may fail build
    "dagster_dbt",  # Requires manifest.json file that may not exist
    "dagster_dbt.dbt_assets",  # Other mocks due to some import issues
    "pipelines.dbt.definitions",
    "azure.identity",
    "azure.storage.blob",
    "azure.keyvault.secrets",
    "azure.core",
    "azure.storage",
    "azure.keyvault",
    "pyarrow",
    "pyarrow.parquet",
    "pandas",
    "pandas.compat",
    "pandas.compat.pyarrow",
]

warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*BetaWarning.*")
warnings.filterwarnings("ignore", message=".*backfill_policy.*")

myst_all_links_external = True
# Configure relative path resolution for cross-references
# Now that CONTRIBUTING.md is in docs/, relative links should work properly
myst_relative_docs_path = "../.."
templates_path = ["_templates"]
exclude_patterns = []

myst_heading_anchors = 3
myst_url_schemes = ["http", "https", "mailto", "ftp"]

# Configure code highlighting
highlight_language = "none"  # Don't guess language
pygments_style = "default"

# Configure Mermaid support
mermaid_output_format = (
    "raw"  # Render as JavaScript in browser instead of server-side PNG
)


def setup_custom_lexers():
    # Map HCL to text lexer to avoid parsing errors (JSON lexer is too strict)
    lexer_classes["hcl"] = TextLexer


def setup(app):
    setup_custom_lexers()


# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "sphinx_book_theme"
html_css_files = ["custom.css"]
html_static_path = ["_static"]