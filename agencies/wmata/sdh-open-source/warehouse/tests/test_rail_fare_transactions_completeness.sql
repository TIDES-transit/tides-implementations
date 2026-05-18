-- Ensures rail fare transactions are not silently dropped by the INNER JOIN
-- to GTFS rail stops in int_disaggregated_station_activities.
-- Compares rail-related fare transactions (Enter/Exit/Transfer) in
-- fct_tides_fare_transactions to what survives into station activities.
-- Flags dates where >5% of rail fare transactions are lost.
{{ config(
    severity='warn',
    meta={
        'dagster': {
            'ref': {
                'name': 'int_disaggregated_station_activities',
                'package': 'warehouse'
            }
        }
    }
) }}

with rail_fare_actions as (
    select
        service_date,
        count(*) as upstream_count
    from {{ ref('fct_tides_fare_transactions') }}
    where
        stop_id is not null
        and fare_action in ('Enter', 'Exit', 'Transfer entrance', 'Transfer exit')
    group by service_date
),

station_activity_transactions as (
    select
        service_date,
        count(*) as downstream_count
    from {{ ref('int_disaggregated_station_activities') }}
    where
        source_system != 'faregate_data_ORGN'
    group by service_date
),

compared as (
    select
        rail_fare_actions.service_date,
        rail_fare_actions.upstream_count,
        coalesce(station_activity_transactions.downstream_count, 0) as downstream_count,
        rail_fare_actions.upstream_count
        - coalesce(station_activity_transactions.downstream_count, 0) as lost_count
    from rail_fare_actions
    left join station_activity_transactions
        on rail_fare_actions.service_date = station_activity_transactions.service_date
),

test_rail_fare_transactions_completeness as (
    select
        service_date,
        upstream_count,
        downstream_count,
        lost_count,
        round(100.0 * lost_count / upstream_count, 2) as pct_lost
    from compared
    where
        lost_count > 0
        and (1.0 * lost_count / upstream_count) > 0.05
)

select * from test_rail_fare_transactions_completeness