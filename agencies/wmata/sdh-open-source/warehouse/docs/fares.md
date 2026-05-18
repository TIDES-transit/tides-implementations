<!-- faregate_data_MTN -->

{% docs field_occur_dtime %}
Date and time that the event occurred in the equipment. Value: 'YYYY-MM-DDThh:mm:ss'
{% enddocs %}

{% docs field_mezz_id %}the id of the mezzanine that the equipment belongs to. value: mezzanine id ('001', '002', etc???){% enddocs %}

{% docs field_eqmt_type_id %}
The type ID of the equipment which sent its status information. Value: 'RVG', 'SAG'
{% enddocs %}

{% docs field_eqmt_id %}
The ID of the equipment which sent its status information. Value: Equipment ID ('10', '11', etc???)
{% enddocs %}

{% docs field_event_cd %}
The code of the event. Value: Please refer to 4.8.2 Event code in CDRL 2-06_01.System Interface Specification.docx
{% enddocs %}

{% docs field_msg_sno %}
The sequence number of the message. Value: '1' ~ '9999999999'
{% enddocs %}

{% docs field_serial_num %}
Serial number of component. Value: Serial number
{% enddocs %}

{% docs field_event_argmt %}
The argument that the event has. Value: Please refer to 4.8.2 Event code in CDRL 2-06_01.System Interface Specification.docx
{% enddocs %}

{% docs field_stn_id %}
The ID of the station that the equipment belongs to. Value: Station ID ('A01', 'A02', etc???)
{% enddocs %}

{% docs field_event_type_cd %}
The type code of the event data. Value: '01'
{% enddocs %}

{% docs field_msg_type_cd %}
The type code of the message. Value: '32'
{% enddocs %}

{% docs field_eqmt_send_event_flg %}
Indicates whether this row is generated from equipment(FG, ST, or faregate_data) or not. Value: 'Y'= Generated from Equipment(FG,ST,faregate_data), 'N'= Generated manually
{% enddocs %}

{% docs field_reg_dtime %}
Date and time that row is registered initially. Value: 'YYYY-MM-DDThh:mm:ss'
{% enddocs %}

{% docs field_reg_usr_id %}
The user ID that first registered the row. Value: ID of user who performed the action or system ID ('faregate_data', 'STT')
{% enddocs %}

{% docs field_upd_dtime %}
Date and time that the row is updated lastly. Value: 'YYYY-MM-DDThh:mm:ss'
{% enddocs %}

{% docs field_upd_usr_id %}
The user ID that last updated the row. Value: ID of user who performed the action or system ID ('faregate_data', 'STT')
{% enddocs %}

{% docs field_inserted_dtm %}
Pending documentation.
{% enddocs %}

{% docs field_alarm_level %}
Pending documentation.
{% enddocs %}

<!-- faregate_data_ORGN -->

{% docs field_trxn_dtime %}
Date and time that the transaction occurred.  Value: 'YYYY-MM-DDThh:mm:ss'
{% enddocs %}

{% docs field_trxn_type_cd %}
The code of the transaction data type. Value: '01'= Metro entry, '02'= Metro exit
{% enddocs %}

{% docs field_trxn_sno %}
The sequence number of the transaction. Value: '1' ~ '9999999999'
{% enddocs %}

{% docs field_cid_id %}
Identity number of the Card Interface Device (CID). Unique within the transit region. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_cid_ser_num %}
Serial number of the Card Interface Device. Unique among all CIDs in the world. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_trxn_utc_dtime %}
Date and time that the transaction occurred. (UTC) Value: 'YYYY-MM-DDThh:mm:ssZ'
{% enddocs %}

{% docs field_csc_mfg_id %}
Manufactures CSC ID.  Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_eis_num %}
**Redacted field, hashed using original value and INSERTED_DTM**. Card serial or electronic identification number. Value: 20 digits number. Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_rider_cls_cd %}
Rider classification as encoded on the CSC. Value: Not yet confirmed. Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_ppt_loc %}
Card Success or Failure division Value: 0 ??? Success, 1 ??? Failure
{% enddocs %}

{% docs field_trxn_stat_cd %}
Success or rejection of transaction. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_fare_inst_id %}
Unique fare instrument ID. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_rider_remain_cnt %}
RidesRemaining on this pass. Value: '255' = unlimited rides. Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_sv_trxn_val %}
Amount card's stored value has changed due to the possible use of stored value to pay for a pass. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_sv_remain_val %}
Amount remaining in card's stored value after the transaction was completed. Includes bonus amount. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_trxn_cd %}
Unique stop-point in the transit travel region. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_oper_stat_result_cd %}
Type of use or load for this CSC. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.
{% enddocs %}

{% docs field_last_use_dtime %}
Date and time of the last use. Value: 'YYYY-MM-DDThh:mm:ssZ'
{% enddocs %}

{% docs field_last_use_loc_cd %}
Unique stop-point in the transit travel region. Location of the last use. Value: Please refer to Data Interface Control Document for the PPT and PV Devices for [AGENCY] SI vendor_3 5 document.Location of the last use.
{% enddocs %}

{% docs field_csc_num %}
**Redacted field, hashed using original value and INSERTED_DTM**. Pending documentation.
{% enddocs %}

{% docs field_csc_sno %}
cscSeqNumber defined in ICD  
{% enddocs %}

{% docs field_trxn_no %}
transNum defined in ICD  
{% enddocs %}

{% docs field_alpo_use_val %}
Alpo value used
{% enddocs %}

{% docs field_prod_use_load %}
Product use load
{% enddocs %}

{% docs field_fare_table_id %}
fare table id
{% enddocs %}

<!-- FARE sale -->

{% docs field_transaction_dtm %}
Pending documentation.
{% enddocs %}

{% docs field_operator_id %}
Pending documentation.
{% enddocs %}

{% docs field_media_type_id %}
Pending documentation.
{% enddocs %}

{% docs field_sale_transaction_type %}
Pending documentation.
{% enddocs %}

{% docs field_quantity %}
Pending documentation.
{% enddocs %}

{% docs field_bonus_added %}
Pending documentation.
{% enddocs %}

{% docs field_rides_added %}
Pending documentation.
{% enddocs %}

{% docs field_deposit %}
Pending documentation.
{% enddocs %}

{% docs field_sv_amount_used %}
Pending documentation.
{% enddocs %}

{% docs field_cr_db_amount %}
Pending documentation.
{% enddocs %}

{% docs field_region_id %}
Pending documentation.
{% enddocs %}

{% docs field_data_format %}
Pending documentation.
{% enddocs %}

{% docs field_rev_or_test %}
Pending documentation.
{% enddocs %}

{% docs field_country %}
Pending documentation.
{% enddocs %}

{% docs field_agency_id %}
Pending documentation.
{% enddocs %}

{% docs field_transaction_status_cd %}
Pending documentation.
{% enddocs %}

{% docs field_fare_instrument_id %}
Pending documentation.
{% enddocs %}

{% docs field_service_type %}
Pending documentation.
{% enddocs %}

{% docs field_updated_dtm %}
Pending documentation.
{% enddocs %}

{% docs field_processed_flag %}
Pending documentation.
{% enddocs %}

{% docs field_facid %}
Pending documentation.
{% enddocs %}

{% docs field_autoload_event_id %}
Pending documentation.
{% enddocs %}

{% docs field_sv_transaction %}
Pending documentation.
{% enddocs %}

{% docs field_sv_remaining %}
Pending documentation.
{% enddocs %}

{% docs field_rides_remaining %}
Pending documentation.
{% enddocs %}

{% docs field_net_value %}
Pending documentation.
{% enddocs %}

{% docs field_bus_id %}
Pending documentation.
{% enddocs %}

{% docs field_run_id %}
Pending documentation.
{% enddocs %}

{% docs field_route_id %}
Pending documentation.
{% enddocs %}

{% docs field_receipt_issued %}
Pending documentation.
{% enddocs %}

{% docs field_load_type_id %}
Pending documentation.
{% enddocs %}

{% docs field_product_use_load_id %}
Pending documentation.
{% enddocs %}

{% docs field_authority_id %}
Pending documentation.
{% enddocs %}

{% docs field_cash_collected %}
Pending documentation.
{% enddocs %}

{% docs field_action_cd %}
Pending documentation.
{% enddocs %}

{% docs field_retrieval_ref_num %}
Pending documentation.
{% enddocs %}

{% docs field_replacement_fee %}
Pending documentation.
{% enddocs %}

{% docs field_merchant_id %}
Pending documentation.
{% enddocs %}

{% docs field_merchant_type %}
Pending documentation.
{% enddocs %}

{% docs field_administrative_fee %}
Pending documentation.
{% enddocs %}

{% docs field_route_number %}
Pending documentation.
{% enddocs %}

{% docs field_receipt_ticket_number %}
Pending documentation.
{% enddocs %}

{% docs field_date_cutover_time %}
Pending documentation.
{% enddocs %}

{% docs field_response_code %}
Pending documentation.
{% enddocs %}

{% docs field_auth_id_response %}
Pending documentation.
{% enddocs %}

{% docs field_pos_entry_mode %}
Pending documentation.
{% enddocs %}

{% docs field_processing_code %}
Pending documentation.
{% enddocs %}

{% docs field_terminal_id %}
Pending documentation.
{% enddocs %}

{% docs field_alighting_stop %}
Pending documentation.
{% enddocs %}

{% docs field_high_zone %}
Pending documentation.
{% enddocs %}

{% docs field_low_zone %}
Pending documentation.
{% enddocs %}

{% docs field_group_id %}
Pending documentation.
{% enddocs %}

{% docs field_group_seq_no %}
Pending documentation.
{% enddocs %}

{% docs field_home_garage %}
Pending documentation.
{% enddocs %}

{% docs field_benefit_value %}
Pending documentation.
{% enddocs %}

{% docs field_boarding_stop %}
Pending documentation.
{% enddocs %}

{% docs field_local_logon_id %}
Pending documentation.
{% enddocs %}

{% docs field_device_transaction_id %}
Pending documentation.
{% enddocs %}

{% docs field_latitude %}
Pending documentation.
{% enddocs %}

{% docs field_longitude %}
Pending documentation.
{% enddocs %}

{% docs field_transit_mode_id %}
Pending documentation.
{% enddocs %}

{% docs field_participant_inserted_dtm %}
Pending documentation.
{% enddocs %}

{% docs field_participant_transit_day %}
Pending documentation.
{% enddocs %}

{% docs field_participant_financial_day %}
Pending documentation.
{% enddocs %}

{% docs field_eod_processed_flag %}
Pending documentation.
{% enddocs %}

{% docs field_fa_processed_flag %}
Pending documentation.
{% enddocs %}

{% docs field_alp_txn_flag %}
Pending documentation.
{% enddocs %}

{% docs field_fare_level_id %}
Pending documentation.
{% enddocs %}

{% docs field_run_route_record_identifier %}
Pending documentation.
{% enddocs %}

{% docs field_lat_long_data %}
Pending documentation.
{% enddocs %}

{% docs field_incorrect_transaction_dtm %}
Pending documentation.
{% enddocs %}

{% docs field_inter_fare_queue_mesg_nbr %}
Pending documentation.
{% enddocs %}

{% docs field_inter_fare_queue_batch_nbr %}
Pending documentation.
{% enddocs %}

{% docs field_orig_transaction_status_cd %}
Pending documentation.
{% enddocs %}

{% docs field_serial_nbr %}
**Redacted field, hashed using original value and INSERTED_DTM**. Pending documentation.
{% enddocs %}

{% docs field_employee_id %}
**Redacted field, hashed using original value and INSERTED_DTM**. Pending documentation.
{% enddocs %}

{% docs field_employee_identification %}
**Redacted field, hashed using original value and INSERTED_DTM**. Pending documentation.
{% enddocs %}

{% docs field_employee_serial_nbr %}
**Redacted field, hashed using original value and INSERTED_DTM**. Pending documentation.
{% enddocs %}

<!-- FARE use unique columns -->

{% docs field_use_transaction_type %}
Pending documentation.
{% enddocs %}

{% docs field_riders %}
Pending documentation.
{% enddocs %}

{% docs field_manual_override %}
Pending documentation.
{% enddocs %}

{% docs field_use_type %}
Pending documentation.
{% enddocs %}

{% docs field_journey_start_dtm %}
Pending documentation.
{% enddocs %}

{% docs field_sv_adjusted_txn %}
Pending documentation.
{% enddocs %}

{% docs field_days_valid %}
Pending documentation.
{% enddocs %}

{% docs field_validity_period %}
Pending documentation.
{% enddocs %}

{% docs field_transfer_count %}
Pending documentation.
{% enddocs %}

{% docs field_start_dtm %}
Pending documentation.
{% enddocs %}

{% docs field_stop_point_id %}
Pending documentation.
{% enddocs %}

{% docs field_previous_stop_point_id %}
Pending documentation.
{% enddocs %}

{% docs field_last_use_operator_id %}
Pending documentation.
{% enddocs %}