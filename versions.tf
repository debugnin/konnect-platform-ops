terraform {
  required_version = ">= 1.6"

  required_providers {
    konnect = {
      source  = "kong/konnect"
      version = "3.22.0"
    }
  }
}
