with source as (
    select *
    from {{ source('faregate_data', 'faregate_data_mtn') }}

),

stg_faregate_data_mtn as (

    select
        rowid as _row_id,
        occur_dtime,
        mezz_id,
        eqmt_type_id,
        eqmt_id,
        event_cd,
        msg_sno,
        serial_num,
        event_argmt,
        stn_id,
        event_type_cd,
        msg_type_cd,
        eqmt_send_event_flg,
        reg_dtime,
        reg_usr_id,
        upd_dtime,
        upd_usr_id,
        inserted_dtm,
        alarm_level
    from source

)

select * from stg_faregate_data_mtn