{% docs field_has_passenger_event_id %}
Boolean indicating whether the given row has a non-null passenger_event_id value.
passenger_event_id is a required field.
{% enddocs %}

{% docs field_has_passenger_service_date %}
Boolean indicating whether the given row has a non-null service_date value.
service_date is a required field.
{% enddocs %}

{% docs field_has_passenger_event_timestamp %}
Boolean indicating whether the given row has a non-null event_timestamp value.
event_timestamp is a required field.
{% enddocs %}

{% docs field_has_device_id %}
Boolean indicating whether the given row has a non-null device_id value.
device_id is a required field in alignment with the TIDES schema modification proposal by [AGENCY], which makes device_id required instead of vehicle_id for passenger events.
{% enddocs %}

{% docs field_has_event_type %}
Boolean indicating whether the given row has a non-null event_type value.
event_type is a required field.
{% enddocs %}

{% docs field_has_valid_event_type %}
Boolean indicating whether the given row has a valid event_type value from the accepted list.
For passenger events, valid event types are: 'Vehicle arrived at stop', 'Vehicle departed stop', 'Door opened', 'Door closed', 'Passenger boarded', 'Passenger alighted', 'Kneel was engaged', 'Kneel was disengaged', 'Ramp was deployed', 'Ramp was raised', 'Ramp deployment failed', 'Lift was deployed', 'Lift was raised', 'Individual bike boarded', 'Individual bike alighted', 'Bike rack deployed'.
{% enddocs %}

{% docs field_has_trip_stop_sequence %}
Boolean indicating whether the given row has a non-null trip_stop_sequence value.
trip_stop_sequence is optional for station-based events in alignment with the TIDES schema modification proposal by [AGENCY], which makes trip_stop_sequence optional for events not associated with a trip.
{% enddocs %}

{% docs field_has_vehicle_id %}
Boolean indicating whether the given row has a non-null vehicle_id value.
vehicle_id is optional for station-based events in alignment with the TIDES schema modification proposal by [AGENCY], which makes vehicle_id optional for events that occur at a fixed location (station/stop).
{% enddocs %}

{% docs field_has_linked_transaction_id %}
Boolean indicating whether the given row has a non-null linked_transaction_id value.
linked_transaction_id is an optional field that was added in alignment with the TIDES schema modification proposal by [AGENCY] to link passenger events with their associated fare transactions when applicable.
{% enddocs %}

{% docs field_passenger_event_invalid_reason %}
Explanation of why a passenger event record is considered invalid. This field is populated in the invalid records table and provides details about which validation check the record failed.
{% enddocs %}