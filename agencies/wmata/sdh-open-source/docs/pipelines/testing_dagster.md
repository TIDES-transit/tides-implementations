# Testing Dagster in Python

The project's dev environment at the root level includes python testing libraries (`pytest`) and coverage tools (`pytest-cov` and `coverage`). Settings are managed in `pyproject.toml` and `.vscode/settings.json`.

## Guidance on Testing

- **Runtime asset checks**:
  - Focus on runtime asset checks ([see details](https://docs.dagster.io/guides/test/asset-checks)), e.g., does unzipped GTFS feed have rows? Are there items that would lead to a catastrophic failure in dbt?
  - Leave expectation tests about data (e.g., columns, non-nulls, etc.) to dbt.
  
- **Unit and integration tests**:
  - At a high-level, be selective and cautious about what you decide to test in a developer framework. Some simple tests are present in the repo. Decide at the issue creation about what tests are needed.
  - Largely, we will focus on ensuring that the pipeline runs in the dev environment as a means of ensuring the pipeline is working.
  - That said, [additional guidance on Dagster testing is here](https://docs.dagster.io/guides/test/unit-testing-assets-and-ops)
  - *Key targets for testing in python*:
    - Unit testing:
      - Utility or helper functions: these are candidates for unit testing.
      - Error handling: ensuring we have logic when API requests fail (e.g., error message enhancement, clean up of actions after error, other recovery)
      - General regression testing/feature validation/schema: Making sure that specific input results in output (note: asset checks at runtime are strongly preferred).

    - Integration testing.
      - For now, avoid these unless you are testing specific failure behavior like those above. Testing dagster assets by creating mock context and executing.

  - *Methods*:
    - Use pytest (unittest magicmocks fine).
    - Follow stack-specific guidance first and foremost.
    - Use Test classes and methods to allow for setup and teardown methods, inheritance, and pre-empt possible test namespace issues.
    - Use fixtures to define re-usable test assets. Put them in a `conftest.py` when they need to be auto-discovered by multiple test files.
    - Monitor code coverage results (e.g., Run with Coverage) to ensure you're testing the codebase thoroughly; only unit and integration tests will count towards coverage.
    - Use pytest markers to identify the type of test. See the defined markers in `pyproject.toml`; do feel free to create some others as needed. For instance: `@pytest.mark.integration` above the test function.

  - *On the back-burner for now*:
    - Security tests: We may want to validate that certain roles don't have the ability to take certain actions, or that certain fields have been hashed.
    - End-to-end tests: These can be tricky to mock thoroughly, especially when Azure or other cloud resources are involved. An alternative would be to create 'local' alternatives for many of these methods, but that may require a good deal of work and create other risks.  We may be better off just monitoring the development environment for these cases. We'll see.
  - *What else not to test*:
    - Placeholder implementations that will not be present in the repo over the long term (e.g., don't test functions that write to Parquet while we're waiting for iceberg catalog).
    - Don't test API access (ala that [AGENCY] API endpoint works) or mock-heavy items.
    - Low risk items (if test fails and no one cares, it is low risk.)
    - In general, 'testing' will focus more on testing that data is present/coming through the pipeline

## Local Testing/Development

- vscode's test panel will automatically pick up tests in the repository. Locally, only `unit` and `integration` tests will be run using settings.json configuration (`pyproject.toml` does not have test filters to avoid possible challenges elsewhere; may revisit inclusion of integration tests here and for coverage stats later, this is being a bit generous).
- Use "run with coverage" from the vscode panel to generate coverage statistics during test runs. Again, only unit and integration tests will be included in coverage statistics. There is currently no coverage target. To generate a coverage report, use:

```sh
pytest --cov --cov-report=xml --cov-report=html
```

This will generate an HTML report in the `htmlcov` directory for detailed inspection.

## CI testing

*In Progress*: CI testing not yet implemented.