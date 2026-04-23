import {
  id = "/subscriptions/${var.arm_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/${var.system_name}-${var.environment_name}-cae"
  to = module.common.azurerm_container_app_environment.cae[0]
}
