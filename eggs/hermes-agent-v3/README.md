# Hermes Agent v3

Hermes Agent v3, dashboard-first. A random admin password is generated on first start and written to `FIRST_LOGIN.txt`; you must change it on first login. No API keys in the panel.

## First-run setup (security)

Until you set your own password, the dashboard port serves only a small first-run setup page. That page is reachable on the allocation (0.0.0.0) because Wings only forwards the allocation port, so binding it to loopback would lock you out too. To stop whoever reaches the port first from taking over the server, the page requires the **one-time password** that was generated for this server:

1. Open `/home/container/FIRST_LOGIN.txt` in the panel file manager (it is only written there, never to the console).
2. Open `http://<allocation-ip>:<port>/`, enter that one-time password, then your new password twice (at least 12 characters).
3. The one-time password is checked in constant time; wrong values get HTTP 403. Cross-origin form posts (an `Origin` header that does not match the host) are refused.
4. On success `FIRST_LOGIN.txt` and the setup marker are deleted and the normal dashboard (HTTP basic auth, user `admin`) starts.

The setup page is plain HTTP. If the network between you and the node is untrusted, do the first-run step over a tunnel (Cloudflare/Tailscale eggs) or an SSH port forward.

## Upstream pinning

The upstream installer is fetched by full commit SHA (`HERMES_VERSION`, default `f97608f178d1ffeca59860195ab7da295f7c8e5f` = tag `v2026.9.24`) and its sha256 is checked against `HERMES_INSTALL_SHA256` before it runs. A mismatch or a non-SHA value stops the start. To upgrade, an admin sets both variables (new commit SHA, and `sha256sum` of `scripts/install.sh` at that commit). `SERVER_PORT` comes from the allocation and is not user-editable.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-hermes-agent-v3.json`.

## Images

- Debian 12: `ghcr.io/ptero-eggs/yolks:debian@sha256:3a31e5b2…` (multi-arch index digest, pinned)

Author: Mox Neo
