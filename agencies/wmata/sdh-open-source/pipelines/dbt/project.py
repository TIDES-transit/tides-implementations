from pathlib import Path

from dagster_dbt import DbtProject


warehouse_dbt_project = DbtProject(
    project_dir=Path(__file__).joinpath("..", "..", "..", "warehouse").resolve(),
    # packaged_project_dir=Path(__file__).joinpath("..", "..", "dbt-project").resolve(),
)

warehouse_dbt_project.prepare_if_dev()
