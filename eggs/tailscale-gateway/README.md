# Tailscale gateway

Official `tailscale/tailscale` container (containerboot). Set `TS_AUTHKEY` (from your Tailscale admin console) to join your tailnet; `TS_HOSTNAME` sets the node name.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-tailscale-gateway.json`.

## Images

- Tailscale 1.102.5 (default, pinned): `tailscale/tailscale:v1.102.5@sha256:c507f3a2…` (multi-arch index digest)
- Tailscale stable (unpinned, opt-in): `tailscale/tailscale:stable`

The egg has no install script; its install container is a current, digest-pinned `alpine:3.22` (was the EOL `alpine:3.4`).

Author: Mox Neo
