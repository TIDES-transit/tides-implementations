with source as (
    select *
    from {{ source('vendor_2', 'evt_txn_recv') }}

),

stg_evt_txn_recv as (
    select
        funding_src_id,
        customer_id,
        event_id,
        created_ts,
        db_inserted_ts,
        txn_id,
        device_id,
        device_txn_id,
        txn_ts,
        txn_recv_ts,
        stop_loc_id,
        txn_type,
        txn_outcome

    from source
)

select * from stg_evt_txn_recv