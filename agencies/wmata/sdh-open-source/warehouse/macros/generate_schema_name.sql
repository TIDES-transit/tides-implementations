{# This macro is copied from the Cal-ITP version: https://github.com/cal-itp/data-infra/blob/f01ef6344b9b02d5e8141e0d337fe4f21d66c5e6/warehouse/macros/generate_schema_name.sql #}
{# See the below link for a full explanation of this macro, but briefly it namespaces non-prod environments via a schema prefix #}
{# https://docs.getdbt.com/docs/building-a-dbt-project/building-models/using-custom-schemas#how-does-dbt-generate-a-models-schema-name #}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if not custom_schema_name -%}
        {{ default_schema }}
    {%- elif target.name.startswith('deployed') -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}