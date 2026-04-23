{% docs field_row_id %}
An identifier that uniquely identifies an incoming row from a source system.
This is not a semantically meaningful primary key; it should be used for basic data integrity checks.
{% enddocs %}

{% docs field_row_hash %}
A hash of row data values that can be used for duplicate detection/handling.
{% enddocs %}
