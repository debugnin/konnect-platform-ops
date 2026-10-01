# Demoing the OpenTelemetry Plugin → Datadog (SaaS) with decK

This walkthrough loads a small, self-contained decK state file against a
Konnect **Dedicated Cloud Gateway** control plane to demonstrate the
`opentelemetry` plugin configured as a **global plugin** — applied to every
Service/Route on the control plane, with no per-service wiring needed —
shipping **traces, access logs, and metrics** from Kong directly to
**Datadog's SaaS OTLP intake endpoints**. No Datadog Agent or OpenTelemetry
Collector is required for traces/logs.

Files in this folder:

| File | Purpose |
|---|---|
| `opentelemetry-datadog-sample.yaml` | The sample decK state: a single global `opentelemetry` Plugin, tagged `sample-otel-datadog` |
| `README-opentelemetry-datadog.md` | This document |

---

## ⚠️ Read this before running `deck gateway sync`

`deck gateway sync` makes the target control plane's configuration **match
the file(s) you give it exactly**. Anything already configured on the
control plane that is *not* present in the file you sync will be **deleted**.

**This is why the sample file only ever gets synced using `--select-tag`.**
Every object in `opentelemetry-datadog-sample.yaml` is tagged
`sample-otel-datadog` — do not remove the tags, and always pass
`--select-tag sample-otel-datadog` to `diff`, `sync`, and `dump`.

Never run a bare `deck gateway sync opentelemetry-datadog-sample.yaml`
(without `--select-tag`) against a control plane that has real/other
configuration on it.

**Also note:** because the plugin in this file is **global** (no
`service`/`route`/`consumer` attachment), as soon as you sync it, it starts
exporting telemetry for **every** Service/Route already configured on the
target control plane — not just a demo Service/Route. Keep that in mind
before syncing against a shared/live control plane, even with `--select-tag`
scoping the plugin object itself.

---

## ⚠️ Metrics caveat — read before you build the metrics part of the demo

Datadog's **direct OTLP metrics intake endpoint only accepts delta-temporality
metrics**. The Kong `opentelemetry` plugin currently exports metrics using
**cumulative temporality**. If you point `config.metrics.endpoint` straight at
Datadog's `/v1/metrics` intake (as the sample file does, for illustration),
Datadog will reject the payloads.

For a demo that needs **working** metrics in Datadog, put an OpenTelemetry
Collector (with Datadog's recommended Collector exporter, or a
`cumulativetodelta` processor in front of the OTLP HTTP exporter) or the
Datadog Agent's OTLP ingest between Kong and Datadog, and point
`config.metrics.endpoint` at the Collector/Agent instead of Datadog directly.

Traces and access logs do **not** have this limitation — those can go
straight from Kong to Datadog's OTLP intake, as configured in the sample file.

References:
- https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/metrics/
- https://docs.datadoghq.com/opentelemetry/setup/collector_exporter/

---

## Prerequisites

- [decK](https://developer.konghq.com/deck/installation/) installed (`deck version` to check)
- A Konnect Personal Access Token (PAT) with permission to manage the target
  control plane — the same `KONNECT_TOKEN` used elsewhere in this repo
- The name of the Konnect control plane to target
- At least one Service/Route already configured on the control plane (or one
  of your own) to generate traffic against, since this sample does not
  create one — the plugin is global and applies regardless
- A Datadog account with:
  - Your [Datadog site](https://docs.datadoghq.com/getting_started/site/)
    (e.g. US1 = `datadoghq.com`, EU = `datadoghq.eu`, US3, US5, AP1, or
    `ddog-gov.com`)
  - A Datadog **API key** (Organization Settings → API Keys)

Export your Konnect token:

```bash
export KONNECT_TOKEN="kpat_..."
```

---

## Step 1 — Resolve your Datadog OTLP hostname and API key

Datadog's direct OTLP intake hostname follows the pattern
`otlp.<your-datadog-site>` (mirroring how Datadog's `api.<site>` and
`http-intake.logs.<site>` hostnames work). For the default US1 site this is:

```
otlp.datadoghq.com
```

Confirm the exact hostname for your site on the signal-specific intake pages
before using it in a customer-facing demo:

- Traces: https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/traces/
- Logs: https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/logs/
- Metrics: https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/metrics/

Then substitute the placeholders in `opentelemetry-datadog-sample.yaml`:

| Placeholder | Replace with |
|---|---|
| `${DATADOG_SITE}` | Your resolved OTLP hostname, e.g. `otlp.datadoghq.com` |
| `${DATADOG_API_KEY}` | Your Datadog API key |

Do this with `envsubst`, a templating step in your pipeline, or — for a real
(non-demo) deployment — a
[decK/Konnect vault reference](https://developer.konghq.com/gateway/entities/vault/)
so the API key is never committed in plaintext.

Example using `envsubst`:

```bash
export DATADOG_SITE="otlp.datadoghq.com"
export DATADOG_API_KEY="dd_api_key_here"

envsubst < opentelemetry-datadog-sample.yaml > opentelemetry-datadog-sample.rendered.yaml
```

(Use the rendered file in the remaining steps instead of the template.)

---

## Step 2 — Sanity-check connectivity

```bash
deck gateway ping \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane"
```

(Adjust `--konnect-addr` to match your control plane's geo.)

---

## Step 3 — Preview the change with `diff`

```bash
deck gateway diff opentelemetry-datadog-sample.rendered.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-otel-datadog
```

Expect a single global Plugin (`opentelemetry`) listed as being created. If
the diff shows unrelated resources being deleted, **stop** — `--select-tag`
wasn't applied correctly.

---

## Step 4 — Load the sample config

```bash
deck gateway sync opentelemetry-datadog-sample.rendered.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-otel-datadog
```

---

## Step 5 — Generate traffic and verify in Datadog

Send a few requests through the Dedicated Cloud Gateway's data plane proxy
endpoint, against any existing Service/Route on the control plane (the
plugin is global, so no dedicated demo route is required):

```bash
curl -i https://<data-plane-proxy-host>/<any-existing-route-path>
```

Then check Datadog:

- **APM → Traces**: look for traces tagged `service.name:dedicated-cloud-gateway-demo`
- **Logs**: filter on `service:dedicated-cloud-gateway-demo` for the access
  logs emitted by the request above
- **Metrics**: only if you've routed metrics through a Collector/Agent per
  the caveat above — otherwise expect no metrics to appear, or 4xx errors in
  the Kong error log for the metrics exporter

You can also confirm the objects exist directly:

```bash
deck gateway dump \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-otel-datadog
```

---

## Step 6 — Clean up (optional)

```bash
echo '_format_version: "3.0"' > empty.yaml

deck gateway sync empty.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-otel-datadog
```

Because the sync is scoped with `--select-tag sample-otel-datadog`, only the
tagged sample Plugin is deleted — everything else on the control plane is
left untouched, and telemetry export stops immediately for all traffic.

---

## Summary of the safety rule

| Command | Scope | Safe against a live/shared control plane? |
|---|---|---|
| `deck gateway sync opentelemetry-datadog-sample.yaml` (no tag) | Entire control plane made to match this one file | ❌ No — deletes unrelated config |
| `deck gateway sync opentelemetry-datadog-sample.yaml --select-tag sample-otel-datadog` | Only objects tagged `sample-otel-datadog` | ✅ Yes |

Always use `--select-tag sample-otel-datadog` (for `diff`, `sync`, and
`dump`) when working with this sample file.
