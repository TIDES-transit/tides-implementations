-- Extracts fare-data-compatible rail station codes from GTFS.
-- Uses two methods as a cross-check:
--   1. Extract from platform stop_ids (PF_{code}_{suffix} → code)
--   2. Extract from parent_station IDs (STN_{code} or STN_{code1}_{code2} → codes)
-- Joins through dim_stop_times → dim_trips → dim_routes to identify
-- stops served by rail routes (route_type = 1).

with dim_stop_times as (
    select * from {{ ref('dim_stop_times') }}
),

dim_trips as (
    select * from {{ ref('dim_trips') }}
),

dim_routes as (
    select * from {{ ref('dim_routes') }}
),

dim_stops as (
    select * from {{ ref('dim_stops') }}
),

rail_platform_stops as (
    select distinct
        dim_stop_times._feed_hash,
        dim_stop_times.stop_id as platform_stop_id,
        dim_stops.parent_station
    from dim_stop_times
    inner join dim_trips
        on
            dim_stop_times._feed_hash = dim_trips._feed_hash
            and dim_stop_times.trip_id = dim_trips.trip_id
    inner join dim_routes
        on
            dim_trips._feed_hash = dim_routes._feed_hash
            and dim_trips.route_id = dim_routes.route_id
    inner join dim_stops
        on
            dim_stop_times._feed_hash = dim_stops._feed_hash
            and dim_stop_times.stop_id = dim_stops.stop_id
    where dim_routes.route_type = 1
),

-- Method 1: extract station code from platform stop_id (PF_A01_1 → A01)
from_platforms as (
    select distinct
        _feed_hash,
        regexp_extract(platform_stop_id, '^PF_([A-Z][0-9]+)_', 1) as stop_id
    from rail_platform_stops
    where platform_stop_id like 'PF_%'
),

-- Method 2: extract station codes from parent_station (STN_A01 → A01, STN_A01_C01 → A01 and C01)
from_stations as (
    select distinct
        _feed_hash,
        regexp_extract(parent_station, 'STN_([A-Z][0-9]+)', 1) as stop_id
    from rail_platform_stops
    where parent_station like 'STN_%'
    union
    select distinct
        _feed_hash,
        regexp_extract(parent_station, '_([A-Z][0-9]+)$', 1) as stop_id
    from rail_platform_stops
    where parent_station like 'STN_%_%_%'  -- compound stations like STN_A01_C01
),

-- Union both methods (should produce the same set)
int_gtfs_rail_stops as (
    select distinct
        {{ dbt_utils.generate_surrogate_key(['_feed_hash', 'stop_id']) }} as _key,
        _feed_hash,
        stop_id
    from from_platforms
    where stop_id is not null
    union
    select distinct
        {{ dbt_utils.generate_surrogate_key(['_feed_hash', 'stop_id']) }} as _key,
        _feed_hash,
        stop_id
    from from_stations
    where stop_id is not null
)

select * from int_gtfs_rail_stops
