-- Test that each stop_code has only one stop_id within a given feed
-- This ensures stop_id from bus info (which matches GTFS stop_code)
-- can be matched to gtfs and to return a single GTFS stop_id back to vehicle locations.
-- per GTFS spec, stop_code doesn't need to be unique like stop_id
-- if this fails, we're duplicating records in vehicle_locations, but for now,
-- we just warn.

{{ config(severity='warn') }}

with stop_code_mappings as (
    select
        _feed_hash,
        stop_code,
        count(distinct stop_id) as distinct_stop_ids
    from {{ ref('dim_stops') }}
    where stop_code is not null
    group by 1, 2
),

test_dim_stops_stop_code_unique_stop_id_per_feed as (
    select *
    from stop_code_mappings
    where distinct_stop_ids > 1
)

select * from test_dim_stops_stop_code_unique_stop_id_per_feed