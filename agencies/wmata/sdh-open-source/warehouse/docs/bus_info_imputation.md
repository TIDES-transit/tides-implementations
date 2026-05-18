{% docs field_trip_stop_sequence_imputed %}
Integer stop sequence computed within same service_date and trip_id_performed in bus info.
Null stop_ids are skipped.
{% enddocs %}

{% docs field_trip_id_performed_imputed %}
Imputed trip id for all events, especially useful to identify and break down trips by service data and bus (vehicle)
id when trip_id_performed is NULL. Follows string pattern of bus id - pattern_or_hash - run_start_time.
{% enddocs %}