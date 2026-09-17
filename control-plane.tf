resource "konnect_gateway_control_plane" "control_plane" {
  name          = "Konnect Control Plane"
  description   = "Control plane backed by a dedicated Cloud Gateway data plane"
  cluster_type  = "CLUSTER_TYPE_CONTROL_PLANE"
  cloud_gateway = true
  auth_type     = "pinned_client_certs"
}
