{% docs field_has_transaction_id %}
Boolean indicating whether the given row has a non-null transaction_id value.
transaction_id is a required field.
{% enddocs %}

{% docs field_has_fare_service_date %}
Boolean indicating whether the given row has a non-null service_date value.
service_date is a required field.
{% enddocs %}

{% docs field_has_event_timestamp %}
Boolean indicating whether the given row has a non-null event_timestamp value.
event_timestamp is a required field.
{% enddocs %}

{% docs field_has_amount %}
Boolean indicating whether the given row has a non-null amount value.
amount is a required field.
{% enddocs %}

{% docs field_has_fare_action %}
Boolean indicating whether the given row has a non-null fare_action value.
fare_action is a required field.
{% enddocs %}

{% docs field_has_valid_fare_action %}
Boolean indicating whether the given row has a valid fare_action value from the accepted list.
Valid fare actions are: 'Purchase', 'Enter', 'Exit', 'Transfer entrance', 'Transfer exit', 'Add', 'New', 'Capture', 'Extend', 'Combine', 'Void', 'Activate', 'Adjust', 'Other'.
{% enddocs %}

{% docs field_has_valid_fare_media_id %}
Boolean indicating whether the given row has a valid fare_media_id value from the accepted list.
Valid fare media types are: 'Cash or coins', 'Smart card or ticket', 'Magnetic-stripe card or ticket', 'Bank card', 'Mobile NFC', 'Optical scan', 'Button pressed by driver or operator to indicate a boarding or alighting passenger.', 'Other type'.
{% enddocs %}

{% docs field_source_system_fare %}
In the current implementation, these quality checks apply to fare transactions from FARE data sources (FARE_SALE and FARE_USE) in alignment with the TIDES schema modification proposal by [AGENCY]. faregate_data data is now handled through the passenger_events model.
{% enddocs %}