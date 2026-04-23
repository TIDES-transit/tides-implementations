{#
  Dialect-agnostic safe casting macros with DuckDB and Trino compatibility.
  These macros handle type conversion failures gracefully by returning NULL
  for invalid inputs including NaN, Inf, and malformed values.
#}

{% macro _normalize_varchar(value) %}
    nullif(trim(cast({{ value }} as varchar)), '')
{% endmacro %}

{% macro _is_nan_like(value) %}
    case
        when {{ value }} is null then false
        when lower({{ value }}) in ('nan','inf','-inf','infinity','-infinity') then true
        else false
    end
{% endmacro %}

{# Extract ISO day of week (1=Monday, 7=Sunday) across different SQL dialects #}
{% macro extract_isodow(date_column) %}
    {% if target.type == 'duckdb' %}
        extract(isodow from {{ date_column }})
    {% elif target.type == 'trino' %}
        {# Trino's day_of_week already returns ISO values: 1=Monday, ..., 7=Sunday #}
        extract(day_of_week from {{ date_column }})
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by extract_isodow macro."
        ) }}
    {% endif %}
{% endmacro %}

{% macro flex_cast(expression, target_type, safe=False) %}
    {% set translated_type = api.Column.translate_type(target_type) %}
    {# Iceberg requires timestamp(6); Trino defaults to timestamp(3) which Iceberg rejects #}
    {% if target.type == 'trino' and translated_type.lower() == 'timestamp' %}
        {% set translated_type = 'timestamp(6)' %}
    {% endif %}
    {% set cast_fn = 'try_cast' if safe else 'cast' %}

    {#
        Runtime type check:
        - String types: normalize (trim + nullif empty) then cast
        - Other types: cast directly
        Both branches return the same target type.
        Note: Trino's typeof() returns length-qualified names (e.g. varchar(255)),
        so we use LIKE instead of exact matching.

        NOTE on empty-string behavior: when the input is a varchar/char type,
        the normalize step runs nullif(trim(cast(expr as varchar)), ''), which
        means empty strings are silently converted to NULL regardless of target
        type. Callers should be aware that '' and NULL are treated identically.
    #}
    case
        {% if target.type == 'duckdb' %}
        when typeof({{ expression }}) in ('VARCHAR', 'TEXT', 'STRING')
        {% elif target.type == 'trino' %}
        when typeof({{ expression }}) like 'varchar%' or typeof({{ expression }}) like 'char%'
        {% else %}
            {{ exceptions.raise_compiler_error(
                "Database type '" ~ target.type ~ "' is not supported by flex_cast macro."
            ) }}
        {% endif %}
        then {{ cast_fn }}({{ _normalize_varchar(expression) }} as {{ translated_type }})
        else {{ cast_fn }}({{ expression }} as {{ translated_type }})
    end
{% endmacro %}
