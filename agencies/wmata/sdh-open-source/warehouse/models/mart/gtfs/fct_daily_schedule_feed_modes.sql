with dim_dates as (
    select *
    from {{ ref('dim_dates') }}
),

dim_schedule_feeds as (
    select *
    from {{ ref('dim_schedule_feeds') }}
),

dim_trips as (
    select
        _feed_hash,
        route_id,
        service_id
    from {{ ref('dim_trips') }}
),

dim_routes as (
    select
        _feed_hash,
        route_id,
        route_type
    from {{ ref('dim_routes') }}
),

daily_services as (
    select
        service_date,
        _feed_hash,
        service_id
    from {{ ref('int_gtfs_daily_services') }}
),

modes as (
    select
        'Combined' as feed_type,
        'Bus' as feed_mode
    union all
    select
        'Combined' as feed_type,
        'Rail' as feed_mode
),

-- Expand Combined feeds into separate Bus and Rail rows
expanded_feeds as (
    select
        dim_schedule_feeds.*,
        coalesce(modes.feed_mode, dim_schedule_feeds._feed_type) as feed_mode
    from dim_schedule_feeds
    left join modes on dim_schedule_feeds._feed_type = modes.feed_type
),

-- Identify which (feed_hash, service_id) combinations have trips of each mode
trip_service_modes as (
    select distinct
        dim_trips._feed_hash,
        dim_trips.service_id,
        case
            when dim_routes.route_type = 1 then 'Rail'
            when dim_routes.route_type = 3 then 'Bus'
        end as trip_mode
    from dim_trips
    inner join dim_routes
        on
            dim_trips._feed_hash = dim_routes._feed_hash
            and dim_trips.route_id = dim_routes.route_id
    where dim_routes.route_type in (1, 3)
),

-- For each (feed_hash, mode), find the earliest date with active service for that mode
mode_first_service_dates as (
    select
        trip_service_modes._feed_hash,
        trip_service_modes.trip_mode as feed_mode,
        min(daily_services.service_date) as mode_first_service_date
    from trip_service_modes
    inner join daily_services
        on
            trip_service_modes._feed_hash = daily_services._feed_hash
            and trip_service_modes.service_id = daily_services.service_id
    group by 1, 2
),

-- INNER JOIN excludes feed/mode combos with zero trips for that mode
-- (e.g., zombie calendar entries like anyday_service_R with no actual trips)
feeds_with_mode_start as (
    select
        expanded_feeds.*,
        mode_first_service_dates.mode_first_service_date,
        greatest(
            expanded_feeds._valid_from,
            mode_first_service_dates.mode_first_service_date
        ) as mode_effective_from
    from expanded_feeds
    inner join mode_first_service_dates
        on
            expanded_feeds._feed_hash = mode_first_service_dates._feed_hash
            and expanded_feeds.feed_mode = mode_first_service_dates.feed_mode
),

-- A feed remains valid for a mode until the NEXT feed can actually serve that mode
feeds_with_mode_validity as (
    select
        *,
        coalesce(
            lead(mode_effective_from) over (
                partition by feed_mode
                order by _date_retrieved, _feed_hash
            ),
            _valid_to
        ) as mode_valid_to
    from feeds_with_mode_start
),

valid_feeds as (
    select
        dim_dates.service_date,
        feeds_with_mode_validity._feed_hash,
        feeds_with_mode_validity.feed_mode,
        feeds_with_mode_validity._feed_type,
        feeds_with_mode_validity._source,
        feeds_with_mode_validity._date_retrieved,
        feeds_with_mode_validity.feed_start_date,
        feeds_with_mode_validity.feed_end_date,
        feeds_with_mode_validity.feed_version,
        feeds_with_mode_validity._valid_from,
        feeds_with_mode_validity._valid_to
    from dim_dates
    left join feeds_with_mode_validity
        on
            dim_dates.service_date
            between feeds_with_mode_validity.mode_effective_from
            and feeds_with_mode_validity.mode_valid_to
    where
        -- Feed must be retrieved before or at noon on the service date.
        feeds_with_mode_validity._date_retrieved <= {{ date_add('service_date', 12, 'HOUR', 'HOUR') }}
),

-- Rank feeds by recency for each service_date/feed_mode combination
-- Tie-breaking: most recent date_retrieved, then most recent _valid_from, then latest _valid_to
ranked_feeds as (
    select
        service_date,
        feed_mode,
        _feed_hash,
        _feed_type,
        _date_retrieved,
        _valid_from,
        _valid_to,
        row_number() over (
            partition by service_date, feed_mode
            order by
                _date_retrieved desc,
                _valid_from desc,
                _valid_to desc,
                _feed_hash desc
        ) as feed_rank
    from valid_feeds
),

-- Select only the most recent applicable feed for each service_date/feed_mode
fct_daily_schedule_feed_modes as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'feed_mode']) }} as _key,
        service_date,
        feed_mode,
        _feed_hash,
        _feed_type as feed_type
    from ranked_feeds
    where feed_rank = 1
)

select * from fct_daily_schedule_feed_modes
