# =======================================================================
# Managed Identities

resource "azurerm_user_assigned_identity" "id" {
  location            = var.resource_group_location
  name                = local.resource_names.id
  resource_group_name = var.resource_group_name
  tags                = local.id_tags
}
