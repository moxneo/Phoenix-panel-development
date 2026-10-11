# Hermes Agent v3

Hermes Agent v3, dashboard-first. A random admin password is generated on first start and written to `FIRST_LOGIN.txt`; you must change it on first login. No API keys in the panel.

## First-run setup (security)

Until you set your own password, the dashboard port serves only a small first-run setup page. That page is reachable on the allocation (0.0.0.0) because Wings only forwards the allocation port, so binding it to loopback would lock you out too. To stop whoever reaches the port first from taking over the server, the page requires the **one-time password** that was generated for this server:

1. Open `/home/container/FIRST_LOGIN.txt` in the panel file manager (it is only written there, never to the console).
2. Open `http://<allocation-ip>:<port>/`, enter that one-time password, then your new password twice (at least 12 characters).
3. The one-time password is checked in constant time; wrong values get HTTP 403. Cross-origin form posts (an `Origin` header that does not match the host) are refused.
4. On success `FIRST_LOGIN.txt` and the setup marker are deleted and the normal dashboard (HTTP basic auth, user `admin`) starts.

The setup page is plain HTTP. If the network between you and the node is untrusted, do the first-run step over a tunnel (Cloudflare/Tailscale eggs) or an SSH port forward.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-hermes-agent-v3.json`.

## Images

- Debian 12: `ghcr.io/ptero-eggs/yolks:debian`

Author: Mox Neo
