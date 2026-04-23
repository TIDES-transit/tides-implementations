{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with stop_visits as (
    select
        service_date,
        trip_id_performed,
        trip_stop_sequence,
        scheduled_stop_sequence,
        stop_id,
        actual_arrival_time,
        pattern_id,
        vehicle_id,
        departure_load,
        boarding_1,
        boarding_2,
        alighting_1,
        alighting_2
    from {{ ref('fct_tides_stop_visits_bus') }}
    {% if var('enable_realtime', false) %}
        union all
        select
            service_date,
            trip_id_performed,
            trip_stop_sequence,
            scheduled_stop_sequence,
            stop_id,
            actual_arrival_time,
            pattern_id,
            vehicle_id,
            departure_load,
            boarding_1,
            boarding_2,
            alighting_1,
            alighting_2
        from {{ ref('fct_tides_stop_visits_realtime') }}
        where service_date = current_date
    {% endif %}
),

-- compute ridership quality metrics checks
-- 1) Prepare stop-level totals and cumulative boarding/alighting
stop_level as (
    select
        service_date,
        trip_id_performed,
        trip_stop_sequence,
        scheduled_stop_sequence,
        stop_id,
        actual_arrival_time,
        pattern_id,
        vehicle_id,
        departure_load,
        boarding_1 + boarding_2 as boardings,
        alighting_1 + alighting_2 as alightings,

        sum(boarding_1 + boarding_2) over (
            partition by service_date, trip_id_performed
            order by trip_stop_sequence, actual_arrival_time
            rows between unbounded preceding and current row
        ) as cum_boardings,

        sum(alighting_1 + alighting_2) over (
            partition by service_date, trip_id_performed
            order by trip_stop_sequence, actual_arrival_time
            rows between unbounded preceding and current row
        ) as cum_alightings

    from stop_visits
),

-- 2) Tag first/last stop on each trip
stop_level_ranked as (
    select
        *,
        row_number() over (
            partition by service_date, trip_id_performed
            order by trip_stop_sequence, actual_arrival_time
        ) as rn_first,
        row_number() over (
            partition by service_date, trip_id_performed
            order by trip_stop_sequence desc, actual_arrival_time desc
        ) as rn_last
    from stop_level
),

-- 3) Trip-level quality metrics
trip_level_agg as (
    select
        service_date,
        trip_id_performed,
        any_value(pattern_id) as pattern_id,
        any_value(vehicle_id) as vehicle_id,
        sum(boardings) as boardings,
        sum(alightings) as alightings,
        max(trip_stop_sequence) as max_trip_stop_sequence,
        max(scheduled_stop_sequence) as max_scheduled_stop_sequence,
        max(case when rn_first = 1 and departure_load <> 0 then 1 else 0 end) = 1
            as has_first_stop_load_not_zero,

        max(case when rn_last = 1 and departure_load <> 0 then 1 else 0 end) = 1
            as has_last_stop_load_not_zero,

        max(case when departure_load < 0 then 1 else 0 end) = 1
            as has_negative_load,
        sum(case when departure_load < 0 then 1 else 0 end)
            as count_negative_load_stops,

        max(case
            when departure_load <> (cum_boardings - cum_alightings)
                then 1
            else 0
        end) = 1 as has_load_mismatch,

        sum(case
            when departure_load <> (cum_boardings - cum_alightings)
                then 1
            else 0
        end) as count_load_mismatch_stops

    from stop_level_ranked
    group by
        service_date,
        trip_id_performed
    order by
        service_date,
        trip_id_performed
),

--other metrics comparing on/offs and number of stops completed
metric_trip_ridership as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'trip_id_performed']) }} as _key,
        service_date,
        trip_id_performed,
        pattern_id,
        vehicle_id,
        boardings,
        alightings,
        max_trip_stop_sequence,
        max_scheduled_stop_sequence,
        has_first_stop_load_not_zero,
        has_last_stop_load_not_zero,
        has_negative_load,
        count_negative_load_stops,
        has_load_mismatch,
        count_load_mismatch_stops,
        round(boardings / case when alightings <> 0 then alightings else 1 end, 2) as on_off_ratio,
        round(max_trip_stop_sequence / max_scheduled_stop_sequence, 2) as proportion_stops_served

    from trip_level_agg
)

select * from metric_trip_ridership
