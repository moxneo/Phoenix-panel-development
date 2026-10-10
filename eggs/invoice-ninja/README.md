# Invoice Ninja v5 (Octane)

Invoice Ninja v5 (Octane/FrankenPHP) with all writable data under `/home/container`. Start Redis first; use `LARAVEL_ROLE=app` for web, `worker` for queues, `scheduler` for cron.

**Image note:** `ghcr.io/moxneo/invoice-ninja:latest` is a placeholder and may not be published yet. The image must provide `/usr/local/bin/entrypoint.sh`. Fill in `APP_KEY`, `APP_URL`, DB and mail settings before first start.

## Import

In your panel: Admin → Nests → Import Egg, then select `egg-invoice-ninja.json`.

## Images

- Invoice Ninja - latest: `ghcr.io/moxneo/invoice-ninja:latest`

Author: Mox Neo
