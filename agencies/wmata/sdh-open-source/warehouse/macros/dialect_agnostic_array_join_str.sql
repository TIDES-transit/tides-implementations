{# This macro is a dialect agnostic wrapper for aggregating an array into a string, with a separator.#}
{# You may optionally specify if you only want DISTINCT values on the column #}
{# Grouping operations must be performed with in a CTE #}
{# `agg_col` - the column to aggregate to string #}
{# `separator` - character used to separate values, by default ',' #}
{# `use_distinct` - boolean, default False, whether to filter to DISTINCT values within the aggregation clause #}
{# `order_col` - string, default None, if specified or not None ORDER BY the 'order_col' column within the aggregation clause #}

{% macro agg_array_to_string(agg_col, separator=",", use_distinct=False, order_col=None) %}
    {% if target.type == 'duckdb' %}
        string_agg(
            {% if use_distinct %} DISTINCT {% endif %}
            {{agg_col }}, -- syntax: STRING_AGG(DISTINCT agg_col, "sep" ORDER BY order_col)
           '{{ separator }}'
            {% if order_col %} ORDER BY {{ order_col }} {% endif %})
    {% elif target.type == 'trino' %}
        {% if use_distinct and order_col %}
            {{ exceptions.raise_compiler_error(
                "agg_array_to_string: Trino does not support ORDER BY inside ARRAY_AGG(DISTINCT ...). "
                ~ "Use either use_distinct or order_col, not both."
            ) }}
        {% endif %}
        array_join(array_agg(
            {% if use_distinct %} DISTINCT {% endif %}
            {{ agg_col }}
            {% if order_col %} ORDER BY {{ order_col }} {% endif %}
            ), '{{ separator }}')
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by agg_array_to_string macro."
        ) }}
    {% endif %}
{% endmacro %}


