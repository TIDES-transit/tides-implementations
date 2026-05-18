{% macro make_noon(column_name) -%}
  {{ return(adapter.dispatch('make_noon', 'warehouse')(column_name)) }}
{%- endmacro %}

{% macro default__make_noon(column_name) -%}
  {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by make_noon macro. Supported types: duckdb, trino"
        ) }}
{%- endmacro %}

{% macro trino__make_noon(column_name) -%}
  with_timezone(date_parse(cast({{ column_name }} as varchar) || 'T12:00:00', '%Y-%m-%dT%H:%i:%S'),'America/New_York')
{%- endmacro %}

{% macro duckdb__make_noon(column_name) -%}
  make_timestamptz(extract(year from {{ column_name }}), extract(month from {{ column_name }}), extract(day from {{ column_name }}), 12, 0, 0,'America/New_York')
{%- endmacro %}