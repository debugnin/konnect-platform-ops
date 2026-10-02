# Local Docker Data Plane joined to Konnect (hybrid mode)

This verifies that a self-managed Kong Gateway data plane running in Docker
on a laptop can join the **Sample Control Plane** in Konnect over hybrid
mode (mTLS, pinned client certificate) — as opposed to running fully
DB-less against a static file (see [`../local-dataplane/`](../local-dataplane)).

## Why this is possible

Querying the Konnect Control Planes API confirmed the Sample Control Plane
is a standard hybrid-mode control plane, not a Dedicated Cloud Gateway:

```bash
curl -s -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://au.api.konghq.com/v2/control-planes?filter[name][eq]=Sample%20Control%20Plane"
```

```json
{
  "cluster_type": "CLUSTER_TYPE_CONTROL_PLANE",
  "auth_type": "pinned_client_certs",
  "cloud_gateway": false,
  "control_plane_endpoint": "https://78e73f1135.au.cp.konghq.com",
  "telemetry_endpoint": "https://78e73f1135.au.tp.konghq.com"
}
```

`cloud_gateway: false` means Konnect isn't provisioning the data plane
infrastructure itself — a self-managed Docker/K8s/VM data plane can connect
to it directly, which is what this directory sets up.

## One-time setup: generate and pin a client certificate

Konnect's `auth_type` for this control plane is `pinned_client_certs`: the
data plane presents a certificate, and Konnect checks it against a list of
certs you've explicitly registered (as opposed to full PKI with a CA chain).

```bash
# 1. Generate a self-signed cert/key pair
openssl req -new -x509 -nodes -newkey rsa:2048 \
  -keyout ./cluster.key -out ./cluster.crt -days 1095 -subj "/CN=kongdp"

# 2. Register the certificate with the control plane
CP_ID="0e717e66-c285-4652-9b1a-fa882d5ade96"   # Sample Control Plane
curl -X POST "https://au.api.konghq.com/v2/control-planes/${CP_ID}/dp-client-certificates" \
  -H "Authorization: Bearer $KONNECT_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"cert\": $(python3 -c 'import json,sys; print(json.dumps(open("cluster.crt").read()))'), \"title\": \"local-docker-dp\"}"
```

`cluster.crt`/`cluster.key` are already generated in this directory (not
committed — see `.gitignore`). Re-run the two steps above to rotate them if
needed; keep the key private.

## Bring up the data plane

```bash
export KONG_LICENSE_DATA="..."   # required: jq/datakit/response-transformer-advanced are Enterprise plugins
docker compose up -d
```

The compose file sets the minimum required hybrid-mode parameters per
[Kong's Data Plane reference](https://developer.konghq.com/gateway/data-plane-reference/):

| Env var | Value | Why |
|---|---|---|
| `KONG_ROLE` | `data_plane` | |
| `KONG_DATABASE` | `off` | Data planes never own a DB |
| `KONG_KONNECT_MODE` | `on` | |
| `KONG_CLUSTER_MTLS` | `pki` | Konnect's documented value even for pinned-cert auth |
| `KONG_CLUSTER_CONTROL_PLANE` | `78e73f1135.au.cp.konghq.com:443` | from `control_plane_endpoint`, port 443 |
| `KONG_CLUSTER_TELEMETRY_ENDPOINT` | `78e73f1135.au.tp.konghq.com:443` | from `telemetry_endpoint`, port 443 |
| `KONG_CLUSTER_CERT` / `KONG_CLUSTER_CERT_KEY` | mounted `cluster.crt`/`cluster.key` | the pinned cert from the setup step |

## Verify the connection

```bash
CP_ID="0e717e66-c285-4652-9b1a-fa882d5ade96"
curl -s -H "Authorization: Bearer $KONNECT_TOKEN" \
  "https://au.api.konghq.com/v2/control-planes/${CP_ID}/nodes" | python3 -m json.tool
```

Look for an entry with `hostname` matching your container ID and
`connection_state.is_connected: true` / `config_sync.state: STATE_IN_SYNC`.
You can also check in the Konnect UI under the control plane's **Data Plane
Nodes** page.

## Push config and test

Once connected, apply the example services/routes/plugins from
[`../local-dataplane/kong.yaml`](../local-dataplane/kong.yaml) directly to
this control plane (note: `deck gateway sync` is a full-state sync — it will
delete anything on the control plane that isn't in the file):

```bash
deck gateway sync ../local-dataplane/kong.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr "https://au.api.konghq.com" \
  --konnect-control-plane-name "Sample Control Plane"
```

Then hit the local proxy (routes are HTTPS-only because the upstream `url:`
is `https://`, so use port 8443 with `-k` to skip local cert verification,
or 426-redirect-follow on 8000):

```bash
curl -sk https://localhost:8443/jq-error-transform-example/get
curl -sk https://localhost:8443/datakit-error-transform-example/get
curl -sk https://localhost:8443/response-transformer-advanced-error-transform-example/get
```

See [`../README.md`](../README.md) for the Datakit-specific 500 finding
uncovered while testing against this exact setup.
