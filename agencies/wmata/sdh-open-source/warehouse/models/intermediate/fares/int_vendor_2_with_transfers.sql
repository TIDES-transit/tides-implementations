with fares as (
    select * from {{ ref('stg_vendor_2_fares') }}
),

transfers as (
    select * from {{ ref('stg_vendor_2_transfers') }}
),

connections as (
    select * from {{ ref('stg_vendor_2_connections') }}
),

dev_txns as (
    select * from {{ ref('stg_vendor_2_dev_txns') }}
),

-- addresses pattern of multiple dev_txns per vendor_2_transaction_id
-- by deduping and prioritising rows with location_name
deduped_dev_txns as (
    select * from (
        select
            *,
            row_number() over (
                partition by vendor_2_transaction_id
                order by
                    case when location_name != '' then 0 else 1 end,
                    case when location_name is not null then 0 else 1 end,
                    case when location_id is not null then 0 else 1 end,
                    case when device_id is not null then 0 else 1 end,
                    case when lp_type is not null then 0 else 1 end,
                    record_updated_timestamp_utc desc
            ) as rn
        from dev_txns
    )
    where rn = 1
),

-- Expand fares to individual transaction level via boarded/alighted txn ids
fare_transactions as (
    -- Boarded transactions
    select
        journey_id,
        trip_id,
        service_name,
        fare_amount,
        adjustment_amount,
        adjustment_description,
        trip_processed_timestamp_utc,
        boarded_vendor_2_txn_id as vendor_2_transaction_id,
        'boarded' as transaction_role,
        participant_id,
        currency_code
    from fares
    where boarded_vendor_2_txn_id is not null

    union all

    -- Alighted transactions
    select
        journey_id,
        trip_id,
        service_name,
        fare_amount,
        adjustment_amount,
        adjustment_description,
        trip_processed_timestamp_utc,
        alighted_vendor_2_txn_id as vendor_2_transaction_id,
        'alighted' as transaction_role,
        participant_id,
        currency_code
    from fares
    where alighted_vendor_2_txn_id is not null
),

-- Join with transfers and connections - dedupe with priority
transfers_connections_ranked as (
    select
        fare_transactions.*,
        transfers.transfer_id,
        transfers.from_service_name as transfer_from_service,
        transfers.to_service_name as transfer_to_service,
        connections.connection_id,
        case
            when transfers.from_trip_id = fare_transactions.trip_id then 'from_trip'
            when transfers.to_trip_id = fare_transactions.trip_id then 'to_trip'
        end as transfer_trip_role,
        case
            when connections.from_trip_id = fare_transactions.trip_id then 'from_trip'
            when connections.to_trip_id = fare_transactions.trip_id then 'to_trip'
        end as connection_trip_role,
        transfers.transfer_id is not null as has_transfer,
        connections.connection_id is not null as has_connection,
        -- Priority: prefer to_trip over from_trip for transfers
        row_number() over (
            partition by fare_transactions.vendor_2_transaction_id
            order by
                case when transfers.to_trip_id = fare_transactions.trip_id then 0 else 1 end,
                transfers.transfer_id
        ) as transfer_priority
    from fare_transactions
    left join transfers
        on
            fare_transactions.journey_id = transfers.journey_id
            and (fare_transactions.trip_id = transfers.from_trip_id or fare_transactions.trip_id = transfers.to_trip_id)
    left join connections
        on
            fare_transactions.journey_id = connections.journey_id
            and (
                fare_transactions.trip_id = connections.from_trip_id
                or fare_transactions.trip_id = connections.to_trip_id
            )
),

-- Filter first, then exclude (Trino's exclude_columns doesn't support subqueries)
trip_transfer_connections_filtered as (
    select *
    from transfers_connections_ranked
    where transfer_priority = 1
),

trip_transfer_connections as (
    {{ select_except('trip_transfer_connections_filtered', ['transfer_priority']) }}
),

-- join with dev_txns
int_vendor_2_with_transfers as (
    select
        -- Transaction identifiers
        trip_transfer_connections.vendor_2_transaction_id,
        trip_transfer_connections.journey_id,
        trip_transfer_connections.trip_id,

        -- transaction details from dev_txns
        deduped_dev_txns.transaction_timestamp_utc,
        deduped_dev_txns.location_id,
        deduped_dev_txns.location_name,
        deduped_dev_txns.lp_type as transaction_type,
        deduped_dev_txns.vehicle_id,
        deduped_dev_txns.device_id,
        deduped_dev_txns.route_id,

        -- cols from fares
        trip_transfer_connections.service_name,
        trip_transfer_connections.fare_amount,
        trip_transfer_connections.adjustment_amount,
        trip_transfer_connections.adjustment_description,
        trip_transfer_connections.trip_processed_timestamp_utc,
        trip_transfer_connections.transaction_role, -- boarded/alighted
        trip_transfer_connections.currency_code,

        -- Transfer details
        trip_transfer_connections.transfer_id,
        trip_transfer_connections.transfer_from_service,
        trip_transfer_connections.transfer_to_service,
        trip_transfer_connections.transfer_trip_role,
        trip_transfer_connections.has_transfer,

        -- Connection details
        trip_transfer_connections.connection_id,
        trip_transfer_connections.connection_trip_role,
        trip_transfer_connections.has_connection,

        -- Fare action derived from transaction type and transfer status
        case
            when
                (trip_transfer_connections.has_transfer or trip_transfer_connections.has_connection)
                and deduped_dev_txns.lp_type = 'ON'
                then 'Transfer entrance'
            when
                (trip_transfer_connections.has_transfer or trip_transfer_connections.has_connection)
                and deduped_dev_txns.lp_type = 'OFF'
                then 'Transfer exit'
            when deduped_dev_txns.lp_type in ('ON', 'SINGLE') then 'Enter'
            when deduped_dev_txns.lp_type = 'OFF' then 'Exit'
        end as fare_action,
        trip_transfer_connections.adjustment_amount != 0 as has_adjustment,
        {{ date_add(utc_to_timezone('transaction_timestamp_utc', 'America/New_York'), '-4', 'HOUR', 'DAY') }}
            as service_date

    from trip_transfer_connections
    inner join deduped_dev_txns
        on trip_transfer_connections.vendor_2_transaction_id = deduped_dev_txns.vendor_2_transaction_id
)

select * from int_vendor_2_with_transfers