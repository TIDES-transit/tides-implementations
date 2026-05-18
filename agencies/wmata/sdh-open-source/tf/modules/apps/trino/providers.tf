terraform {
  required_providers {
    # While providers that come from HashiCorp get inherited automatically,
    # we need to explicitly define any third-party providers.
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = "~>1.0"
    }
  }
}
