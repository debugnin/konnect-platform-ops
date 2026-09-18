# Dedicated Cloud Gateway data plane for the control plane. Konnect
# provisions and manages this data plane directly, so there is no
# self-managed DP client certificate to register (unlike a self-hosted
# hybrid-mode data plane).

# Looks up the Cloud Gateway provider account(s) Konnect has automatically
# provisioned for this org (no manual linking step required) so the network
# below doesn't require a hardcoded account ID.
data "konnect_cloud_gateway_provider_account_list" "my_cloudgatewayprovideraccountlist" {}

locals {
  # Provider accounts available to this org, filtered to the target cloud provider.
  matching_provider_accounts = [
    for account in data.konnect_cloud_gateway_provider_account_list.my_cloudgatewayprovideraccountlist.data :
    account if account.provider == var.cloud_gateway_provider
  ]

  # Use the explicit var override if set, otherwise auto-discover from the
  # available provider accounts. Errors loudly if none/ambiguous so plan
  # fails fast instead of picking the wrong account.
  cloud_gateway_provider_account_id = coalesce(
    var.cloud_gateway_provider_account_id,
    length(local.matching_provider_accounts) == 1 ? local.matching_provider_accounts[0].id : null,
  )
}

resource "konnect_cloud_gateway_network" "network" {
  name                              = "konnect-platform-ops-network"
  region                            = var.cloud_gateway_region
  cidr_block                        = var.cloud_gateway_cidr_block
  availability_zones                = var.cloud_gateway_availability_zones
  cloud_gateway_provider_account_id = local.cloud_gateway_provider_account_id
}

resource "konnect_cloud_gateway_configuration" "data_plane" {
  control_plane_id  = konnect_gateway_control_plane.control_plane.id
  control_plane_geo = var.control_plane_geo
  kind              = "dedicated.v0"
  version           = var.cloud_gateway_kong_version

  dataplane_groups = [
    {
      provider                 = var.cloud_gateway_provider
      region                   = var.cloud_gateway_region
      cloud_gateway_network_id = konnect_cloud_gateway_network.network.id

      autoscale = {
        configuration_data_plane_group_autoscale_autopilot = {
          kind     = "autopilot"
          base_rps = var.cloud_gateway_base_rps
        }
      }
    },
  ]
}
