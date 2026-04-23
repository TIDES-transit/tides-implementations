-- Monitors stop_id_imputed NULL rate for in-service Scheduled/Skipped records (Path 1).
-- These records go through spatial imputation and should almost always get a match.
-- Returns service_dates where the in-service null rate exceeds 5%.
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

with path1_in_service_stats as (
    select
        service_date,
        count(*) as total_records,
        count(stop_id_imputed) as imputed_records,
        count(*) - count(stop_id_imputed) as null_records
    from {{ ref('int_tides_vehicle_locations_bus_info_stop_id') }}
    where
        schedule_relationship in ('Scheduled', 'Skipped')
        and trip_type = 'In service'
    group by service_date
),

test_stop_id_imputed_null_rate_scheduled as (
    select
        service_date,
        total_records,
        null_records,
        round(100.0 * null_records / total_records, 2) as pct_null
    from path1_in_service_stats
    where
        null_records > 0
        and (1.0 * null_records / total_records) > 0.05
)

select * from test_stop_id_imputed_null_rate_scheduled