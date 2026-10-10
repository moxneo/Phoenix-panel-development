# Odoo (External DB)

Odoo 16/17/18 against an external PostgreSQL server. Writes `start.sh` and `odoo.conf` at install time; supports an optional Git addons repo. Set `DB_HOST`, `DB_PASSWORD` and `ODOO_ADMIN_PASSWD` before installing.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-odoo.json`.

## Images

- ODOO: `ghcr.io/scriptjunkiedev/ptero-odoo:odoo-16-sha-d42b22c2baeced2fb33366fa2d1c8c8bb86c3b82`

Author: Mox Neo
