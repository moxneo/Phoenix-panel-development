# Listmonk

Listmonk newsletter / mailing-list manager using the official image and an external PostgreSQL database. Set the admin and database credentials before first start.

## Admin account

Listmonk never starts with a blank admin password, because a blank one lets the first visitor create the admin. If `LISTMONK_ADMIN_PASSWORD` is set it must be at least 12 characters. If it is blank, `start.sh` generates a random one on first start, saves it in `/home/container/.listmonk-admin-password`, and writes the login to `/home/container/FIRST_LOGIN.txt` (mode 0600, not printed to the console). Change the password in Listmonk after logging in, then delete `FIRST_LOGIN.txt`. Existing servers need a **Reinstall** to get `start.sh`.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-listmonk.json`.

## Images

- Listmonk 6.1.0 (default, pinned): `listmonk/listmonk:v6.1.0@sha256:179d00d9…` (multi-arch index digest)
- Listmonk latest (unpinned, opt-in): `listmonk/listmonk:latest`

Author: Mox Neo
