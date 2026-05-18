{{ config(enabled=var('enable_realtime', false)) }}

with avl_trips_raw as (
    select * from {{ source('avl_lookups', 'route_lookup_crosswalk') }}
),

parse_datetimes as (
    select
        *,
        --ldate is stored as decimal, converting to int before parsing
        {{ parse_datetime(flex_cast(flex_cast('ldate', 'integer'), 'string'), '%Y%m%d', 8, 'date') }} as ldate_parsed,
        {{ as_timestamp('blockstarttime') }} as blockstarttime_parsed,
        {{ as_timestamp('blockendtime') }} as blockendtime_parsed,
        {{ as_timestamp('tripstarttime') }} as tripstarttime_parsed,
        {{ as_timestamp('tripendtime') }} as tripendtime_parsed
    from avl_trips_raw
),

calculate_service_date as (
    select
        *,
        {{ date_add('tripstarttime_parsed', -4, 'HOUR', 'DAY') }} as service_date
    from parse_datetimes
),

normalize_routes as (
    select
        *,
        {{ flex_cast('route', 'string') }} as route_normalized
    from calculate_service_date
),

stg_avl_trips as (
    select
        ldate_parsed as ldate,
        blockreference,
        blockstartts,
        blockendts,
        tripidentifier,
        tripstartts,
        tripendts,
        routevarid,
        routevarname,
        route_normalized as route,
        tapatternid,
        direction,
        {{ flex_cast('vendor_1_tripid', 'varchar') }} as vendor_1_tripid,
        isrevenue,
        blockstarttime_parsed as blockstarttime,
        blockendtime_parsed as blockendtime,
        tripstarttime_parsed as tripstarttime,
        tripendtime_parsed as tripendtime,
        service_date
    from normalize_routes
)

select * from stg_avl_trips