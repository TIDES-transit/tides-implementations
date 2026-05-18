# The container app environment should have been created manually as part of the
# environment setup. If it hasn't yet been created, ensure that `has_network` is
# set to false in the .tfvars file, and comment out this import. Be sure to
# uncomment it once the environment has been created.

import {
  id = "/subscriptions/${var.arm_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/aca-datahub-[env3]"
  to = module.common.azurerm_container_app_environment.cae[0]
}