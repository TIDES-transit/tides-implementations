{#
  Dialect-agnostic regular expression matching macro.

  This macro provides consistent regex matching across DuckDB and Trino:
  - DuckDB: Uses regexp_full_match — pattern must match the entire string implicitly.
  - Trino: Uses regexp_like — performs substring matching by default. Without ^ and $,
    a pattern like '[0-9]+' will match 'abc123' on Trino but NOT on DuckDB.

  ALWAYS include ^ and $ anchors for consistent full-string semantics across both engines.

  Parameters:
    - column_name: The column or expression to match against
    - pattern: The regex pattern — must include ^ and $ anchors

  Example usage:
    {{ regexp_match('column_name', '^[0-9]+$') }}
#}

{% macro regexp_match(column_name, pattern) %}
    {% if target.type == 'duckdb' %}
        regexp_full_match(cast({{ column_name }} as varchar), '{{ pattern }}')
    {% elif target.type == 'trino' %}
        regexp_like(cast({{ column_name }} as varchar), '{{ pattern }}')
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by regexp_match macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}
