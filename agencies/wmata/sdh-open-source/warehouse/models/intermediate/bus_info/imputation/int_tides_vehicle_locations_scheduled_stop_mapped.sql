{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

-- Computes scheduled_stop_sequence_imputed on the distinct (one row per trip/stop) subset.
-- Operates on a small dataset to minimize window function overhead.
-- Output is joined back to the full vehicle locations dataset in
-- int_tides_vehicle_locations_bus_info_scheduled_stop.
--
-- Safety note: trip_id_performed_imputed embeds trip_id_scheduled in its construction
-- (see int_tides_vehicle_locations_imputation_trip_id), so the output join key
-- (service_date, trip_id_performed_imputed, trip_stop_sequence_imputed, stop_id)
-- is guaranteed unique per trip_id_scheduled. A uniqueness test enforces this.

with int_vl_filtered as (
    -- Apply all filter conditions from both int_vl and int_vl_filtered layers
    select
        service_date,
        trip_id_scheduled,
        stop_id,
        trip_id_performed_imputed,
        trip_stop_sequence_imputed
    from {{ ref("int_tides_vehicle_locations_imputation") }}
    where
        -- int_vl conditions
        trip_id_scheduled is not null
        and trip_type = 'In service'
        and stop_id is not null
        -- int_vl_filtered conditions
        and trip_stop_sequence not in (0, -1)
        and schedule_relationship in ('Skipped', 'Scheduled')
),

scheduled_stop_times as (
    select
        service_date,
        trip_id,
        stop_id,
        stop_sequence
    {# .render() opts out of microbatch auto-filtering — this model batches by service_date
       but fct_scheduled_stop_times uses event_time=_date_retrieved #}
    from {{ ref("fct_scheduled_stop_times").render() }}
    where route_type = 3
),

rowrank_stoptimes as (
    select
        *,
        row_number() over (
            partition by service_date, trip_id, stop_id
            order by stop_sequence
        ) as nth_trip_stop_visit_at_stop
    from scheduled_stop_times
),

distinct_businfo as (
    select distinct
        service_date,
        trip_id_scheduled,
        stop_id,
        trip_id_performed_imputed,
        trip_stop_sequence_imputed
    from int_vl_filtered
),

rowrank_businfo as (
    select
        *,
        row_number() over (
            partition by service_date, trip_id_performed_imputed, stop_id
            order by trip_stop_sequence_imputed
        ) as nth_trip_stop_visit_at_stop
    from distinct_businfo
),

first_join as (
    select
        rowrank_businfo.service_date,
        rowrank_businfo.trip_id_performed_imputed,
        rowrank_businfo.trip_stop_sequence_imputed,
        rowrank_businfo.stop_id,
        rowrank_stoptimes.stop_sequence as scheduled_stop_sequence_imputed
    from rowrank_businfo
    left join rowrank_stoptimes
        on
            rowrank_businfo.service_date = rowrank_stoptimes.service_date
            and rowrank_businfo.trip_id_scheduled = rowrank_stoptimes.trip_id
            and rowrank_businfo.stop_id = rowrank_stoptimes.stop_id
            and rowrank_businfo.nth_trip_stop_visit_at_stop = rowrank_stoptimes.nth_trip_stop_visit_at_stop
),

int_tides_vehicle_locations_scheduled_stop_mapped as (
    -- due to trip stop sequencing issues, we sometimes have a 'second' appearance of a stop that isn't
    -- actually a second visit. For these, we just fill down.
    select
        service_date,
        trip_id_performed_imputed,
        trip_stop_sequence_imputed,
        stop_id,
        {{ last_value_ignore_nulls('scheduled_stop_sequence_imputed') }} over (
            partition by trip_id_performed_imputed, stop_id
            order by scheduled_stop_sequence_imputed nulls last
            rows between unbounded preceding and current row
        ) as scheduled_stop_sequence_imputed
    from first_join
)

select *
from int_tides_vehicle_locations_scheduled_stop_mapped