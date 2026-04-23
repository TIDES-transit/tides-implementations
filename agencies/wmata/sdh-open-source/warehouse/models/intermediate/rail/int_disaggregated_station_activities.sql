{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

/*
This model combines passenger events from faregates and fare transactions to create a
comprehensive dataset of rail station activity.

Fare transactions use numeric mezzanine IDs (FARE stop_point_id, vendor_2 location_id)
which are mapped to GTFS station codes via the rail_mezzanine_to_station seed before
joining to GTFS rail stops. faregate_data faregate events already use GTFS-compatible station codes.

It adds flags for entry events, exit events, and transactions to enable aggregation
in the mart model. The hour is extracted from the timestamp to support hourly aggregation.
*/

with rail_feed as (
    select
        service_date,
        _feed_hash
    from {{ ref('fct_daily_schedule_feed_modes') }}
    where feed_mode = 'Rail'
),

int_gtfs_rail_stops as (
    select * from {{ ref('int_gtfs_rail_stops') }}
),

rail_stops as (
    select
        rail_feed.service_date,
        int_gtfs_rail_stops.stop_id
    from rail_feed
    inner join int_gtfs_rail_stops
        on rail_feed._feed_hash = int_gtfs_rail_stops._feed_hash
),

fct_tides_passenger_events_faregates as (
    select * from {{ ref('fct_tides_passenger_events_faregates') }}
),

fct_tides_fare_transactions as (
    select * from {{ ref('fct_tides_fare_transactions') }}
),

rail_mezzanine_to_station as (
    select * from {{ ref('rail_mezzanine_to_station') }}
),

passenger_events as (
    select
        service_date,
        event_timestamp,
        stop_id,
        event_type,
        rider_category,
        {{ flex_cast("null", "varchar") }} as fare_product,
        {{ flex_cast("null", "varchar") }} as token_id,
        extract(hour from event_timestamp) as hour_of_day,
        coalesce(event_type = 'Passenger entry', false) as is_entry,
        coalesce(event_type = 'Passenger exit', false) as is_exit,
        false as is_entry_transaction,
        false as is_exit_transaction,
        source_system
    from
        fct_tides_passenger_events_faregates
    where
        stop_id is not null
        -- filter to include only rail station events
        -- as all events from faregate_data_ORGN source are from faregates (which are only at rail stations)
        and source_system = 'faregate_data_ORGN'
),

fare_transactions as (
    select
        fct_tides_fare_transactions.service_date,
        fct_tides_fare_transactions.event_timestamp,
        rail_mezzanine_to_station.station_code as stop_id,
        fct_tides_fare_transactions.fare_action as event_type,
        fct_tides_fare_transactions.rider_category,
        fct_tides_fare_transactions.fare_product,
        fct_tides_fare_transactions.token_id,
        extract(hour from fct_tides_fare_transactions.event_timestamp) as hour_of_day,
        false as is_entry,
        false as is_exit,
        coalesce(
            fct_tides_fare_transactions.fare_action in ('Enter', 'Transfer entrance'), false
        ) as is_entry_transaction,
        coalesce(
            fct_tides_fare_transactions.fare_action in ('Exit', 'Transfer exit'), false
        ) as is_exit_transaction,
        fct_tides_fare_transactions.source_system
    from
        fct_tides_fare_transactions
    inner join
        rail_mezzanine_to_station
        on
            fct_tides_fare_transactions.stop_id
            = {{ flex_cast('rail_mezzanine_to_station.mezzanine_id', 'varchar') }}
    inner join
        rail_stops
        on
            fct_tides_fare_transactions.service_date = rail_stops.service_date
            and rail_mezzanine_to_station.station_code = rail_stops.stop_id
    where
        fct_tides_fare_transactions.stop_id is not null
),

combined_events as (
    select * from passenger_events
    union all
    select * from fare_transactions
),

int_disaggregated_station_activities as (
    select
        service_date,
        event_timestamp,
        stop_id,
        event_type,
        rider_category,
        fare_product,
        token_id,
        hour_of_day,
        is_entry,
        is_exit,
        is_entry_transaction,
        is_exit_transaction,
        source_system,
        {{ dbt_utils.generate_surrogate_key([
            'service_date', 'stop_id', 'event_timestamp', 'event_type', 'source_system'
        ]) }}
            as _key
    from
        combined_events
)

select * from int_disaggregated_station_activities