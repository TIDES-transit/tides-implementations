{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

{#
  GTFS models use event_time=_date_retrieved (the feed download date), but this model
  batches by service_date. dbt's microbatch auto-filtering would restrict GTFS refs to
  _date_retrieved within the service_date batch window, which is wrong — a service_date's
  GTFS data comes from a feed that may have been downloaded on a completely different date.
  Use .render() to opt out of auto-filtering per dbt docs.
#}

-- model imputes stop_id from gtfs schedule data for trips that will be included in stop_visits
-- to do this it calculates a weighted_distance from the lat/long in the vehicle_locations
-- to the stops in the gtfs data and finds the closest stop w/ the a logical stop_sequence

with
int_locations as (
    select * from {{ ref("int_tides_vehicle_locations_bus_info") }}
),

fct_daily_feeds as (
    select
        _feed_hash,
        service_date
    from
        {{ ref("fct_daily_schedule_feed_modes") }}
    where
        feed_mode = 'Bus'
),

dim_stops as (
    select
        _feed_hash,
        stop_id,
        stop_code
    from
        {{ ref("dim_stops").render() }}
),

fct_schd_stops as (
    select
        service_date,
        stop_sequence,
        stop_lat,
        stop_lon,
        stop_id,
        trip_id
    from
        {{ ref("fct_scheduled_stop_times").render() }}
),

int_tides_vehicle_locations_bus_info_base as (
    select
        int_locations.location_ping_id,
        int_locations.service_date,
        int_locations.event_timestamp,
        int_locations.trip_id_performed,
        int_locations.trip_id_scheduled,
        int_locations.trip_stop_sequence,
        int_locations.scheduled_stop_sequence,
        int_locations.vehicle_id,
        int_locations.device_id,
        int_locations.pattern_id,
        dim_stops.stop_id,
        int_locations.latitude,
        int_locations.longitude,
        int_locations.gps_quality,
        int_locations.heading,
        int_locations.speed,
        int_locations.odometer,
        int_locations.schedule_deviation,
        int_locations.headway_deviation,
        int_locations.trip_type,
        int_locations.current_status,
        int_locations.schedule_relationship
    from int_locations
    left join fct_daily_feeds
        on int_locations.service_date = fct_daily_feeds.service_date
    left join dim_stops
        on
            fct_daily_feeds._feed_hash = dim_stops._feed_hash
            and int_locations.stop_id = dim_stops.stop_code
),

-- First compute distance_meters (Trino doesn't allow referencing aliases in same SELECT)
int_stops_distance_base as (
    select
        bs_base.*,
        fct_schd_stops.stop_lat,
        fct_schd_stops.stop_lon,
        fct_schd_stops.stop_id as stop_id_imputed,
        fct_schd_stops.stop_sequence as schd_stop_sequence,
        {{ haversine_distance_meters(
            'bs_base.latitude',
            'bs_base.longitude',
            'fct_schd_stops.stop_lat',
            'fct_schd_stops.stop_lon'
        ) }} as distance_meters
    from
        (
            select * from int_tides_vehicle_locations_bus_info_base
            -- for locations that will be stop visits
            -- not including "Added" or "Missing" bc they will likely not
            -- have matches with gtfs schedule
            where schedule_relationship in ('Skipped', 'Scheduled')
        ) as bs_base
    left join fct_schd_stops
        on
            bs_base.service_date = fct_schd_stops.service_date
            and bs_base.trip_id_scheduled = fct_schd_stops.trip_id
            and {{ bounding_box_filter(
                'bs_base.latitude',
                'bs_base.longitude',
                'fct_schd_stops.stop_lat',
                'fct_schd_stops.stop_lon',
                radius_meters = 300
            ) }}
),

-- Then compute weighted_distance and rank
int_stops_distance as (
    select
        *,
        abs(coalesce(trip_stop_sequence, 0) - coalesce(schd_stop_sequence, 0))
        + 1 as sequence_diff_mult,
        distance_meters * (
            abs(coalesce(trip_stop_sequence, 0) - coalesce(schd_stop_sequence, 0)) + 1)
            as weighted_distance
    from int_stops_distance_base
),

int_stops_distance_ranked as (
    select
        *,
        row_number()
            over (
                partition by
                    location_ping_id
                order by
                    weighted_distance,
                    sequence_diff_mult
            )
            as rn
    from int_stops_distance
),

int_stops_distance_filtered as (
    select
        location_ping_id,
        service_date,
        event_timestamp,
        trip_id_performed,
        trip_id_scheduled,
        trip_stop_sequence,
        scheduled_stop_sequence,
        vehicle_id,
        device_id,
        pattern_id,
        stop_id,
        latitude,
        longitude,
        gps_quality,
        heading,
        speed,
        odometer,
        schedule_deviation,
        headway_deviation,
        trip_type,
        current_status,
        schedule_relationship,
        stop_id_imputed
    from int_stops_distance_ranked
    where rn = 1
),

-- bringing back in the vehicle locations data where schedule_relationship is not in ('Skipped', 'Scheduled')
int_tides_vehicle_locations_bus_info_stop_id as (
    select
        *,
        stop_id as stop_id_imputed
    from int_tides_vehicle_locations_bus_info_base
    where
        not schedule_relationship in ('Skipped', 'Scheduled')
        or schedule_relationship is null
    union all
    select *
    from int_stops_distance_filtered
)

select * from int_tides_vehicle_locations_bus_info_stop_id