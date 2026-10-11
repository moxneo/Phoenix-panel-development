# Odoo (External DB)

Odoo 16/17/18 against an external PostgreSQL server. Writes `start.sh` at install time; `start.sh` validates every panel value and regenerates `odoo.conf` on each start; supports an optional Git addons repo. Set `DB_HOST`, `DB_PASSWORD` and `ODOO_ADMIN_PASSWD` before installing.

## Security defaults

- `list_db = False`: the web database manager (`/web/database/*`: create, drop, backup, restore) is disabled. Manage databases with `psql`/`pg_dump` or the `odoo` CLI.
- `dbfilter = ^<DB_NAME>$` and `db_name = <DB_NAME>`: the server only serves its own database.
- Every value written to `odoo.conf` is checked for line breaks and against a strict pattern (hosts, users, DB name, ports, numeric limits). An invalid value stops the start with a clear message instead of writing a broken or injected config.
- `odoo.conf` is regenerated on every start, so panel changes apply on restart. Existing servers need a **Reinstall** to get the new `start.sh`.

The `ADDONS_GIT_*` variables are defined but not used by this egg's scripts yet.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-odoo.json`.

## Images

- ODOO: `ghcr.io/scriptjunkiedev/ptero-odoo:odoo-16-sha-d42b22c2baeced2fb33366fa2d1c8c8bb86c3b82@sha256:e17e6daa…` (digest-pinned)

Author: Mox Neo
