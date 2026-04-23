with source as (
    select *
    from {{ source('vendor_2', 'dev_txn_purchases') }}

),

stg_vendor_2_dev_txn_purchases as (
    select
        participant_id,
        channel,
        correlated_purchase_id,
        description as lp_description,
        indicative_amount,
        infile_name,
        vendor_2_transaction_id,
        product_id,
        purchase_id,
        record_updated_timestamp_utc,
        transaction_timestamp_utc
    from source
)

select * from stg_vendor_2_dev_txn_purchases