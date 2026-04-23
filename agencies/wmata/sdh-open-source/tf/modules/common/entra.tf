# =============================================================================
# User Groups

# Defines a group for Azure users who should be able to log in to Data Hub services, and have read-only permission in the data lake.
resource "azuread_group" "users" {
  count = var.can_modify_entra ? 1 : 0

  display_name     = "[Project Name] Users - ${var.environment_name}"
  description      = "Users with read access to [Project Name] services"
  security_enabled = true
}

# Defines a group for Azure users who should have developer permissions in Data Hub services, including write access to the data lake.
resource "azuread_group" "developers" {
  count = var.can_modify_entra ? 1 : 0

  display_name     = "[Project Name] Developers - ${var.environment_name}"
  description      = "Users with developer access to [Project Name] services"
  security_enabled = true
}