{#
  Dialect-agnostic datetime parsing and GTFS time handling macros.

  These macros provide consistent datetime operations across DuckDB and Trino:
  - parse_datetime: Converts string values to timestamp/date with POSIX format support
  - gtfs_time_string_to_interval: Handles 24+ hour GTFS times (e.g., '26:30:00')

  Note: Trino with Iceberg doesn't support 'interval day to second' type.
#}

{% macro validate_posix_format_narrow(fmt) -%}
  {# remove all accepted tokens; if any '%' remains, it's unsupported #}
  {# I believe this assumes 00-23 hours as opposed to 1-12 #}
  {%- set s = fmt
      | replace('%Y','') | replace('%y','')
      | replace('%m','') | replace('%-m','')
      | replace('%d','') | replace('%-d','')
      | replace('%H','') | replace('%-H','')
      | replace('%M','') | replace('%-M','')
      | replace('%S','') | replace('%-S','')
      | replace('%f','') | replace('%g','')
      | replace('%n','')
  -%}
  {%- if '%' in s -%}
    {{ exceptions.raise_compiler_error(
      "Unsupported POSIX tokens in format '" ~ fmt ~
      "'. Allowed: %Y %y %m %-m %d %-d %H %-H %M %-M %S %-S %f %g %n"
    ) }}
  {%- endif -%}
{%- endmacro %}

{% macro posix_to_java(fmt) -%}
  {{- fmt
      | replace('%Y','yyyy') | replace('%y','yy')
      | replace('%-m','M')   | replace('%m','MM')
      | replace('%-d','d')   | replace('%d','dd')
      | replace('%-H','H')   | replace('%H','HH')
      | replace('%-M','m')   | replace('%M','mm')
      | replace('%-S','s')   | replace('%S','ss')
      | replace('%n','SSS')  | replace('%f','SSS') | replace('%g','SSS')
  -}} {# subseconds: accept but truncate to ms on Trino #}
{%- endmacro %}

{% macro as_date(column_name) %}
    {% if target.type == 'duckdb' %}
        {{ column_name }}::date
    {% elif target.type == 'trino' %}
        cast({{ column_name }} as date)
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by as_date macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

{% macro as_timestamp(column_name) %}
    {% if target.type == 'duckdb' %}
        {{ column_name }}::timestamp
    {% elif target.type == 'trino' %}
        cast({{ column_name }} as timestamp(6))
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by as_timestamp macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

{% macro parse_datetime(column_name, format_string, expected_length, type = "datetime") %}
    {{ validate_posix_format_narrow(format_string) }}
    {%- if type not in ["date", "datetime"] -%}
        {{ exceptions.raise_compiler_error(
            "Invalid type parameter '" ~ type ~ "'. Must be 'date' or 'datetime'"
        ) }}
    {%- endif -%}
    case
        when {{ column_name }} is null then null
        -- skip values that are the wrong number of characters
        when length(cast({{ column_name }} as varchar)) != {{ expected_length }} then null
        -- skip negative values
        when substr(cast({{ column_name }} as varchar), 1, 1) = '-' then null
        else
            {% if target.type == 'duckdb' %}
                {% if type == "date" %}
                    try_cast(try_strptime({{ column_name }}, '{{ format_string }}') as date)
                {% else %}
                    try_cast(try_strptime({{ column_name }}, '{{ format_string }}') as timestamp)
                {% endif %}
            {% elif target.type == 'trino' %}
                {% if type == "date" %}
                    try(cast(parse_datetime({{ column_name }}, '{{ posix_to_java(format_string) }}' ) as date))
                {% else %}
                    try(cast(parse_datetime({{ column_name }}, '{{ posix_to_java(format_string) }}' ) as timestamp(6)))
                {% endif %}
            {% else %}
                {{ exceptions.raise_compiler_error(
                    "Database type '" ~ target.type ~
                    "' is not supported by parse_datetime macro. Supported types: duckdb, trino"
                ) }}
            {% endif %}
  end
{% endmacro %}

{% macro utc_to_timezone(column_name, target_tz) %}
    {#
    Convert a UTC timestamp to the specified timezone.
    First casts the timestamp as UTC to ensure bare timestamps are properly interpreted as UTC.

    Usage: {{ utc_to_timezone('my_utc_timestamp', 'America/New_York') }}
    #}
    {% if target.type == 'duckdb' %}
        timezone('{{ target_tz }}', timezone('UTC', cast({{ column_name }} as timestamp)))
    {% elif target.type == 'trino' %}
        cast(at_timezone(at_timezone(cast({{ column_name }} as timestamp(6)), 'UTC'), '{{ target_tz }}') as timestamp(6))
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by utc_to_timezone macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

{% macro date_add(column_name, interval_value, interval_unit, date_part) %}
    {% if target.type == 'duckdb' %}
        date_trunc('{{ date_part }}', {{ column_name }} + INTERVAL ({{ interval_value }}) {{ interval_unit }})
    {% elif target.type == 'trino' %}
        {# Use Trino's date_add() function to support column references as interval values #}
        {% if interval_unit.upper() in ['HOUR', 'MINUTE', 'SECOND'] %}
            date_trunc('{{ date_part }}', date_add('{{ interval_unit }}', {{ interval_value }}, cast({{ column_name }} as timestamp(6))))
        {% else %}
            date_trunc('{{ date_part }}', date_add('{{ interval_unit }}', {{ interval_value }}, {{ column_name }}))
        {% endif %}
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by date_add macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

{% macro timestamp_add(column_name, interval_value, interval_unit, has_timezone=true) %}
    {% if target.type == 'duckdb' %}
        {{ column_name }} + INTERVAL ({{ interval_value }}) {{ interval_unit }}
    {% elif target.type == 'trino' %}
        {% if has_timezone %}
            date_add('{{ interval_unit }}', {{ interval_value }}, cast({{ column_name }} as timestamp(6) with time zone))
        {% else %}
            date_add('{{ interval_unit }}', {{ interval_value }}, cast({{ column_name }} as timestamp(6)))
        {% endif %}
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by timestamp_add macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

{#
    Convert a GTFS Time string (HH:MM:SS where HH can exceed 23) to an INTERVAL.
    - Valid examples: '00:00:00', '23:59:59', '26:30:30'
    - Returns NULL for non-matching inputs.
    - DuckDB: returns interval
    - Trino: returns interval day to second
    Note: does not work on Iceberg tables in Trino, as they do not support interval types.
#}
{% macro gtfs_time_string_to_interval(gtfs_time_field) %}
    case
        when {{ gtfs_time_field }} = '' or {{ gtfs_time_field }} is null then null
        {% if target.type == 'duckdb' %}
            when regexp_full_match(cast({{ gtfs_time_field }} as varchar), '^[0-9]+:[0-5][0-9]:[0-5][0-9]$') then
                (
                    cast(split_part({{ gtfs_time_field }}, ':', 1) as bigint) * 3600 +
                    cast(split_part({{ gtfs_time_field }}, ':', 2) as bigint) * 60 +
                    cast(split_part({{ gtfs_time_field }}, ':', 3) as bigint)
                ) * INTERVAL 1 SECOND
        {% elif target.type == 'trino' %}
            when regexp_like(cast({{ gtfs_time_field }} as varchar), '^[0-9]+:[0-5][0-9]:[0-5][0-9]$') then
                try(
                    (
                        cast(split_part({{ gtfs_time_field }}, ':', 1) as bigint) * 3600 +
                        cast(split_part({{ gtfs_time_field }}, ':', 2) as bigint) * 60 +
                        cast(split_part({{ gtfs_time_field }}, ':', 3) as bigint)
                    ) * INTERVAL '1' SECOND
                )
        {% else %}
            else {{ exceptions.raise_compiler_error(
                "Database type '" ~ target.type ~ "' is not supported by gtfs_time_string_to_interval macro. Supported types: duckdb, trino"
            ) }}
        {% endif %}
        else null
    end
{% endmacro %}

{#
    Convert a GTFS "Time" string (HH:MM:SS; HH may be >= 24) to BIGINT total seconds.
    Returns NULL if input is NULL/blank or does not match the pattern.
#}
{% macro gtfs_time_string_to_seconds(gtfs_time_field) %}
{%- set regex_pattern = "^([0-9]+):([0-5][0-9]):([0-5][0-9])$" -%}
{%- set hour_extract = "regexp_extract(" ~ gtfs_time_field ~ ", '" ~ regex_pattern ~ "', 1)" -%}
{%- set min_extract = "regexp_extract(" ~ gtfs_time_field ~ ", '" ~ regex_pattern ~ "', 2)" -%}
{%- set sec_extract = "regexp_extract(" ~ gtfs_time_field ~ ", '" ~ regex_pattern ~ "', 3)" -%}

case
  when {{ gtfs_time_field }} is null or {{ gtfs_time_field }} = '' then null
  else
    (
      {{ flex_cast(hour_extract, "bigint", safe=True) }} * 3600
    + {{ flex_cast(min_extract, "bigint", safe=True) }} * 60
    + {{ flex_cast(sec_extract, "bigint", safe=True) }}
    )
end
{% endmacro %}

{#
  Dialect-agnostic date/time difference calculation.
  Returns the difference between two timestamps in the specified unit.

  Usage: {{ date_diff_unit('second', 'start_ts', 'end_ts') }}
#}
{% macro date_diff_unit(unit, start_timestamp, end_timestamp) %}
    {% if target.type == 'duckdb' %}
        datediff('{{ unit }}', {{ start_timestamp }}, {{ end_timestamp }})
    {% elif target.type == 'trino' %}
        date_diff('{{ unit }}', {{ start_timestamp }}, {{ end_timestamp }})
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by date_diff_unit macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

{#
  Dialect-agnostic datetime formatting.
  Formats a timestamp using POSIX-style format strings (converted for Trino).

  Usage: {{ format_datetime('my_timestamp', '%Y%m%d%H%M%S') }}
#}
{% macro format_datetime(column_name, format_string) %}
    {%- set _allowed_formats = ['%Y%m%d%H%M%S', '%A'] -%}
    {%- if target.type == 'trino' and format_string not in _allowed_formats -%}
        {{ exceptions.raise_compiler_error(
            "format_datetime: format string '" ~ format_string ~ "' has not been verified for Trino. "
            ~ "Allowed formats: " ~ _allowed_formats | join(', ')
        ) }}
    {%- endif -%}
    {% if target.type == 'duckdb' %}
        strftime({{ column_name }}, '{{ format_string }}')
    {% elif target.type == 'trino' %}
        {# POSIX to Trino date_format: remap specifiers that differ #}
        {%- set trino_fmt = format_string
            | replace('%A', '%W')
            | replace('%M', '%i') | replace('%S', '%s')
        -%}
        date_format({{ column_name }}, '{{ trino_fmt }}')
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Unsupported target type: " ~ target.type
        ) }}
    {% endif %}
{% endmacro %}

{#
  Dialect-agnostic FIRST/LAST aggregate functions.

  For tie-breaking, pass multiple columns comma-separated:
    {{ first_agg('stop_id', 'arrival_time, _row_id') }}
  DuckDB uses ORDER BY directly; Trino wraps in ROW() for min_by/max_by.

  NOTE: Always include a deterministic tie-breaker (e.g. _row_id) as the last
  order_by column. Without one, DuckDB's first()/last() and Trino's min_by/max_by
  may return different rows when the primary order column has ties.
  ROW() comparison in Trino is lexicographic, matching DuckDB's multi-column ORDER BY.
#}
{% macro first_agg(column, order_by) %}
    {% if target.type == 'duckdb' %}
        first({{ column }} order by {{ order_by }})
    {% elif target.type == 'trino' %}
        {% if ',' in order_by %}
        min_by({{ column }}, row({{ order_by }}))
        {% else %}
        min_by({{ column }}, {{ order_by }})
        {% endif %}
    {% else %}
        {{ exceptions.raise_compiler_error("Unsupported target type: " ~ target.type) }}
    {% endif %}
{% endmacro %}

{% macro last_agg(column, order_by) %}
    {% if target.type == 'duckdb' %}
        last({{ column }} order by {{ order_by }})
    {% elif target.type == 'trino' %}
        {% if ',' in order_by %}
        max_by({{ column }}, row({{ order_by }}))
        {% else %}
        max_by({{ column }}, {{ order_by }})
        {% endif %}
    {% else %}
        {{ exceptions.raise_compiler_error("Unsupported target type: " ~ target.type) }}
    {% endif %}
{% endmacro %}

{#
  Dialect-agnostic FIRST_VALUE window function with IGNORE NULLS.
  The syntax for IGNORE NULLS differs between DuckDB and Trino.

  Usage: {{ first_value_ignore_nulls('column_name') }}

  Note: This returns just the function call - you still need to add the OVER clause.
  Example: {{ first_value_ignore_nulls('my_col') }} over (partition by x order by y rows between current row and unbounded following)
#}
{% macro first_value_ignore_nulls(column) %}
    {% if target.type == 'duckdb' %}
        first_value({{ column }} ignore nulls)
    {% elif target.type == 'trino' %}
        first_value({{ column }}) ignore nulls
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by first_value_ignore_nulls macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}

{#
  Dialect-agnostic LAST_VALUE window function with IGNORE NULLS.
  The syntax for IGNORE NULLS differs between DuckDB and Trino.

  Usage: {{ last_value_ignore_nulls('column_name') }}

  Note: This returns just the function call - you still need to add the OVER clause.
  Example: {{ last_value_ignore_nulls('my_col') }} over (partition by x order by y rows between unbounded preceding and current row)
#}
{% macro last_value_ignore_nulls(column) %}
    {% if target.type == 'duckdb' %}
        last_value({{ column }} ignore nulls)
    {% elif target.type == 'trino' %}
        last_value({{ column }}) ignore nulls
    {% else %}
        {{ exceptions.raise_compiler_error(
            "Database type '" ~ target.type ~ "' is not supported by last_value_ignore_nulls macro. Supported types: duckdb, trino"
        ) }}
    {% endif %}
{% endmacro %}
