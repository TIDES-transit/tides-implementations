{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with tides_int as (
    select *
    from {{ ref('int_tides_vehicle_locations_bus_info_stop_id') }}
),

-- ensures that every record gets a trip_id_performed_imputed
base as (
    select
        tides_int.*,
        lag(tides_int.event_timestamp) over (
            partition by
                tides_int.service_date,
                tides_int.vehicle_id,
                tides_int.trip_id_scheduled,
                tides_int.pattern_id
            order by tides_int.event_timestamp, tides_int.location_ping_id
        ) as lag_ts
    from tides_int
),

with_gap_flag as (
    select
        base.*,
        case
            when base.lag_ts is null  -- first row of the day/vehicle/pattern/trip_id_scheduled
                then 1
            when {{ date_diff_unit('second', 'base.lag_ts', 'base.event_timestamp') }} >= 3600 --1 hr
                then 1
            else 0
        end as long_gap
    from base
),

trip_candidates as (
    select
        *,
        -- Running trip counter per vehicle_id +service_date
        sum(long_gap) over (
            partition by service_date, vehicle_id, trip_id_scheduled, pattern_id
            order by event_timestamp
            rows unbounded preceding
        ) as bus_trip_candidate
    from with_gap_flag
),

start_times as (
    select
        trip_candidates.*,
        -- first timestamp of each imputed trip
        min(trip_candidates.event_timestamp) over (
            partition by
                trip_candidates.service_date,
                trip_candidates.vehicle_id,
                trip_candidates.trip_id_scheduled,
                trip_candidates.pattern_id,
                trip_candidates.bus_trip_candidate
        ) as this_trip_candidate_start_time
    from trip_candidates
),

trip_id_proxy_col as (
    select
        start_times.*,
        -- trip_id_performed_imputed: trip_id_scheduled - bus id - pattern id - trip_start_time
        coalesce({{ flex_cast("start_times.trip_id_scheduled", "varchar", safe=True) }}, '#')
        || '-'
        || {{ flex_cast('start_times.vehicle_id', "varchar", safe=True) }}
        || '-'
        || coalesce({{ flex_cast('start_times.pattern_id', "varchar", safe=True) }}, '0')
        || '-'
        || {{ format_datetime('start_times.this_trip_candidate_start_time', '%Y%m%d%H%M%S') }}
            as trip_id_performed_imputed
    from start_times
),

int_tides_vehicle_locations_imputation_trip_id as (
    select
        location_ping_id,
        service_date,
        event_timestamp,
        trip_id_performed,
        trip_id_scheduled,
        trip_stop_sequence,
        scheduled_stop_sequence,
        vehicle_id,
        device_id,
        pattern_id,
        stop_id,
        current_status,
        latitude,
        longitude,
        gps_quality,
        heading,
        speed,
        odometer,
        schedule_deviation,
        headway_deviation,
        trip_type,
        schedule_relationship,
        stop_id_imputed,
        trip_id_performed_imputed
    from trip_id_proxy_col
)

select *
from int_tides_vehicle_locations_imputation_trip_id