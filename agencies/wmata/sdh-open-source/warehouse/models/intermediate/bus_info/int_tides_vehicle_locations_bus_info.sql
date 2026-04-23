{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}


with stg_bus_info as (
    select * from {{ ref("stg_bus_info") }}
),

dim_patterns as (
    select
        _feed_hash,
        pattern_id,
        shape_id
    from
        {{ ref('dim_patterns') }}
),

fct_daily_feeds as (
    select
        _feed_hash,
        service_date
    from
        {{ ref('fct_daily_schedule_feed_modes') }}
    where
        feed_mode = 'Bus'
),

int_tides_vehicle_locations_bus_info as (
    select
        stg_bus_info._row_id as location_ping_id,
        stg_bus_info.service_date,
        stg_bus_info.event_time as event_timestamp,
        {{ flex_cast("null", "varchar") }} as trip_id_performed,
        stg_bus_info.trip_id as trip_id_scheduled,
        stg_bus_info.stop_sequence as trip_stop_sequence,
        {{ flex_cast("null", "integer") }} as scheduled_stop_sequence,
        {{ flex_cast("stg_bus_info.bus_id", "varchar") }} as vehicle_id,
        {{ flex_cast("null", "varchar") }} as device_id,
        stg_bus_info.route_id as pattern_id,
        stg_bus_info.ta_geo_id as stop_id,
        stg_bus_info.latitude,
        stg_bus_info.longitude,
        {{ flex_cast("null", "varchar") }} as gps_quality,
        stg_bus_info.heading,
        {{ flex_cast("null", "integer") }} as speed, --TRANSIT_AVG_SPEED is available in bus info by Rich
        stg_bus_info.odometer_distance as odometer,
        {{ flex_cast("null", "double") }} as schedule_deviation,
        {{ flex_cast("null", "double") }} as headway_deviation,
        -- derives trip type per TIDES enum based checking listed route_id col, ordered by frequency for performance
        -- creates current_status and schedule_relationship per TIDES enum
        dim_patterns.shape_id,
        -- Non-TIDES fields for quality analysis
        case
            when stg_bus_info.route_id like 'PI%' then 'Pullin'
            when stg_bus_info.route_id like 'PO%' then 'Pullout'
            when stg_bus_info.route_id like 'DH%' then 'Deadhead'
            when stg_bus_info.route_id like 'SH%' then 'Other not in service'
            when coalesce(regexp_extract(stg_bus_info.route_id, '^[A-Z](98|99)'), '') != '' then 'Other not in service'
            when stg_bus_info.route_id = '0' then 'Other not in service'
            when stg_bus_info.route_id like 'TTT%' then 'Other not in service'
            when dim_patterns.pattern_id is not null then 'In service'
            else 'Other not in service'
        end as trip_type,
        case
            when stg_bus_info.event_type = 3 then 'Stopped at'
            -- used to identify if there's activity at a given stop
            when (
                stg_bus_info.stop_front_door_entry > 0
                or stg_bus_info.stop_front_door_exit > 0
                or stg_bus_info.stop_back_door_entry > 0
                or stg_bus_info.stop_back_door_exit > 0
            ) then 'Stopped at'
        end as current_status,
        case
            when stg_bus_info.event_type = 4 then 'Skipped' -- Unserviced Stop = skipped
            when stg_bus_info.event_type in (3, 5, 6, 7, 8, 10, 11) then 'Scheduled' -- Serviced Stop = scheduled
        end as schedule_relationship
    from stg_bus_info
    left join fct_daily_feeds
        on stg_bus_info.service_date = fct_daily_feeds.service_date
    left join dim_patterns
        on
            stg_bus_info.route_id = dim_patterns.pattern_id
            and fct_daily_feeds._feed_hash = dim_patterns._feed_hash
)

select * from int_tides_vehicle_locations_bus_info