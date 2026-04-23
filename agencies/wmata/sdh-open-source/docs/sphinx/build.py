import shutil
import subprocess
from pathlib import Path

docs_dir = Path(__file__).parent
sphinx_source_dir = docs_dir / "source"
root_dir = Path(__file__).parent.parent.parent

# Configuration -------------------------------------------------------------------

# This is a list of relative paths to files from globbing .md that we want to exclude
# from the final build
FILES_TO_CLEAN_UP = []

# Helper functions ----------------------------------------------------------------


def clean_up_files(files_to_remove: list, target_dir: Path):
    """Take a list of relative paths and remove files to silence warnings."""
    for f in files_to_remove:
        (target_dir / f).unlink(missing_ok=True)


def setup_source_directory(sphinx_source_dir: Path):
    """Set up the sphinx source directory by copying only additional content."""

    # Clear existing source directory - avoid toctree warnings
    if sphinx_source_dir.exists():
        shutil.rmtree(sphinx_source_dir)
    sphinx_source_dir.mkdir(parents=True, exist_ok=True)

    if (
        not sphinx_source_dir.exists()
    ):  # Just confirm that it exists, some defensive programming here.
        raise Exception(
            "Sphinx source dir {sphinx_source_dir} does not exist, unable to proceed with docs build."
        )
    # Copy template files to source (Sphinx needs them in the source directory)
    templates_dir = docs_dir / "templates"
    for template_path in templates_dir.rglob("*"):
        if template_path.is_file():
            relative_path = template_path.relative_to(templates_dir)
            target_location = sphinx_source_dir / relative_path
            target_location.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(template_path, target_location)

    # Copy diagrams directory to _static for serving as static files
    diagrams_source = root_dir / "docs" / "diagrams"
    diagrams_target = sphinx_source_dir / "_static" / "diagrams"
    if diagrams_source.exists():
        shutil.copytree(diagrams_source, diagrams_target, dirs_exist_ok=True)

    # Copy and modify README.md for Sphinx context
    readme_source = root_dir / "README.md"
    readme_target = sphinx_source_dir / "README.md"
    if readme_source.exists():
        # Read the original README.md
        with open(readme_source, "r", encoding="utf-8") as f:
            content = f.read()

        # Replace docs/ paths with HTML paths for Sphinx
        # All docs/ subdirectories are copied to the sphinx source root
        # and .md files become .html files in the built documentation due to links from
        # ./README.md or other external docs
        path_replacements = {
            "docs/CONTRIBUTING.md": "CONTRIBUTING.html",
            "docs/warehouse/README.md": "warehouse/README.html",  # Keep as README.html
            "docs/warehouse/sample_data_workflow.md": "warehouse/sample_data_workflow.html",
            "docs/dagster/deployment.md": "dagster/deployment.html",
            "docs/pipelines/README.md": "pipelines/README.html",  # Keep as README.html
            "warehouse/README.md": "warehouse/README.html",  # Keep as README.html
            "docs/diagrams/architecture.drawio.svg": "_static/diagrams/architecture.drawio.svg",
        }

        for old_path, new_path in path_replacements.items():
            content = content.replace(old_path, new_path)

        # Write the modified content to the target
        with open(readme_target, "w", encoding="utf-8") as f:
            f.write(content)

    # Copy CONTRIBUTING.md from docs/ folder
    contributing_source = root_dir / "docs" / "CONTRIBUTING.md"
    contributing_target = sphinx_source_dir / "CONTRIBUTING.md"
    if contributing_source.exists():
        shutil.copy2(contributing_source, contributing_target)

    # Find directories containing .md files and copy their markdown content
    docs_root = root_dir / "docs"
    dirs_to_copy = []

    # Go through directories and find those containing .md files
    for item in docs_root.iterdir():
        if (
            item.is_dir() and item.name != "sphinx"
        ):  # Exclude sphinx directory, otherwise this runs on itself
            if any(item.glob("*.md")):
                dirs_to_copy.append(item.name)

    # Copy .md files from directories that contain them
    for doc_dir in dirs_to_copy:
        source_dir_path = docs_root / doc_dir
        target_dir_path = sphinx_source_dir / doc_dir

        # Create target directory
        target_dir_path.mkdir(parents=True, exist_ok=True)

        # Copy all .md files except index.md (which are now templates)
        for md_file in source_dir_path.glob("*.md"):
            if md_file.name != "index.md":
                target_file = target_dir_path / md_file.name
                shutil.copy2(md_file, target_file)

    # Copy diagrams directory
    diagrams_source = docs_root / "diagrams"
    diagrams_target = sphinx_source_dir / "diagrams"
    if diagrams_source.exists():
        shutil.copytree(diagrams_source, diagrams_target, dirs_exist_ok=True)

    # Clean up noisy files
    clean_up_files(files_to_remove=FILES_TO_CLEAN_UP, target_dir=sphinx_source_dir)


# Main build logic ----------------------------------------------------------------------


def build(
    source_dir: Path = docs_dir / "source",
    build_dir: Path = docs_dir / "build",
    overwrite: bool = True,
) -> None:
    """Build the documentation using Sphinx.

    Parameters
    ----------
    source_dir : Path, optional
         The path to the source directory containing the Sphinx documentation., by default docs_dir/"source"
    build_dir : Path, optional
        The path to the build directory where the documentation will be generated., by default docs_dir/"build"
    overwrite : bool, optional
        Whether to overwrite docs or not, by default True
    """

    # Find the path to the uv executable
    uv_path = shutil.which("uv")
    if uv_path is None:
        error = "Could not find the 'uv' executable. Please ensure it is installed and in your PATH."
        raise FileNotFoundError(error)

    if not overwrite and build_dir.exists():
        error = f"Build directory {build_dir} already exists. Use overwrite=True to overwrite it."
        raise FileExistsError(error)

    # Setup the complete source directory
    setup_source_directory(sphinx_source_dir=source_dir)

    # Then run build command
    subprocess.run(
        [
            uv_path,
            "run",
            "sphinx-build",
            "-b",
            "html",
            "-a",
            "-E",
            str(source_dir),
            str(build_dir),
        ],
        check=True,
    )


if __name__ == "__main__":
    build()