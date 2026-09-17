provider "konnect" {
  # Personal access token comes from the provider's PAT auth attribute /
  # env var (configured outside this file).
  # Region: AU. The provider appends versioned paths itself, so do not
  # include a `/v2` (or any other version) suffix on server_url.
  server_url = "https://au.api.konghq.com"
}
