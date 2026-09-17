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
- A Konnect Cloud Gateway provider account already linked (Konnect UI: Cloud Gateway > Provider Accounts) for the cloud vendor you deploy into

## Authentication

Export your Konnect PAT before running any Terraform command:

```bash
export KONNECT_TOKEN="kpat_..."
```

## Required variables

None of these have defaults — they're specific to your Konnect org and target region:

| Variable | Description |
|---|---|
| `cloud_gateway_provider_account_id` | Linked provider account ID from the Konnect UI |
| `cloud_gateway_region` | Cloud provider region, e.g. `ap-southeast-2` |
| `cloud_gateway_availability_zones` | AZ IDs for that region, from the Konnect UI/API |
| `cloud_gateway_kong_version` | Kong Gateway version to run on the data plane |

See `variables.tf` for the full variable list, including `cloud_gateway_provider`, `cloud_gateway_cidr_block`, and `control_plane_geo`, which do have defaults you can override.

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
