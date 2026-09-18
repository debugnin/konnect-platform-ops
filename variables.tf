variable "cloud_gateway_provider_account_id" {
  description = <<-EOT
    Konnect Cloud Gateway provider account ID for the linked cloud account
    (Konnect UI: Cloud Gateway > Provider Accounts).

    Optional: leave unset (null) to auto-discover via the
    konnect_cloud_gateway_provider_account_list data source, filtered to
    cloud_gateway_provider. Auto-discovery only works if exactly one
    provider account is linked for that provider; if you have more than
    one linked account, set this explicitly to disambiguate.
  EOT
  type        = string
  default     = null
}

variable "cloud_gateway_provider" {
  description = "Cloud provider to deploy the data plane into. Must match the cloud vendor of cloud_gateway_provider_account_id."
  type        = string
  default     = "aws"
}

variable "cloud_gateway_region" {
  description = "Cloud provider region for the dedicated Cloud Gateway network and data plane."
  type        = string
}

variable "cloud_gateway_availability_zones" {
  description = "Availability zone IDs for the Cloud Gateway network (Konnect UI/API for the chosen region)."
  type        = list(string)
}

variable "cloud_gateway_cidr_block" {
  description = "CIDR block for the Cloud Gateway network. Must not overlap with reserved blocks for the target region."
  type        = string
  default     = "10.0.0.0/16"
}

variable "control_plane_geo" {
  description = "Konnect control-plane geo for the Cloud Gateway configuration."
  type        = string
  default     = "au"
}

variable "cloud_gateway_kong_version" {
  description = "Kong Gateway version to run on the dedicated Cloud Gateway data plane (Konnect UI: Cloud Gateway > Create Configuration, for supported versions)."
  type        = string
}

variable "cloud_gateway_base_rps" {
  description = "Base requests per second the autopilot autoscaler should provision the data plane to support."
  type        = number
  default     = 10
}
