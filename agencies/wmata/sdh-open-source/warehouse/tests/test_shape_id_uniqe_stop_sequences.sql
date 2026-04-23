--  Test to ensure that each shape_id has only one unique stop pattern.
-- If a shape_id is associated with multiple different stop sequences,
-- this indicates a data quality issue where the same shapes linestring
-- is being used for trips with different stop patterns.

-- Returns rows where shape_id has multiple stop patterns

{{ config(
    severity='warn',
    meta={
        'dagster': {
            'ref': {
                'name': 'dim_stop_times',
                'package': 'warehouse'
            }
        }
    }
) }}

with dim_stop_times as (
    select
        _feed_hash,
        trip_id,
        stop_sequence,
        stop_id
    from {{ ref('dim_stop_times') }}

),

dim_trips as (
    select
        _feed_hash,
        trip_id,
        route_id,
        shape_id
    from {{ ref('dim_trips') }}
),

agged_patterns as (
    select
        _feed_hash,
        trip_id,
        {{ agg_array_to_string(agg_col='stop_id', separator=',', order_col='stop_sequence') }} as concatenated_stop_ids
    from dim_stop_times
    group by
        _feed_hash,
        trip_id
),

pattern_details as (
    select
        agged_patterns._feed_hash,
        dim_trips.route_id,
        dim_trips.shape_id,
        agged_patterns.trip_id,
        agged_patterns.concatenated_stop_ids
    from agged_patterns
    left join dim_trips
        on
            agged_patterns._feed_hash = dim_trips._feed_hash
            and agged_patterns.trip_id = dim_trips.trip_id
),

count_trips_patterns as (
    select
        _feed_hash,
        route_id,
        shape_id,
        concatenated_stop_ids,
        count(trip_id) as n_trips
    from pattern_details
    group by
        _feed_hash,
        route_id,
        shape_id,
        concatenated_stop_ids
),

failing_shapes as (
    select
        _feed_hash,
        route_id,
        shape_id,
        count(*) as count_different_stop_patterns,
        -- Include sample patterns for debugging
        {{ agg_array_to_string(agg_col='concatenated_stop_ids', separator=' | ') }} as sample_stop_patterns
    from count_trips_patterns
    group by
        _feed_hash,
        route_id,
        shape_id
    having count(*) > 1
),

test_shape_id_uniqe_stop_sequences as (
    select
        _feed_hash,
        route_id,
        shape_id,
        count_different_stop_patterns,
        sample_stop_patterns
    from failing_shapes
    order by count_different_stop_patterns desc, route_id asc, shape_id asc

)

select * from test_shape_id_uniqe_stop_sequences
