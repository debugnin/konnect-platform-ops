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
