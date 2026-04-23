{{ config(enabled=var('enable_realtime', false)) }}

with int_tides_vehicle_locations_realtime as (
    select * from {{ ref('int_tides_vehicle_locations_realtime') }}
),

fct_tides_vehicle_locations_realtime_quality as (
    select
        *,
        -- TODO: Add quality checks for realtime vehicle locations, such as:
        -- - Validate GPS coordinates are within expected bounds
        -- - valid trip ID (after imputation)
        -- - Check for reasonable speed values
        -- - Validate event timestamp is recent
        -- - Check for required fields (vehicle_id, service_date, etc.)
        -- - Check for "jittery" stop ID/how that fits with the is_stop_visit flag
        -- - Validate stop_id exists in GTFS stops
        -- - Validate pattern_id
        -- - Validate APC count
        -- May need to move is_stop_visit flag here or even downstream to stop visits model
        true as is_valid -- TODO: rename to _is_valid (non-TIDES)
    from int_tides_vehicle_locations_realtime
)

select * from fct_tides_vehicle_locations_realtime_quality
