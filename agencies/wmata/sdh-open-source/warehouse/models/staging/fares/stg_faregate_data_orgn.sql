with source as (
    select *
    from {{ source('faregate_data', 'faregate_data_orgn') }}

),

stg_faregate_data_orgn as (

    select
        rowid as _row_id,
        trxn_dtime,
        {{ date_add(flex_cast('trxn_dtime', 'timestamp'), '-4', 'HOUR', 'DAY') }} as service_date,
        mezz_id,
        eqmt_type_id,
        eqmt_id,
        trxn_type_cd,
        trxn_sno,
        stn_id,
        cid_id,
        cid_ser_num,
        trxn_utc_dtime,
        csc_mfg_id,
        rider_cls_cd,
        ppt_loc,
        trxn_stat_cd,
        fare_inst_id,
        rider_remain_cnt,
        sv_trxn_val,
        sv_remain_val,
        trxn_cd,
        oper_stat_result_cd,
        last_use_dtime,
        last_use_loc_cd,
        occur_dtime,
        msg_type_cd,
        msg_sno,
        reg_dtime,
        reg_usr_id,
        upd_dtime,
        upd_usr_id,
        csc_sno,
        trxn_no,
        alpo_use_val,
        prod_use_load,
        inserted_dtm,
        fare_table_id,
        eis_num,
        csc_num
    from source
)

select * from stg_faregate_data_orgn