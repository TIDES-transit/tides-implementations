{% docs field_bus_ridership_service_date %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_entdateint %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_period_key %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_facid %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_fare_instrument_id %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_route_number %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_negative_ride_id %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_card_class_id %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_control_date %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_entry_cnt %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_transfer_cnt %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_cash_ride_cnt %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_entry_amt %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_transfer_amt %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_cash_ride_amt %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_load_amt %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_incomplete_ride_cash %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_incomplete_nonride_cash %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_ent_sv_transaction %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_ent_alp_value_used %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_tfr_sv_transaction %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_tfr_alp_value_used %}
TODO: Document this
{% enddocs %}

{% docs field_bus_ridership_mfg_id %}
TODO: Document this
{% enddocs %}

{% docs field_d_date_date_key %}
Primary key id pointing to a specific date
{% enddocs %}

{% docs field_d_date_dateday %}
Specific date referred to by this record
{% enddocs %}

{% docs field_d_date_yearmo %}
The year and month of the dateday represented as an integer with the form YYYYMM
{% enddocs %}

{% docs field_d_date_date_month %}
The month of the dateday represented as a full English spelling of the month
{% enddocs %}

{% docs field_d_date_date_quarter %}
The quarter of the year of the dateday represented in the format Qn where n is the quarter identifier between 1 & 4
Quarters are associated with the following monthly ranges:
Q1 = January - March
Q2 = April - June
Q3 = July - September
Q4 = October - December
{% enddocs %}

{% docs field_d_date_date_year %}
The 4 digit year of the dateday
{% enddocs %}

{% docs field_d_date_date_day_of_week %}
The day of the week in its abbreviated form (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
{% enddocs %}

{% docs field_d_date_date_day_of_week_num %}
The day of the week of the dateday represented as an integer
Days of the week are mapped as follows:
1 = Sunday
2 = Monday
3 = Tuesday
4 = Wednesday
5 = Thursday
6 = Friday
7 = Sunday
{% enddocs %}

{% docs field_d_date_date_day_type %}
Designates whether dateday is a "Weekend" (Sat-Sun) or "Weekday" (Mon-Fri)
{% enddocs %}

{% docs field_d_date_date_holiday %}
Value is set to "Yes" if the dateday represented by this record is a holiday; else "No"
{% enddocs %}

{% docs field_d_date_date_week_num %}
Numeric value indicating the week of the year represented by dateday (1-53)
{% enddocs %}

{% docs field_d_date_date_week_ending %}
Indicates the last date of the current week for the date represented by dateday - weeks always end on a Saturday
{% enddocs %}

{% docs field_d_date_service_type %}
Notes the service type associated with the dateday as it pertains to fare calculations (Weekday, Saturday, Sunday)
{% enddocs %}
