with source as (
    select *
    from {{ source('vendor_2', 'micropay_dev_txns') }}

),

stg_vendor_2_micropay_dev_txns as (
    select
        vendor_2_transaction_id,
        micropayment_id,
        participant_id,
        record_updated_timestamp_utc,
        channel,
        infile_name
    from source
)

select * from stg_vendor_2_micropay_dev_txns