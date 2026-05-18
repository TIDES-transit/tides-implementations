{% docs field_passenger_event_id %}
Unique identifier for the passenger event.
{% enddocs %}

{% docs field_passenger_event_service_date %}
Service date for the passenger event.
{% enddocs %}

{% docs field_passenger_event_event_timestamp %}
Timestamp when the passenger event occurred.
{% enddocs %}

{% docs field_passenger_event_device_id %}
Identifier for the device that recorded the passenger event. This field is required in alignment with the TIDES schema modification proposal by [AGENCY], which makes device_id required instead of vehicle_id for passenger events.
{% enddocs %}

{% docs field_passenger_event_event_type %}
Type of passenger event. Valid values include: 'Passenger boarded', 'Passenger alighted', 'Door opened', 'Door closed', etc.
{% enddocs %}

{% docs field_passenger_event_linked_transaction_id %}
Identifier for a related fare transaction, if one exists. This field is optional and was added in alignment with the TIDES schema modification proposal by [AGENCY] to link passenger events with their associated fare transactions when applicable.
{% enddocs %}

{% docs field_passenger_event_event_count %}
Count for this event, default is 1.
{% enddocs %}

{% docs field_passenger_event_stop_id %}
Identifier for the stop or station where the passenger event occurred.
{% enddocs %}

{% docs field_passenger_event_location_ping_id %}
Identifier for the vehicle location where the passenger event occurred.
{% enddocs %}

{% docs field_passenger_event_trip_id_performed %}
Identifier for the trip performed.
{% enddocs %}

{% docs field_passenger_event_trip_id_scheduled %}
Identifier for the scheduled trip.
{% enddocs %}

{% docs field_passenger_event_trip_stop_sequence %}
The actual order of stops visited within a performed trip. For station-based faregate events, this field is optional in alignment with the TIDES schema modification proposal by [AGENCY], which makes trip_stop_sequence optional for events not associated with a trip.
{% enddocs %}

{% docs field_passenger_event_scheduled_stop_sequence %}
Scheduled order of stops for a particular trip.
{% enddocs %}

{% docs field_passenger_event_vehicle_id %}
Identifier for the vehicle. For station-based faregate events, this field is optional in alignment with the TIDES schema modification proposal by [AGENCY], which makes vehicle_id optional for events that occur at a fixed location (station/stop).
{% enddocs %}

{% docs field_passenger_event_train_car_id %}
Identifier for the train car.
{% enddocs %}

{% docs field_passenger_event_pattern_id %}
Identifier for the unique stop-path for a trip.
{% enddocs %}

{% docs field_passenger_event_rider_category %}
Indicates rider category (categories defined by transit agency). For example: 'Adult', 'Youth', 'Student', 'Senior', 'Other reduced'.

Mapping from source systems:

- faregate_data_ORGN.rider_cls_cd:
  - Values are preserved as 'Rider class X' where X is the original code
  - Note: No documentation is currently available for these codes
{% enddocs %}

{% docs field_passenger_event_source_system %}
Source system for the passenger event data. In the current implementation, this model focuses exclusively on faregate_data_ORGN data in alignment with the TIDES schema modification proposal by [AGENCY].
{% enddocs %}