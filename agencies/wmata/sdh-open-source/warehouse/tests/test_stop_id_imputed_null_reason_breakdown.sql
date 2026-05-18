-- Breaks down why stop_id_imputed is NULL for Scheduled/Skipped records,
-- cross-classified by trip_type to separate actionable issues (In service)
-- from expected nulls (Pullins, Deadheads, etc.).
-- Only flags dates where in-service nulls exceed 5% of Path 1 records.
{{ config(
    severity='warn',
    meta={
        'dagster': {
            'ref': {
                'name': 'int_tides_vehicle_locations_bus_info_stop_id',
                'package': 'warehouse'
            }
        }
    }
) }}

with path1_totals as (
    select
        service_date,
        count(*) as total_path1_records
    from {{ ref('int_tides_vehicle_locations_bus_info_stop_id') }}
    where schedule_relationship in ('Scheduled', 'Skipped')
    group by service_date
),

null_path1 as (
    select
        service_date,
        trip_id_scheduled,
        trip_type,
        latitude,
        longitude
    from {{ ref('int_tides_vehicle_locations_bus_info_stop_id') }}
    where
        schedule_relationship in ('Scheduled', 'Skipped')
        and stop_id_imputed is null
),

gtfs_trips as (
    select distinct
        service_date,
        trip_id
    from {{ ref('fct_scheduled_stop_times') }}
),

classified as (
    select
        null_path1.service_date,
        null_path1.trip_type = 'In service' as is_in_service,
        case
            when null_path1.latitude is null or null_path1.longitude is null
                then 'null_coordinates'
            when null_path1.trip_id_scheduled is null
                then 'null_trip_id'
            when gtfs_trips.trip_id is null
                then 'trip_not_in_gtfs'
            else 'no_stop_within_300m'
        end as null_reason
    from null_path1
    left join gtfs_trips
        on
            null_path1.service_date = gtfs_trips.service_date
            and null_path1.trip_id_scheduled = gtfs_trips.trip_id
),

in_service_null_rates as (
    select
        classified.service_date,
        path1_totals.total_path1_records,
        sum(
            case when classified.is_in_service then 1 else 0 end
        ) as in_service_null_count
    from classified
    inner join path1_totals
        on classified.service_date = path1_totals.service_date
    group by classified.service_date, path1_totals.total_path1_records
),

flagged_dates as (
    select service_date
    from in_service_null_rates
    where
        (1.0 * in_service_null_count / total_path1_records) > 0.05
),

test_stop_id_imputed_null_reason_breakdown as (
    select
        classified.service_date,
        classified.null_reason,
        classified.is_in_service,
        path1_totals.total_path1_records,
        count(*) as record_count,
        round(
            100.0 * count(*) / path1_totals.total_path1_records, 2
        ) as pct_of_path1
    from classified
    inner join path1_totals
        on classified.service_date = path1_totals.service_date
    inner join flagged_dates
        on classified.service_date = flagged_dates.service_date
    group by
        classified.service_date,
        classified.null_reason,
        classified.is_in_service,
        path1_totals.total_path1_records
)

select * from test_stop_id_imputed_null_reason_breakdown