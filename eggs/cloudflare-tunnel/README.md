# Cloudflare tunnel

Outbound-only Cloudflare Tunnel connector. Installs a pinned, checksum-verified `cloudflared` release. Paste your tunnel token into `TUNNEL_TOKEN`; no ports are published.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-cloudflare-tunnel.json`.

## Images

- Debian: `ghcr.io/parkervcp/yolks:debian@sha256:47174f48…` (multi-arch index digest, pinned). Install container: `ghcr.io/pterodactyl/installers:alpine` (digest-pinned).

Author: Mox Neo
