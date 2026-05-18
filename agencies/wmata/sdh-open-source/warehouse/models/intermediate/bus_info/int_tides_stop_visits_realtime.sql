{{ config(
    enabled=var('enable_realtime', false),
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with int_tides_vehicle_locations_realtime as (
    select * from {{ ref('int_tides_vehicle_locations_realtime') }}
),

int_tides_stop_visits_realtime as (
    select
        location_ping_id as _row_id,
        service_date,
        trip_id_performed,
        -- TODO: need to fill in after vehicle locations or this model is matched to GTFS
        {{ flex_cast("null", "integer") }} as trip_stop_sequence,
        -- TODO: need to fill in after vehicle locations or this model is matched to GTFS
        {{ flex_cast("null", "integer") }} as scheduled_stop_sequence,
        pattern_id,
        vehicle_id,
        -- TODO: Could potentially be calculated if departure time is estimated from vehicle locations dataset
        {{ flex_cast("null", "integer") }} as dwell,
        stop_id,
        -- TODO: need to fill in after vehicle locations or this model is matched to GTFS
        {{ flex_cast("null", "boolean") }} as timepoint,
        -- TODO: need to fill in after vehicle locations or this model is matched to GTFS
        {{ flex_cast("null", "timestamp(6)") }} as schedule_arrival_time,
        -- TODO: need to fill in after vehicle locations or this model is matched to GTFS
        {{ flex_cast("null", "timestamp(6)") }} as schedule_departure_time,
        event_timestamp as actual_arrival_time,
        {{ flex_cast("null", "timestamp(6)") }}-- TODO: Could estimate departure time from vehicle locations dataset
            as actual_departure_time,
        {{ flex_cast("null", "double") }} as distance,
        apcon as boarding_1, -- APC on (passenger count increasing)
        apcoff as alighting_1, -- APC off (passenger count decreasing)
        {{ flex_cast("null", "integer") }} as boarding_2, -- Realtime data only has single APC measurement
        {{ flex_cast("null", "integer") }} as alighting_2, -- Realtime data only has single APC measurement
        {{ flex_cast("null", "integer") }} as departure_load, -- TODO: bring from realtime data source or calculate
        {{ flex_cast("null", "boolean") }} as door_open,
        {{ flex_cast("null", "boolean") }} as door_close,
        {{ flex_cast("null", "varchar", safe=True) }} as door_status,
        {{ flex_cast("null", "integer") }} as ramp_deployed_time,
        {{ flex_cast("null", "boolean") }} as ramp_failure,
        {{ flex_cast("null", "integer") }} as kneel_deployed_time,
        {{ flex_cast("null", "integer") }} as lift_deployed_time,
        {{ flex_cast("null", "boolean") }} as bike_rack_deployed,
        {{ flex_cast("null", "integer") }} as bike_load,
        {{ flex_cast("null", "integer") }} as revenue,
        {{ flex_cast("null", "integer") }} as number_of_transactions,
        schedule_relationship,
        {{ flex_cast("null", "integer") }}-- TODO: rename to _custom_ramp_deployed_count (non-TIDES)
            as custom_ramp_deployed_count
    from int_tides_vehicle_locations_realtime
    where
        -- Filter to only stop visits (revenue trips where vehicle is at a stop)
        is_stop_visit = true
)

select * from int_tides_stop_visits_realtime
order by service_date, pattern_id, vehicle_id, actual_arrival_time
