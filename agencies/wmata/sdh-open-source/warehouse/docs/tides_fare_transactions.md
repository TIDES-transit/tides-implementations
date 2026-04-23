{% docs field_transaction_id %}
Unique identifier for the fare transaction.
{% enddocs %}

{% docs field_service_date %}
Service date for the fare transaction. References GTFS indirectly via calendars.txt and calendar_dates.txt.
{% enddocs %}

{% docs field_event_timestamp %}
Recorded event timestamp, including for transactions that may be aggregated values associated with a trip or vehicle.
{% enddocs %}

{% docs field_location_ping_id %}
Identifies the vehicle location where the fare transaction occurred.
{% enddocs %}

{% docs field_amount %}
Value of the transaction.
{% enddocs %}

{% docs field_currency_type %}
Currency used for the transaction. References GTFS.
{% enddocs %}

{% docs field_fare_action %}
Indicates the type of action performed. Valid values include: 'Purchase', 'Enter', 'Exit', 'Transfer entrance', 'Transfer exit', 'Add', 'New', 'Capture', 'Extend', 'Combine', 'Void', 'Activate', 'Adjust', 'Other', 'Unknown action type'.

Mapping from source systems:

- FARE_SALE.sale_transaction_type:
  - 0 (POP Sale) → 'New'
    - Justification: Creating a new proof of payment ticket is more precisely represented by 'New' than 'Purchase', as it specifically indicates creating new fare media.
  
  - 1 (CSC Pass Load) → 'Activate'
    - Justification: 'Activate' better represents adding a pass to a card than 'Purchase', as it specifically indicates enabling a time-based product.
  
  - 2 (CSC Value Load) → 'Add'
    - Justification: 'Add' is the perfect match as it's literally adding stored value to existing media, which is exactly what the TIDES spec defines 'Add' for.
  
  - 3 (Magnetic Pass Load) → 'Activate'
    - Justification: Similar to CSC Pass Load, this is activating a time-based pass on a card rather than a direct purchase.
  
  - 4 (Magnetic Value Load) → 'Add'
    - Justification: Similar to CSC Value Load, this is adding monetary value to an existing card.
  
  - 5 (On Board Sale) → 'Purchase'
    - Justification: 'Purchase' is appropriate as it's a direct cash transaction for fare media on a vehicle, aligning with the TIDES definition.
  
  - 6 (Unknown) → 'Other'
    - Note: This value is not documented in the reference table. Further investigation into [AGENCY] documentation is needed.

- FARE_USE.use_type and use_transaction_type:
  - use_type = 9 (Entry/Tag On) → 'Enter'
  - use_type = 10 (Exit/Tag Off) → 'Exit'
  - use_type = 11 (Free Exit) → 'Exit'
  - use_type = 12 (Free Entry) → 'Enter'
  - use_type = 1 and use_transaction_type = 1 → 'Transfer entrance'
  - use_transaction_type = 1 (CSC Use) → 'Enter'
  - use_transaction_type = 2 (Magnetic Use) → 'Enter'
  - use_transaction_type = 0 (POP Use) → 'Enter'
  - use_transaction_type = 3 → 'Exit'
  - use_transaction_type = 4 → 'Transfer entrance'
  - use_transaction_type = 5 → 'Transfer exit'
{% enddocs %}

{% docs field_trip_id_performed %}
Identifies the trip performed. May be null if the fare collection device is NOT located on a vehicle. May be null if on a vehicle but trip-level data is unavailable, in which case the data would be associated with the vehicle.
{% enddocs %}

{% docs field_trip_id_scheduled %}
Identifies the scheduled trip. May be null if the fare collection device is NOT located on a vehicle. May be null if on a vehicle but schedule data is unavailable, in which case the data would be associated with the vehicle.
{% enddocs %}

{% docs field_pattern_id %}
Identifies the unique stop-path for a trip, may be distinct from GTFS shapes.shape_id.
{% enddocs %}

{% docs field_trip_stop_sequence %}
The actual order of stops visited within a performed trip. The values must start at 1 and must be consecutive along the trip.
{% enddocs %}

{% docs field_scheduled_stop_sequence %}
Scheduled order of stops for a particular trip. The values must increase along the trip but do not need to be consecutive. References GTFS.
{% enddocs %}

{% docs field_vehicle_id %}
Identifies the vehicle. May be null if collection device is NOT located on a vehicle. May be null if on a vehicle but vehicle data is unavailable, in which case the data would be associated with a trip and/or stop.
{% enddocs %}

{% docs field_device_id %}
Identifies the ITS device on which the fare transaction was performed. May be null if only a single device is reporting fare transactions on a vehicle and vehicle_id is provided. May be null if only a single device is reporting fare transactions at a stop and stop_id is provided.
{% enddocs %}

{% docs field_fare_id %}
Identifies a fare class, as included in the GTFS Fare_attributes file. References GTFS.
{% enddocs %}

{% docs field_stop_id %}
Identifies the stop. References GTFS.
{% enddocs %}

{% docs field_num_riders %}
The number of riders included in the transaction.
{% enddocs %}

{% docs field_fare_media_id %}
Indicates the fare medium that was used for the transaction. Valid values include: 'Cash or coins', 'Smart card or ticket', 'Magnetic-stripe card or ticket', 'Bank card', 'Mobile NFC', 'Optical scan', 'Button pressed by driver or operator to indicate a boarding or alighting passenger', 'Other type'.

Mapping from source systems:

- FARE_SALE.media_type_id and FARE_USE.media_type_id:
  - 1 (Paper POP), 6 (Smart Token), 8 (Token) → 'Other type'
  - 4 (Paper CSC), 5 (CSC) → 'Smart card or ticket'
  - 2 (Paper Magnetic), 3 (Plastic Magnetic) → 'Magnetic-stripe card or ticket'
  - 7 (Cash) → 'Cash or coins'
{% enddocs %}

{% docs field_rider_category %}
Indicates rider category (categories defined by transit agency). For example: 'Adult', 'Youth', 'Student', 'Senior', 'Other reduced'.
{% enddocs %}

{% docs field_fare_product %}
Indicates the fare group (fare groups defined by transit agency). For example: 'Single ride', 'Pass', 'Employer sponsored', 'Other pass'.

Mapping from source systems:

- FARE_SALE.fare_instrument_id and FARE_USE.fare_instrument_id:
  - 65580, 65636, 65944 (Weekly passes) → 'Pass'
  - 65586, 65587 (1-Day and 3-Day passes) → 'Pass'
  - 16385, 16386, 16388 (Stored value) → 'Stored value'
{% enddocs %}

{% docs field_fare_period %}
Indicates the fare period (fare periods defined by transit agency). For example: 'All day', 'Peak', 'Off-peak', 'Summer', 'Other'.
{% enddocs %}

{% docs field_fare_capped %}
Indicates if the fare charged in this transaction was modified by a fare capping policy.
{% enddocs %}

{% docs field_token_id %}
Identifies the individual fare instrument used for the transaction. For example, the fare card ID.
{% enddocs %}

{% docs field_balance %}
Stored value remaining on an account after the transaction is made.
{% enddocs %}

{% docs field_source_system %}
Source system for the fare transaction data. May refer to FARE fare purchasing and faregate use data (`FARE_SALE` and `FARE_USE` respectively), or to open payment data (`vendor_2`), in alignment with the TIDES schema modification proposal by [AGENCY].
{% enddocs %}