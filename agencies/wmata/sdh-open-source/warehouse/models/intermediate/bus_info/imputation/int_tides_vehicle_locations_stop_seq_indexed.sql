{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

-- Computes trip_stop_sequence_imputed for the filtered subset of vehicle location pings.
-- Operates on a slim 5-column dataset to minimize shuffle volume.
-- Output is keyed on location_ping_id; the parent imputation model LEFT JOINs this back
-- to the full-width dataset so that non-matching rows receive NULL (then filled downstream).

with tides_int as (
    select *
    from {{ ref('int_tides_vehicle_locations_imputation_trip_id') }}
),

-- filter to meaningful event types AFTER trip ID imputation
-- since event_type is not directly available, this uses schedule_relationship as a proxy
tides_int_filtered as (
    select
        location_ping_id,
        service_date,
        event_timestamp,
        trip_id_performed_imputed,
        stop_id_imputed
    from tides_int
    where
        -- 'Scheduled' from event_types 3,5,6,7,8,10,11 and 'Skipped' from event_type 4
        schedule_relationship in ('Skipped', 'Scheduled')
        -- include only rows with actual stop_id values, filtering out type 16 (timepoints) and type 9 (off route)
        and stop_id_imputed is not null
        -- filter out values which don't represent real stops
        and (trip_stop_sequence is null or trip_stop_sequence not in (0, -1))
),

ordered_events as (
    select
        tides_int_filtered.*,
        row_number() over (
            partition by tides_int_filtered.service_date, tides_int_filtered.trip_id_performed_imputed
            order by tides_int_filtered.event_timestamp, tides_int_filtered.location_ping_id
            -- tie-breaker is needed, otherwise pings at exactly same timestamp cause null in stop_rank
        ) as event_seq
    from tides_int_filtered
),

stop_occurrence as (
    select
        ordered_events.*,
        lag(ordered_events.event_timestamp) over (
            partition by
                ordered_events.service_date,
                ordered_events.trip_id_performed_imputed,
                ordered_events.stop_id_imputed
            order by ordered_events.event_seq
        ) as prev_same_stop_ts,

        lag(ordered_events.stop_id_imputed) over (
            partition by
                ordered_events.service_date,
                ordered_events.trip_id_performed_imputed
            order by ordered_events.event_seq
        ) as prev_overall_stop_id_imputed
    from ordered_events
),

new_visit_flag as (
    select
        location_ping_id,
        service_date,
        trip_id_performed_imputed,
        stop_id_imputed,
        event_seq,
        (stop_id_imputed is not null)
        and (
            prev_same_stop_ts is null
            or prev_overall_stop_id_imputed is distinct from stop_id_imputed
        ) as is_new_visit_bool
    from stop_occurrence
),

int_tides_vehicle_locations_stop_seq_indexed as (
    select
        location_ping_id,
        service_date,
        case
            when stop_id_imputed is null then null
            else sum({{ flex_cast("is_new_visit_bool", "integer") }}) over (
                partition by service_date, trip_id_performed_imputed
                order by event_seq
                rows unbounded preceding
            )
        end as trip_stop_sequence_imputed
    from new_visit_flag
)

select *
from int_tides_vehicle_locations_stop_seq_indexed
