import {
  id = "/subscriptions/${var.arm_subscription_id}/resourceGroups/${var.vnet_rg_name}/providers/Microsoft.Network/virtualNetworks/${local.resource_names.vnet}"
  to = azurerm_virtual_network.vnet
}

import {
  id = "/subscriptions/${var.arm_subscription_id}/resourceGroups/${var.vnet_rg_name}/providers/Microsoft.Network/virtualNetworks/${local.resource_names.vnet}/subnets/${local.resource_names.snet_aca}"
  to = azurerm_subnet.aca
}

import {
  id = "/subscriptions/${var.arm_subscription_id}/resourceGroups/${var.vnet_rg_name}/providers/Microsoft.Network/virtualNetworks/${local.resource_names.vnet}/subnets/${local.resource_names.snet_pe}"
  to = azurerm_subnet.pe
}

import {
  id = "/subscriptions/${var.arm_subscription_id}/resourceGroups/${var.vnet_rg_name}/providers/Microsoft.Network/virtualNetworks/${local.resource_names.vnet}/subnets/${local.resource_names.snet_psql}"
  to = azurerm_subnet.psql
}

import {
  id = "/subscriptions/${var.arm_subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/${local.resource_names.cae}"
  to = azurerm_container_app_environment.cae
}
