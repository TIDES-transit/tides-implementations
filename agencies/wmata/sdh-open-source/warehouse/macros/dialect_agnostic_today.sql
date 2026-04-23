{% macro current_date_local() -%}
  {{ return(adapter.dispatch('current_date_local', 'warehouse')()) }}
{%- endmacro %}

{% macro default__current_date_local() -%}
  -- Fallback, may not work for all dbs
  current_date
{%- endmacro %}

{% macro trino__current_date_local() -%}
  date(current_timestamp AT TIME ZONE 'America/New_York')
{%- endmacro %}

{% macro duckdb__current_date_local() -%}
  cast((now() AT TIME ZONE 'America/New_York') as date)
{%- endmacro %}
