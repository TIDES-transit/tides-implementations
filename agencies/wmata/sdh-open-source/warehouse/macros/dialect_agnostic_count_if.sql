{% macro count_if(statement) -%}
  {{ return(adapter.dispatch('count_if', 'warehouse')(statement)) }}
{%- endmacro %}

{% macro default__count_if(statement) -%}
  {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by count_if macro. Supported types: duckdb, trino"
        ) }}
{%- endmacro %}

{% macro trino__count_if(statement) -%}
  count_if({{ statement }})
{%- endmacro %}

{% macro duckdb__count_if(statement) -%}
    countif({{ statement }})
{%- endmacro %}