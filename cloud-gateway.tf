# Dedicated Cloud Gateway data plane for the control plane. Konnect
# provisions and manages this data plane directly, so there is no
# self-managed DP client certificate to register (unlike a self-hosted
# hybrid-mode data plane).

resource "konnect_cloud_gateway_network" "network" {
  name                              = "konnect-platform-ops-network"
  region                            = var.cloud_gateway_region
  cidr_block                        = var.cloud_gateway_cidr_block
  availability_zones                = var.cloud_gateway_availability_zones
  cloud_gateway_provider_account_id = var.cloud_gateway_provider_account_id
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
