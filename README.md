# konnect-platform-ops

Minimal Terraform configuration for a Kong Konnect control plane backed by a
dedicated Cloud Gateway data plane (AU region).

## What this manages

| Resource | Description |
|---|---|
| **Control plane** | `konnect_gateway_control_plane` with `cloud_gateway = true` |
| **Cloud Gateway network** | `konnect_cloud_gateway_network` — the network the data plane runs in |
| **Cloud Gateway configuration** | `konnect_cloud_gateway_configuration` — ties the data plane to the control plane |

Konnect provisions and manages the data plane directly; there is no
self-hosted data plane to run and no client certificate to register.

## Prerequisites

- Terraform >= 1.6
- A Konnect personal access token with org-admin or CP-admin scope

No manual account-linking step is required: Konnect automatically provisions
a Cloud Gateway provider account per org/cloud-vendor, and this config looks
it up for you (see "Provider account auto-discovery" below).

## Authentication

Export your Konnect PAT before running any Terraform command:

```bash
export KONNECT_TOKEN="kpat_..."
```

## Required variables

None of these have defaults — they're specific to your Konnect org and target region:

| Variable | Description |
|---|---|
| `cloud_gateway_region` | Cloud provider region, e.g. `ap-southeast-2` |
| `cloud_gateway_availability_zones` | AZ IDs for that region, from the Konnect UI/API |
| `cloud_gateway_kong_version` | Kong Gateway version to run on the data plane |

See `variables.tf` for the full variable list, including `cloud_gateway_provider`, `cloud_gateway_cidr_block`, and `control_plane_geo`, which do have defaults you can override.

### Provider account auto-discovery

`cloud_gateway_provider_account_id` is **optional** and normally doesn't need
to be set at all. Konnect automatically provisions a Cloud Gateway provider
account for each org/cloud-vendor pair — there's no manual linking step or
UI action required. If left unset, the ID is auto-discovered via the
`konnect_cloud_gateway_provider_account_list` data source, filtered to
`cloud_gateway_provider` (default `aws`).

This works as long as your Konnect org has exactly one provider account for
that cloud provider, which is the default/common case. If your org somehow
has more than one (e.g. multiple AWS provider accounts), set
`cloud_gateway_provider_account_id` explicitly in `terraform.tfvars` to
disambiguate — otherwise `terraform plan` will fail with a null value error.

## Usage

Copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored) and fill in real values:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Provider

Uses the [Kong Konnect Terraform provider](https://registry.terraform.io/providers/kong/konnect/latest) (`kong/konnect 3.22.0`) targeting `https://au.api.konghq.com`.
