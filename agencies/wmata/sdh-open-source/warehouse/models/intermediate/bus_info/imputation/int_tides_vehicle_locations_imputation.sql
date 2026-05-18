{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

-- Phase 2 of stop sequence imputation: fills trip_stop_sequence_imputed values for
-- non-stop events (null stop_id_imputed rows) using forward and backward fill.
-- Phase 1 (indexing) is in int_tides_vehicle_locations_stop_seq_indexed.

with trip_id_base as (
    select *
    from {{ ref('int_tides_vehicle_locations_imputation_trip_id') }}
),

stop_seq_indexed as (
    select *
    from {{ ref('int_tides_vehicle_locations_stop_seq_indexed') }}
),

-- Fill nulls: rejoin the indexed values back to the full-width dataset, then
-- fill down and up for rows that had no stop_id_imputed (and thus no index).
fill_base as (
    select
        trip_id_base.location_ping_id,
        trip_id_base.service_date,
        trip_id_base.event_timestamp,
        trip_id_base.trip_id_performed_imputed,
        trip_id_base.stop_id_imputed,
        stop_seq_indexed.trip_stop_sequence_imputed
    from trip_id_base
    left join stop_seq_indexed
        on trip_id_base.location_ping_id = stop_seq_indexed.location_ping_id
),

with_filled as (
    select
        fill_base.location_ping_id,
        fill_base.trip_stop_sequence_imputed,
        -- fill null trip_stop_sequence_imputed values by looking at events immediately preceding
        {{ last_value_ignore_nulls('fill_base.trip_stop_sequence_imputed') }} over (
            partition by fill_base.service_date, fill_base.trip_id_performed_imputed, fill_base.stop_id_imputed
            order by fill_base.event_timestamp
            rows between unbounded preceding and current row
        ) as trip_stop_sequence_filled_down,
        -- fill null trip_stop_sequence_imputed values by looking at events immediately following
        {{ first_value_ignore_nulls('fill_base.trip_stop_sequence_imputed') }} over (
            partition by fill_base.service_date, fill_base.trip_id_performed_imputed, fill_base.stop_id_imputed
            order by fill_base.event_timestamp
            rows between current row and unbounded following
        ) as trip_stop_sequence_filled_up
    from fill_base
),

-- Join filled values back to full-width data (single final join)

int_tides_vehicle_locations_imputation as (
    select
        trip_id_base.location_ping_id,
        trip_id_base.service_date,
        trip_id_base.event_timestamp,
        trip_id_base.trip_id_performed,
        trip_id_base.trip_id_scheduled,
        trip_id_base.trip_stop_sequence,
        trip_id_base.scheduled_stop_sequence,
        trip_id_base.vehicle_id,
        trip_id_base.device_id,
        trip_id_base.pattern_id,
        trip_id_base.stop_id,
        trip_id_base.current_status,
        trip_id_base.latitude,
        trip_id_base.longitude,
        trip_id_base.gps_quality,
        trip_id_base.heading,
        trip_id_base.speed,
        trip_id_base.odometer,
        trip_id_base.schedule_deviation,
        trip_id_base.headway_deviation,
        trip_id_base.trip_type,
        trip_id_base.schedule_relationship,
        trip_id_base.trip_id_performed_imputed,
        trip_id_base.stop_id_imputed,
        coalesce(
            with_filled.trip_stop_sequence_imputed,
            with_filled.trip_stop_sequence_filled_down,
            with_filled.trip_stop_sequence_filled_up
        ) as trip_stop_sequence_imputed
    from trip_id_base
    left join with_filled
        on trip_id_base.location_ping_id = with_filled.location_ping_id
)

select *
from int_tides_vehicle_locations_imputation
