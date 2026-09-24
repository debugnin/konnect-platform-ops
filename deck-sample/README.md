# Testing the Gateway with a Sample decK Config (httpbin.konghq)

This walkthrough loads a small, self-contained decK state file against your
Konnect control plane so you can confirm the Cloud Gateway data plane is
routing traffic correctly, using Kong's public test service,
`https://httpbin.konghq.com`.

Files in this folder:

| File | Purpose |
|---|---|
| `httpbin-sample.yaml` | The sample decK state: one Service, one Route, one Plugin, all tagged `sample-httpbin` |
| `README.md` | This document |

---

## ⚠️ Read this before running `deck gateway sync`

`deck gateway sync` makes the target control plane's configuration **match
the file(s) you give it exactly**. Anything already configured on the
control plane that is *not* present in the file you sync will be **deleted**.

If you run `deck gateway sync httpbin-sample.yaml` against a control plane
that already has other Services/Routes/Plugins/Consumers, decK will remove
all of that existing configuration, because it isn't in this sample file.

**This is why the sample file only ever gets synced using `--select-tag`.**
Tag-scoped sync tells decK: "only manage the objects tagged
`sample-httpbin`; leave everything else on the control plane alone." Every
object in `httpbin-sample.yaml` is tagged `sample-httpbin` for exactly this
reason — do not remove the tags.

Never run a bare `deck gateway sync httpbin-sample.yaml` (without
`--select-tag`) against a control plane that has real/other configuration on
it. Only do that against a throwaway/empty control plane you don't mind
being wiped down to just this file.

---

## Prerequisites

- [decK](https://developer.konghq.com/deck/installation/) installed (`deck version` to check)
- A Konnect Personal Access Token (PAT) with permission to manage the target
  control plane — the same `KONNECT_TOKEN` used by the Terraform config in
  `konnect-platform-ops/`
- The name of the Konnect control plane to target (from
  `control-plane.tf`, that's `"Konnect Control Plane"`)
- Network path from wherever you run `deck` to the Konnect Cloud API
  (`https://au.api.konghq.com`, since this control plane's geo is `au`)

Export your token (same variable already used by Terraform):

```bash
export KONNECT_TOKEN="kpat_..."
```

---

## Step 1 — Sanity-check connectivity

Confirm decK can reach the control plane before changing anything:

```bash
deck gateway ping \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane"
```

You should see a success message identifying the control plane and Kong
Gateway version running on the data plane.

---

## Step 2 — Preview the change with `diff`

Always diff before syncing. This shows exactly what decK *would* create,
without changing anything:

```bash
deck gateway diff httpbin-sample.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-httpbin
```

Expect to see one Service (`httpbin-sample-service`), one Route
(`httpbin-sample-route`), and one Plugin (`request-transformer`) listed as
being created. If the diff shows unrelated resources being deleted, **stop**
— it means `--select-tag` wasn't applied, or the tag doesn't match what's on
the control plane already.

---

## Step 3 — Load the sample config

```bash
deck gateway sync httpbin-sample.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-httpbin
```

decK will report the objects created (or updated, on a re-run).

> Tip: to avoid retyping the Konnect flags, you can put them in
> `$HOME/.deck.yaml` or export them as environment variables
> (`DECK_KONNECT_TOKEN`, `DECK_KONNECT_ADDR`,
> `DECK_KONNECT_CONTROL_PLANE_NAME`). `--select-tag` has no environment
> variable equivalent and must still be passed on the command line every
> time, to keep the "only touch tagged resources" guardrail explicit.

---

## Step 4 — Verify the route works

Send a request through the data plane's proxy endpoint (the DNS name /
private endpoint for this control plane's Cloud Gateway — see the Konnect
UI under **Gateway Manager > \<control plane\> > Overview** for the exact
proxy hostname, since this configuration uses `api_access = "private"` and
has no public listener):

```bash
curl -i https://<data-plane-proxy-host>/httpbin-sample/get
```

Expected result:
- `HTTP/1.1 200 OK`
- A JSON body echoed back by httpbin, including the header
  `x-deck-sample: httpbin` under `"headers"` (proof the
  `request-transformer` plugin fired)

You can also confirm the objects exist directly:

```bash
deck gateway dump \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-httpbin
```

This should print back the same Service/Route/Plugin from
`httpbin-sample.yaml` and nothing else.

---

## Step 5 — Clean up (optional)

To remove just the sample objects without touching anything else, sync an
empty file scoped to the same tag:

```bash
echo '_format_version: "3.0"' > empty.yaml

deck gateway sync empty.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr https://au.api.konghq.com \
  --konnect-control-plane-name "Konnect Control Plane" \
  --select-tag sample-httpbin
```

Because the sync is still scoped with `--select-tag sample-httpbin`, only
the tagged sample Service/Route/Plugin are deleted — everything else on the
control plane is left untouched.

---

## Summary of the safety rule

| Command | Scope | Safe against a live/shared control plane? |
|---|---|---|
| `deck gateway sync httpbin-sample.yaml` (no tag) | Entire control plane made to match this one file | ❌ No — deletes unrelated config |
| `deck gateway sync httpbin-sample.yaml --select-tag sample-httpbin` | Only objects tagged `sample-httpbin` | ✅ Yes |

Always use `--select-tag sample-httpbin` (for `diff`, `sync`, and `dump`)
when working with this sample file.
