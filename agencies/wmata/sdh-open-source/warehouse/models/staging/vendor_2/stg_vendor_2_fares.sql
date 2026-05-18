with source as (
    select *
    from {{ source('vendor_2', 'fares') }}

),

stg_vendor_2_fares as (
    select
        trip_id,
        boarded_vendor_2_txn_id,
        alighted_vendor_2_txn_id,
        currency_code,
        fare_amount,
        adjustment_amount,
        adjustment_description,
        trip_processed_timestamp_utc,
        service_name,
        journey_id,
        participant_id,
        record_updated_timestamp_utc,
        channel,
        infile_name
    from source
)

select * from stg_vendor_2_fares