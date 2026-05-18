with source as (
    select *
    from {{ source('vendor_2', 'connections') }}

),

stg_vendor_2_connections as (
    select
        connection_id,
        from_trip_id,
        to_trip_id,
        journey_id,
        participant_id,
        record_updated_timestamp_utc,
        channel,
        infile_name
    from source
)

select * from stg_vendor_2_connections