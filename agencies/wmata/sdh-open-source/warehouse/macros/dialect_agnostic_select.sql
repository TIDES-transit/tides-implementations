{#
  Dialect-agnostic SELECT helpers for DuckDB and Trino compatibility.
#}

{#
  Dialect-agnostic SELECT * EXCLUDE.
  DuckDB supports `SELECT * EXCLUDE (col)` natively.
  Trino uses the `exclude_columns` table function.

  Parameters:
    - relation: The CTE name or table alias to select from
    - exclude_cols: A list of column names to exclude from output

  Usage:
    {{ select_except('my_cte', ['transfer_priority']) }}

  DuckDB expands to:
    select * exclude (transfer_priority) from my_cte

  Trino expands to:
    select * from table(exclude_columns(
        input => table(my_cte),
        columns => descriptor(transfer_priority)
    ))

  Note: If you need to filter, create a separate CTE first then use select_except.
#}
{% macro select_except(relation, exclude_cols) %}
    {% if target.type == 'duckdb' %}
        select * exclude ({{ exclude_cols | join(', ') }}) from {{ relation }}
    {% elif target.type == 'trino' %}
        select * from table(exclude_columns(
            input => table({{ relation }}),
            columns => descriptor({{ exclude_cols | join(', ') }})
        ))
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by select_except macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

