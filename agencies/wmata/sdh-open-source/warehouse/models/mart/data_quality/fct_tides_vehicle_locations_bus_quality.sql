{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with tides_int as (
    select
        *,
        {{ dbt_utils.generate_surrogate_key(['vehicle_id', 'event_timestamp', 'schedule_relationship','latitude', 'longitude','trip_stop_sequence','stop_id']) }} as row_hash --noqa:LT05
    from {{ ref('int_tides_vehicle_locations_imputation') }}
),

sched_seq as (
    select
        location_ping_id,
        scheduled_stop_sequence_imputed
    from
        {{ ref ('int_tides_vehicle_locations_bus_info_scheduled_stop') }}
),

dupes as (
    select
        row_hash,
        count(*) > 1 as has_dup,
        min(location_ping_id) as first_instance
    from tides_int
    group by row_hash

),

join_checks as (
    select
        tides_int.location_ping_id,
        dupes.has_dup as has_duplicates,
        tides_int.location_ping_id = dupes.first_instance as dup_row_to_keep,
        tides_int.service_date is not null as has_service_date,
        tides_int.trip_id_scheduled is not null as has_trip_id_scheduled,
        tides_int.trip_stop_sequence > 0 as has_positive_trip_stop_sequence,
        tides_int.stop_id is not null
        and tides_int.trip_stop_sequence <> tides_int.trip_stop_sequence_imputed as has_corrected_stop_sequence,
        tides_int.trip_id_performed_imputed is not null as has_imputed_trip_id_performed,
        coalesce(tides_int.stop_id <> tides_int.stop_id_imputed, false) as has_imputed_stop_id
    from tides_int
    left join dupes on tides_int.row_hash = dupes.row_hash
),

fct_tides_vehicle_locations_bus_quality as (
    select
        tides_int.location_ping_id,
        join_checks.dup_row_to_keep,
        -- checks
        join_checks.has_duplicates,
        join_checks.has_service_date,
        join_checks.has_trip_id_scheduled,
        join_checks.has_positive_trip_stop_sequence,
        join_checks.has_corrected_stop_sequence,
        join_checks.has_imputed_trip_id_performed,
        -- tides columns
        tides_int.service_date,
        tides_int.event_timestamp,
        tides_int.trip_id_performed,
        tides_int.trip_id_scheduled,
        tides_int.trip_stop_sequence,
        tides_int.scheduled_stop_sequence,
        tides_int.vehicle_id,
        tides_int.device_id,
        tides_int.pattern_id,
        tides_int.stop_id,
        tides_int.current_status,
        tides_int.latitude,
        tides_int.longitude,
        tides_int.gps_quality,
        tides_int.heading,
        tides_int.speed,
        tides_int.odometer,
        tides_int.schedule_deviation,
        tides_int.headway_deviation,
        tides_int.trip_type,
        tides_int.schedule_relationship,
        tides_int.trip_id_performed_imputed,
        tides_int.trip_stop_sequence_imputed,
        sched_seq.scheduled_stop_sequence_imputed,
        tides_int.stop_id_imputed,
        join_checks.has_imputed_stop_id,
        (
            --previously included dup_row_to_keep and has_positive_trip_stop_sequence in the filter condition;
            --removed these because they resulted in losing records associated with ridership
            --join_checks.dup_row_to_keep
            join_checks.has_service_date
            and join_checks.has_imputed_trip_id_performed
            --and join_checks.has_positive_trip_stop_sequence
        )
            as is_valid

    from tides_int
    left join join_checks on tides_int.location_ping_id = join_checks.location_ping_id
    left join sched_seq on tides_int.location_ping_id = sched_seq.location_ping_id
)

select * from fct_tides_vehicle_locations_bus_quality