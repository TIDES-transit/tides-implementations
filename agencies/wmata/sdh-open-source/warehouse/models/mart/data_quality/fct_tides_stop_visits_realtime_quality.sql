{{ config(enabled=var('enable_realtime', false)) }}

with int_tides_stop_visits_realtime as (
    select * from {{ ref('int_tides_stop_visits_realtime') }}
),

fct_tides_stop_visits_realtime_quality as (
    select
        *,
        -- TODO: Add quality checks for realtime stop visits, such as:
        -- - Validate stop_id exists in GTFS stops
        -- - reasonable boarding/alighting counts
        -- - valid trip ID (after imputation)
        -- - Check pattern_id format and validity
        -- - Reasonable and non-null actual departure and arrival times
        -- - Check for duplicate stop visits within same trip
        -- -    (currently not possible but may change when upstream logic for is_stop_visit is improved)
        -- - Validate passenger count consistency
        true as is_valid -- TODO: rename to _is_valid (non-TIDES)
    from int_tides_stop_visits_realtime
)

select * from fct_tides_stop_visits_realtime_quality
