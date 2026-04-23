with stop_times as (
    select * from {{ ref('stg_gtfs_stop_times') }}
),

trips as (
    select * from {{ ref('stg_gtfs_trips') }}
),

patterns as (
    select * from {{ ref('int_gtfs_patterns') }}
),

trip_stop_sequences as (
    select distinct
        trips._feed_hash,
        trips.shape_id,
        stop_times.stop_id,
        stop_times.stop_sequence
    from stop_times
    inner join trips
        on
            stop_times._feed_hash = trips._feed_hash
            and stop_times.trip_id = trips.trip_id
    where trips.shape_id is not null
),

int_gtfs_pattern_stops as (
    select
        {{ dbt_utils.generate_surrogate_key(['patterns._feed_hash',  'patterns.pattern_id', 'trip_stop_sequences.stop_id', 'trip_stop_sequences.stop_sequence']) }} -- noqa
            as _key,
        patterns._feed_hash,
        patterns.pattern_id,
        trip_stop_sequences.stop_id,
        trip_stop_sequences.stop_sequence

    from trip_stop_sequences
    inner join patterns
        on
            trip_stop_sequences._feed_hash = patterns._feed_hash
            and trip_stop_sequences.shape_id = patterns.shape_id
    order by patterns._feed_hash asc, patterns.pattern_id asc, trip_stop_sequences.stop_sequence asc
)

select * from int_gtfs_pattern_stops
