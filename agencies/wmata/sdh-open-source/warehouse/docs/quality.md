{% docs field_is_valid %}
Boolean indicating whether the given row is valid for analytical purposes.
Combines outcomes of individual data quality checks for an overall assesment of validity.
{% enddocs %}

{% docs field_invalid_reason %}
String indicating the reason a row failed validation.
Only populated for invalid rows, null for valid rows.
{% enddocs %}

------------------ BUS INFO: STOP VISITS -------------------------

{% docs field_dup_row_to_keep %}
Boolean indicating whether the given row should be kept based on duplicate checks.
If true, this row is either unique or the first appearance of a duplicate.
If false, this row is a subsequent appearance of a duplicate and should be dropped.
{% enddocs %}

{% docs field_has_duplicates %}
Boolean indicating whether the given row had duplicates.
{% enddocs %}

{% docs field_in_grouped_row %}
Boolean indicating whether the given row has been grouped into new entry.
{% enddocs %}

{% docs field_has_service_date %}
Boolean indicating whether the given row has a non-null service_date value.
service_date is a required field.
{% enddocs %}

{% docs field_has_trip_id_performed %}
Boolean indicating whether the given row has a non-null trip_id_performed value.
trip_id_performed is a required field.
{% enddocs %}

{% docs field_has_positive_trip_stop_sequence %}
Boolean indicating whether the given row has a positive trip_stop_sequence value.
Negative trip_stop_sequence values are invalid.
{% enddocs %}

{% docs field_has_corrected_dwell %}
Boolean indicating whether the dwell time of a stop has been corrected based off actual_departure_time - actual_arrival_time.
{% enddocs %}

{% docs field_has_corrected_stop_sequence %}
Boolean indicating whether the given row has trip_stop_sequence_imputed different from trip_stop_sequence.
{% enddocs %}

{% docs field_has_imputed_trip_id_performed %}
Boolean indicating whether the given row has trip_id_performed_imputed.
{% enddocs %}

{% docs field_has_trip_id_scheduled %}
Boolean indicating whether the given row has a non-null trip_id_scheduled value.
{% enddocs %}

------------------ STATION ACTIVITIES QUALITY -------------------------

{% docs field_has_stop_id %}
Boolean indicating whether the given row has a non-null stop_id value.
stop_id is a required field.
{% enddocs %}

{% docs field_is_entry_consistent %}
Boolean indicating if is_entry is consistent with event_type.
True when is_entry flag matches the expected value based on event_type.
{% enddocs %}

{% docs field_is_exit_consistent %}
Boolean indicating if is_exit is consistent with event_type.
True when is_exit flag matches the expected value based on event_type.
{% enddocs %}

------------------ vendor_2 FARES QUALITY -------------------------

{% docs field_vendor_2_is_dupe %}
Boolean indicating whether the given row is a duplicate based on event_timestamp and device_id.
{% enddocs %}

{% docs field_vendor_2_is_first_instance %}
Boolean indicating whether the given row is the first instance when duplicates exist.
If true, this row should be kept; if false, this is a duplicate that should be dropped.
{% enddocs %}

{% docs field_vendor_2_is_unbalanced_complete_variable_fare %}
Boolean indicating whether a complete variable fare micropayment has unbalanced entry/exit transactions.
True if the micropayment does not have exactly one entry and one exit transaction.
Only populated for complete variable fare charge types; null for other charge types.
{% enddocs %}

{% docs field_vendor_2_entry_count %}
Count of entry transactions (Enter, Transfer entrance) for complete variable fare micropayments.
Expected value is 1. Only populated for complete variable fare charge types; null for other charge types.
{% enddocs %}

{% docs field_vendor_2_exit_count %}
Count of exit transactions (Exit, Transfer exit) for complete variable fare micropayments.
Expected value is 1. Only populated for complete variable fare charge types; null for other charge types.
{% enddocs %}

{% docs field_vendor_2_has_multiple_entries %}
Boolean indicating whether a complete variable fare micropayment has more than one entry transaction.
True indicates a data quality issue. Only populated for complete variable fare charge types; null for other charge types.
{% enddocs %}

{% docs field_vendor_2_has_multiple_exits %}
Boolean indicating whether a complete variable fare micropayment has more than one exit transaction.
True indicates a data quality issue. Only populated for complete variable fare charge types; null for other charge types.
{% enddocs %}

{% docs field_vendor_2_has_no_entry %}
Boolean indicating whether a complete variable fare micropayment has no entry transaction.
True indicates a data quality issue. Only populated for complete variable fare charge types; null for other charge types.
{% enddocs %}

{% docs field_vendor_2_has_no_exit %}
Boolean indicating whether a complete variable fare micropayment has no exit transaction.
True indicates a data quality issue. Only populated for complete variable fare charge types; null for other charge types.
{% enddocs %}

{% docs field_has_pattern_id %}
Boolean indicating whether a trip has non-null pattern id.
{% enddocs %}