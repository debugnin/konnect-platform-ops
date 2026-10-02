# Transforming an upstream error response: jq vs. Datakit vs. response-transformer-advanced

These three examples all solve the same problem — reshaping a JSON:API-style
upstream error response, optionally merged with a request header, into a
flat custom error object:

**Upstream response** (e.g. a 404 from the backend service):
```json
{
  "jsonapi": { "version": "1.0" },
  "errors": [
    { "status": 404, "title": "some content", "detail": "some content", "id": "some id" }
  ]
}
```

**Desired response returned to the client:**
```json
{
  "errorCode": 404,
  "errorDetail": "some content",
  "correlationId": "abc-123"
}
```

Each file is a self-contained decK state file (its own Service/Route/tag) —
there's no shared dependency between them, so you can sync any one in
isolation to compare behavior.

## Which one should I use?

| | `jq` | Datakit | `response-transformer-advanced` |
|---|---|---|---|
| File | [`jq-error-transform.yaml`](./jq-error-transform.yaml) | [`datakit-error-transform.yaml`](./datakit-error-transform.yaml) | [`response-transformer-advanced-error-transform.yaml`](./response-transformer-advanced-error-transform.yaml) |
| Requires Lua? | No | No | **Yes** |
| Can reshape the body? | Yes | Yes | Yes |
| Can read a request header into the response? | **No** | Yes | Yes |
| Produces `correlationId`? | **No** | Yes | Yes |
| Config style | Single `jq` filter string | Declarative node graph, `jq` filter per node | Lua function |
| Min Kong Gateway version | — | **3.11+** (Enterprise) | — |
| Tier | Enterprise | Enterprise | Enterprise |

**Bottom line:**
- If you only need to reshape the **body** (no header merge), use **`jq`** — it's the simplest config of the three.
- If you need to merge a **header value into the response body** without writing Lua, use **Datakit**.
- **`response-transformer-advanced`**'s declarative options (`add`/`rename`/`replace`/`remove`/`append`) can't restructure a nested array into new top-level fields *and* read a header value in the same step — a Lua function is required to do both. It's shown here mainly as a comparison baseline against the no-Lua options.

## Shared caveats across all three

1. **Content-Type gating.** All three plugins only treat the body as JSON
   (and run their transform) when the upstream response's `Content-Type`
   matches a JSON-ish media type (`application/json` by default). JSON:API
   responses are often served as `application/vnd.api+json`. Each example
   file lists/handles this where applicable, but **test against your real
   upstream's actual response headers** before relying on this in a
   customer-facing demo.
2. **Status code scoping.** The `jq` plugin in particular defaults to only
   running on `200` responses (`response_if_status_code: [200]`) — the
   example explicitly adds `404`. Make sure you list every status code you
   want transformed.
3. **These are illustrative, not interchangeable 1:1.** `jq-error-transform.yaml`
   intentionally omits `correlationId` since `jq` can't produce it — see the
   comments in that file for why.

## Trying them out

Each file routes through `httpbin.konghq.com` purely as a stand-in upstream
(it won't actually return a JSON:API-shaped error — you'd need a real
upstream or a mock to see the full transform fire end-to-end). Point
`url:` at your actual backend service to validate against a real response.

```bash
deck gateway diff <file>.yaml \
  --konnect-token "$KONNECT_TOKEN" \
  --konnect-addr <your-konnect-addr> \
  --konnect-control-plane-name "<your control plane>" \
  --select-tag <example-tag-from-the-file>
```

Two verification setups are included in this directory:

- [`local-dataplane/`](./local-dataplane) — a DB-less Kong Gateway in Docker,
  config applied straight from a mounted `kong.yaml` file. Fastest way to
  smoke-test routing/plugin wiring with no Konnect dependency.
- [`hybrid-dataplane/`](./hybrid-dataplane) — a Kong Gateway Docker container
  joined to a real Konnect Control Plane in **hybrid mode** (mTLS, pinned
  client certificate), with the same 3 services/routes/plugins pushed via
  `deck gateway sync`. Use this when you want to validate against an actual
  Konnect-managed control plane instead of a static local file.

## ⚠️ Datakit finding: hard 500 on non-JSON upstream responses

While verifying these against both local setups, **Datakit's implicit
`service_response.body` dependency throws a hard 500** (instead of failing
open, like `jq` and `response-transformer-advanced` do) whenever the
upstream returns a non-JSON `Content-Type` — e.g. `httpbin.konghq.com`'s
plain-text/empty 404 response (`text/html; charset=utf-8`). The error:

```
node service_response failed with error: "failed reading service response
body: unsupported content type 'text/html; charset=utf-8'"
```

**Confirmed this is NOT fixable with a `branch` node guard.** A `branch`
node only controls which named nodes get *scheduled*; it doesn't remove the
underlying data dependency. Even with the body-reading node gated behind a
`Content-Type` check in a `branch`'s `then:` list, Datakit still eagerly
resolves `service_response.body`/`service_response.raw_body` for the whole
request as soon as *any* node in the graph declares that dependency — and
that eager read still throws on a non-JSON Content-Type regardless of
whether the gated node ends up running. (`service_response.headers` and
`service_response.status` are safe to read and don't trigger this.)

**Practical takeaway for customer conversations:** if the real upstream can
ever return a non-JSON body on an error path (crashed app, maintenance
page, misconfigured proxy, plain-text 502/503, etc.), Datakit will 500
instead of passing the response through — this is a materially different
failure mode than `jq` or `response-transformer-advanced`, and worth calling
out explicitly if Datakit is the chosen approach. See the comment block at
the top of [`datakit-error-transform.yaml`](./datakit-error-transform.yaml)
for full details and mitigation options.
