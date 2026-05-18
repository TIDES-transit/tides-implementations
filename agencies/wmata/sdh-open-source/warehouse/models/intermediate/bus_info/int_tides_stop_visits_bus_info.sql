{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with stg as (
    select *
    from {{ ref("stg_bus_info") }}
),

--fill in imputed/improved values from final factual vehicle locations
vl_fct as (
    select
        location_ping_id,
        service_date,
        pattern_id,
        vehicle_id,
        event_timestamp,
        stop_id,
        schedule_relationship,
        trip_id_performed,
        trip_stop_sequence,
        scheduled_stop_sequence,
        odometer
    from {{ ref('fct_tides_vehicle_locations_bus') }}
),

int_tides_stop_visits_bus_info as (
    select
        stg._row_id,
        vl_fct.service_date,
        vl_fct.trip_id_performed,
        vl_fct.trip_stop_sequence,
        vl_fct.scheduled_stop_sequence,
        vl_fct.pattern_id, --unique identifier of route-pattern
        vl_fct.vehicle_id,
        stg.dwell_time as dwell,
        vl_fct.stop_id,
        {{ flex_cast("null", "boolean") }} as timepoint,
        {{ flex_cast("null", "timestamp(6)") }} as schedule_arrival_time,
        {{ flex_cast("null", "timestamp(6)") }} as schedule_departure_time,
        vl_fct.event_timestamp as actual_arrival_time,
        stg.departure_time as actual_departure_time,
        stg.stop_front_door_entry as boarding_1,
        stg.stop_front_door_exit as alighting_1,
        stg.stop_back_door_entry as boarding_2,
        stg.stop_back_door_exit as alighting_2,
        stg.passenger_load as departure_load,
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
        vl_fct.schedule_relationship,
        --custom replacement for ramp_deployed_time
        stg.wheel_chair as custom_ramp_deployed_count,
        -- col to compare w/ dwell
        {{ flex_cast(
            "date_diff('second', vl_fct.event_timestamp, stg.departure_time)",
            "integer",
            safe=True) }} as dwell_imputed,
        case -- compare cumulative odometer readings to get distance traveled
            when
                vl_fct.odometer
                > lag(vl_fct.odometer) over (
                    partition by vl_fct.vehicle_id, vl_fct.service_date
                    order by vl_fct.event_timestamp
                )
                then  --TODO preprocess window functions in a separate table
                    {{ flex_cast(
                        "(
                            vl_fct.odometer

                            - lag(
                                vl_fct.odometer
                            ) over (partition by vl_fct.vehicle_id, vl_fct.service_date order by vl_fct.event_timestamp)
                        )
                        * 0.3048",
                         "float",
                         safe=True
                    ) }} --translate ft to m
        end as distance
    from
        stg
    left join vl_fct on stg._row_id = vl_fct.location_ping_id
    where
    --limit to serviced and unknown stops (only events with boardings/alightings) + skipped stops
        stg.event_type in (3, 5, 4)
)

select * from int_tides_stop_visits_bus_info