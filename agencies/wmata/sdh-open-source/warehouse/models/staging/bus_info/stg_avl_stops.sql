{{ config(enabled=var('enable_realtime', false)) }}

with avl_stops_raw as (
    select * from {{ source('avl_lookups', 'stop_lookup_crosswalk') }}
),

stg_avl_stops as (
    select
        versionid,
        {{ flex_cast('geostopid', 'varchar') }} as geostopid,
        {{ flex_cast('stopid', 'varchar') }} as stopid,
        tageoreference,
        geostopdescription,
        latitude,
        longitude,
        heading
    from avl_stops_raw
)

select * from stg_avl_stops