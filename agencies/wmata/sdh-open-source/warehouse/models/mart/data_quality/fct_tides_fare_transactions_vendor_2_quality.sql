{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with int_tides_fare_transactions as (
    select
        *,
        {{ dbt_utils.generate_surrogate_key(['event_timestamp', 'device_id']) }} as row_hash --noqa
    from {{ ref('int_tides_fare_transactions_vendor_2') }}
),

dupes as (
    select
        row_hash,
        count(*) > 1 as has_dup,
        min(transaction_id) as first_instance
    from int_tides_fare_transactions
    group by row_hash
),

micropayments as (
    select
        micropayment_id,
        charge_type,
        count(case when fare_action in ('Enter', 'Transfer entrance') then 1 end) as entry_count,
        count(case when fare_action in ('Exit', 'Transfer exit') then 1 end) as exit_count
    from int_tides_fare_transactions
    where charge_type = 'complete_variable_fare'
    group by micropayment_id, charge_type
),

check_balanced as (
    select
        micropayment_id,
        charge_type,
        entry_count,
        exit_count,
        -- More than one entry and exit (expected is one per micropayment)
        coalesce(entry_count > 1, false) as has_multiple_entries,
        coalesce(exit_count > 1, false) as has_multiple_exits,
        -- Missing entry or exit record
        coalesce(entry_count = 0, false) as has_no_entry,
        coalesce(exit_count = 0, false) as has_no_exit,
        -- Overall balance check - should have exactly 1 entry and 1 exit
        not coalesce(entry_count = 1 and exit_count = 1, false) as is_unbalanced_complete_variable_fare
    from micropayments
),

fct_tides_fare_transactions_vendor_2_quality as (
    select
        int_tides_fare_transactions.transaction_id,
        int_tides_fare_transactions.service_date,
        int_tides_fare_transactions.event_timestamp,
        int_tides_fare_transactions.location_ping_id,
        int_tides_fare_transactions.amount,
        int_tides_fare_transactions.currency_type,
        int_tides_fare_transactions.fare_action,
        int_tides_fare_transactions.trip_id_performed,
        int_tides_fare_transactions.trip_id_scheduled,
        int_tides_fare_transactions.pattern_id,
        int_tides_fare_transactions.trip_stop_sequence,
        int_tides_fare_transactions.scheduled_stop_sequence,
        int_tides_fare_transactions.vehicle_id,
        int_tides_fare_transactions.device_id,
        int_tides_fare_transactions.fare_id,
        int_tides_fare_transactions.stop_id,
        int_tides_fare_transactions.num_riders,
        int_tides_fare_transactions.fare_media_id,
        int_tides_fare_transactions.rider_category,
        int_tides_fare_transactions.fare_product,
        int_tides_fare_transactions.fare_period,
        int_tides_fare_transactions.fare_capped,
        int_tides_fare_transactions.token_id,
        int_tides_fare_transactions.balance,
        int_tides_fare_transactions.source_system,
        int_tides_fare_transactions.charge_type,
        int_tides_fare_transactions.micropayment_id,
        int_tides_fare_transactions.aggregation_id,
        int_tides_fare_transactions.row_hash,
        -- Quality check columns
        dupes.has_dup as has_duplicates,
        check_balanced.is_unbalanced_complete_variable_fare,
        check_balanced.entry_count,
        check_balanced.exit_count,
        check_balanced.has_multiple_entries,
        check_balanced.has_multiple_exits,
        check_balanced.has_no_entry,
        check_balanced.has_no_exit,
        int_tides_fare_transactions.transaction_id = dupes.first_instance as dup_row_to_keep,
        -- Overall validity check
        (
            -- Keep non-duplicates or first instance of duplicates
            coalesce(int_tides_fare_transactions.transaction_id = dupes.first_instance, true)
            and int_tides_fare_transactions.transaction_id is not null
            and int_tides_fare_transactions.service_date is not null
            and int_tides_fare_transactions.event_timestamp is not null
            and int_tides_fare_transactions.fare_action is not null
            and int_tides_fare_transactions.micropayment_id is not null
            -- Not unbalanced for complete variable fare
            and coalesce(check_balanced.is_unbalanced_complete_variable_fare, false) = false
        ) as is_valid,
        -- Invalid reason - return the first issue found
        case
            when int_tides_fare_transactions.transaction_id is null then 'Missing transaction_id'
            when int_tides_fare_transactions.service_date is null then 'Missing service_date'
            when int_tides_fare_transactions.event_timestamp is null then 'Missing event_timestamp'
            when int_tides_fare_transactions.fare_action is null then 'Missing fare_action'
            when int_tides_fare_transactions.micropayment_id is null then 'Missing micropayment_id'
            when not coalesce(int_tides_fare_transactions.transaction_id = dupes.first_instance, true) then 'Duplicate record' --noqa
            when
                coalesce(check_balanced.has_multiple_entries, false)
                then 'Multiple entry records for complete variable fare'
            when
                coalesce(check_balanced.has_multiple_exits, false)
                then 'Multiple exit records for complete variable fare'
            when coalesce(check_balanced.has_no_entry, false) then 'No entry record for complete variable fare'
            when coalesce(check_balanced.has_no_exit, false) then 'No exit record for complete variable fare'
        end as invalid_reason
    from int_tides_fare_transactions
    left join dupes
        on int_tides_fare_transactions.row_hash = dupes.row_hash
    left join check_balanced
        on int_tides_fare_transactions.micropayment_id = check_balanced.micropayment_id
)

select * from fct_tides_fare_transactions_vendor_2_quality