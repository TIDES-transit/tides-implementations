from dagster import define_asset_job, build_schedule_from_partitioned_job
from .assets import faregate_data_mtn, faregate_data_orgn, fare_sale, fare_use


# jobs ---------------------------------------------

# In the future these will probably merge back,
# but the partitions vary between the tables due to differing time periods in the QA data
faregate_data_mtn_job = define_asset_job("faregate_data_mtn_job", selection=[faregate_data_mtn])
faregate_data_orgn_job = define_asset_job("faregate_data_orgn_job", selection=[faregate_data_orgn])

fare_sale_job = define_asset_job("fare_sale_job", selection=[fare_sale])
fare_use_job = define_asset_job("fare_use_job", selection=[fare_use])

# schedules ----------------------------------------------------------
# Run daily at 6 AM ET to ensure previous day's data is fully ingested

faregate_data_mtn_schedule = build_schedule_from_partitioned_job(faregate_data_mtn_job, hour_of_day=6)
faregate_data_orgn_schedule = build_schedule_from_partitioned_job(faregate_data_orgn_job, hour_of_day=6)
fare_sale_schedule = build_schedule_from_partitioned_job(fare_sale_job)
fare_use_schedule = build_schedule_from_partitioned_job(fare_use_job)