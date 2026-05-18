-- Test for partial null scheduled_stop_sequence_imputed within trips
-- Returns records where scheduled_stop_sequence_imputed is null but other records
-- in the same trip_id_performed_imputed have non-null values
-- This identifies data quality issues where only some stops within a trip are missing
-- their scheduled stop sequence, suggesting partial join failures or data inconsistencies
-- or just that the trip had a deviation. eventually we should untangle these so we can
-- write a test that passes.

{{ config(severity='warn') }}

with int_vl as (
    select
        service_date,
        trip_id_performed_imputed,
        trip_stop_sequence,
        stop_id,
        scheduled_stop_sequence_imputed
    from {{ ref('int_tides_vehicle_locations_bus_info_scheduled_stop') }}
    where
    -- because the non-stop event cases can occur in all sorts of orders, the check for monotonicity
    -- can be rather screwy if we don't just focus on these. At some point we may want to loosen this
    -- to look at all cases, but hard to say right now.
        schedule_relationship in ('Skipped', 'Scheduled')
),

trip_null_status as (
    select
        trip_id_performed_imputed,
        count(*) as total_records,
        count(scheduled_stop_sequence_imputed) as non_null_records,
        count(*) - count(scheduled_stop_sequence_imputed) as null_records
    from int_vl
    group by trip_id_performed_imputed
),

trips_with_mixed_nulls as (
    select trip_id_performed_imputed
    from trip_null_status
    where
        non_null_records > 0  -- has at least one non-null value
        and null_records > 0   -- has at least one null value
),

test_schedule_stop_sequence_partial_nulls as (

    select
        int_vl.service_date,
        int_vl.trip_id_performed_imputed,
        int_vl.trip_stop_sequence,
        int_vl.stop_id,
        int_vl.scheduled_stop_sequence_imputed
    from int_vl
    inner join trips_with_mixed_nulls
        on int_vl.trip_id_performed_imputed = trips_with_mixed_nulls.trip_id_performed_imputed
    where int_vl.scheduled_stop_sequence_imputed is null
)

select * from test_schedule_stop_sequence_partial_nulls