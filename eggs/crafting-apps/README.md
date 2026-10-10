# Crafting Apps (Phoenix / Wings egg)

This repository is the public source for the Wings container image `ghcr.io/ttgdevx/crafting-apps`. GitHub Actions builds `eggs/crafting-apps/Dockerfile` (workflow `.github/workflows/crafting-apps-image.yml` at the repo root, build context `eggs/crafting-apps`) and publishes to GitHub Container Registry. The egg JSON in this folder points at that image.

One egg, one server, one app. The egg installs a Storytold Crafting App chosen by the `APP` startup variable. Change `APP` (or `MODE` / `VERSION`) and reinstall. The same egg and the same script replace the served app. This is not a game egg and it does not copy one.

Access is private. The server listens on the Wings allocation (`${SERVER_PORT}`). The operator exposes that port with Tailscale. There is no user database and no web login page; native mode adds only noVNC's VNC password.

## What you get

| File | Role |
|---|---|
| `crafting-apps.sh` | Source of truth. Install fetches and unpacks. Start serves. |
| `Dockerfile` | Builds `ghcr.io/ttgdevx/crafting-apps` (static server, Xvfb, noVNC, native libraries, vulkan-loader). |
| `egg-crafting-apps.json` | PTDL_v2 egg. Name: **Crafting Apps**. The install script is `crafting-apps.sh` verbatim. |

Startup command: `/usr/local/bin/crafting-apps start`

Install container: `debian:bookworm-slim` (the script installs `curl`, `ca-certificates`, `jq`, `unzip`). It writes the selected app into `/mnt/server`, which Wings mounts as `/home/container`.

## Publish the image, import the egg, set variables, reinstall

### Registry image (recommended)

1. In this repository, add a secret named `GHCR_TOKEN`: a GitHub PAT with `write:packages` on the **TTGDevX** org. `GITHUB_TOKEN` from a repo outside TTGDevX cannot push to `ghcr.io/ttgdevx/...`.
2. Push to `main` or run the **Build and publish crafting-apps image** workflow (`workflow_dispatch`). The workflow pushes `ghcr.io/ttgdevx/crafting-apps:latest` and `ghcr.io/ttgdevx/crafting-apps:<short-sha>` for `linux/amd64`.
3. In GitHub → **Packages** → `crafting-apps`, set package visibility to **Public** once. Wings nodes pull the image anonymously; a private package fails on nodes without registry credentials.

The egg's Docker image is `ghcr.io/ttgdevx/crafting-apps:latest`. Wings pulls it from GHCR when you create or reinstall a server.

### Local build fallback

If you are developing the egg or cannot use GHCR, build on the Wings node (or any host Wings can pull from):

```bash
docker build -t crafting-apps:latest eggs/crafting-apps
```

Tag the result as `crafting-apps:latest` locally, or change `docker_images` in `egg-crafting-apps.json` to match your tag.

Import `egg-crafting-apps.json` in the Phoenix / Pterodactyl panel (Admin → Nests → Import egg). Create a server, set the variables, and install.

| Variable | Default | Values |
|---|---|---|
| `APP` | `photocraft` | `photocraft`, `vectorcraft`, `filmcraft`, `lightcraft`, `pdfcraft`, `effectcraft`, `designcraft` |
| `MODE` | `web` | `web` or `native` |
| `VERSION` | `latest` | `latest`, or a GitHub release tag such as `v0.5.0` |
| `GPU` | `false` | `true`, `false`, `1`, `0` |
| `CONTROL_PORT` | `7878` | Integer 1–65535. Native mode only. Not a Wings allocation. |

`VERSION=latest` is resolved once, at install, from `https://api.github.com/repos/storytold/<app>/releases/latest`. A restart does not float to a newer tag. Reinstall to pick up a new latest. A leading `v` is the tag (`v0.5.0` requests that tag). The script does not invent a `v` prefix for a version that does not have one.

Reinstall after changing `APP`, `MODE`, or `VERSION`. Install downloads only the one asset for the selected mode, caches it under `/home/container/.cache/<app>/<mode>/<tag>/`, and replaces `/home/container/www` (web) or `/home/container/app` (native). The cache key includes app, mode, and the resolved tag, so switching does not reuse the wrong archive.

## Release verification

Storytold releases publish `SHA256SUMS.txt` (checked on photocraft v0.5.0). Install downloads it and checks the selected asset with `sha256sum`. This is an integrity check against the checksums published in the same release, not signature verification; a mismatch or a missing entry aborts the install and removes the cached file. If a release has no SHA256SUMS, the script logs that the asset is unverified beyond the GitHub host allowlist and the archive test, and continues.

## Tailscale

`tailscale serve --help` was not available in the environment that wrote this egg. Current Tailscale (CLI rewritten in 1.52; checked against the [serve reference](https://tailscale.com/docs/reference/tailscale-cli/serve)) proxies to a local URL and serves HTTPS on 443 by default:

```bash
tailscale serve --bg --https=443 http://127.0.0.1:${SERVER_PORT}
```

The short form does the same thing, because HTTPS on 443 is the default listener:

```bash
tailscale serve --bg http://127.0.0.1:${SERVER_PORT}
```

Run that on the Wings node (or on a tailnet machine that can reach the allocation). Use the server's allocation port, not `CONTROL_PORT`.

## Why there is no login

The trust boundary is the tailnet, or a tailnet-only bind. Tailscale already authenticates the viewer. These tools do not have a user database, and this egg does not add one or a web login page. Web mode has no login. Native mode has only noVNC's own VNC password (see Native mode), which is a second layer. Tailscale is the outer gate. Do not add another login page in front of the allocation.

## Web mode

`MODE=web` unpacks `<app>-web-<version>.zip` into `/home/container/www` (a single top-level directory in the zip is hoisted) and serves it with Caddy on `0.0.0.0:${SERVER_PORT}`.

Response headers:

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- `Cross-Origin-Resource-Policy: same-origin` (so those COEP headers do not block the wasm preload)
- `.wasm` is `application/wasm`

No native binary, no Xvfb, no noVNC. This build uses the browser GPU (WebGPU, WebGL2 fallback). The node GPU is not used. The log says that.

Web mode needs HTTPS or localhost for WebGPU. Tailscale HTTPS on 443 is a secure context. Plain HTTP to a public IP falls back to WebGL2 inside the app.

## Native mode

`MODE=native` unpacks `<app>-<version>-linux-x86_64.tar.gz` into `/home/container/app`. Current tarballs contain `bin/<app>` and `bin/<app>-cli`.

The panel allocation is a browser desktop: Xvfb plus x11vnc on `127.0.0.1:5900` plus websockify/noVNC on `0.0.0.0:${SERVER_PORT}`. Open `/vnc.html` (autoconnect: `/vnc.html?autoconnect=1&resize=scale`). x11vnc runs with `-rfbauth /home/container/.vnc-passwd`, not `-nopw`. On first native start the script creates a random per-server password (8 printable characters from `openssl rand -base64 6`, about 48 bits), stores the plain text in `/home/container/.vnc-password` and the x11vnc hash in `/home/container/.vnc-passwd` (umask 077, mode `0600`), and logs the path (not the password). The hash is written with the password on stdin, not argv. Read the password in the panel file manager: open `.vnc-password`. Only the hash file `.vnc-passwd` is in the egg's `file_denylist`. noVNC prompts for it. Delete both files and restart to rotate. An 8-character VNC password is a second layer, not a substitute for access control: keep the allocation reachable only over Tailscale.

The control port stays on loopback. These releases accept `--control <port>` and bind `127.0.0.1` themselves. Passing `127.0.0.1:7878` is not a valid port (PhotoCraft `parse_control_port` rejects it and exits 2), so the script passes the numeric `CONTROL_PORT` only. `CONTROL_PORT` is not a Wings allocation and nothing listens on `0.0.0.0` for it.

When the binary contains the flags (PhotoCraft v0.5.0 does; the other apps' current release tags do not), the GUI is started with:

```text
--control ${CONTROL_PORT}
--control-token-file /home/container/.control-token
--automation-read-root /home/container
--automation-write-root /home/container
```

The token file is created with `openssl rand -hex 32` if missing, mode `0600`. The token is not printed. Apps that do not have those flags are started with `--control ${CONTROL_PORT}` only, and the script logs that. File open/save over `--control` is refused (`file.open`, `file.save`, `file.saveAs`, and other ambient path commands). Batch work goes through `<app>-cli` (`<app>-cli run`, `<app>-cli batch`). The script starts `<app>-cli mcp` only when that binary is in the tarball. If it is absent, it logs and continues.

## GPU

The image always includes vulkan-loader (`libvulkan1`) and Mesa's lavapipe ICD. The image build does not need a GPU.

`GPU=true` means the host should expose `/dev/dri` (AMD/Intel) or run the container with the NVIDIA container runtime. If those device nodes are missing, install and startup log `GPU=true but /dev/dri and NVIDIA devices are missing; continuing with the CPU compositor.` and keep going on llvmpipe. Install does not fail because a device is absent. `GPU=false` does not look for a device.

In `MODE=web`, ignore the node GPU. The browser uses WebGPU or WebGL2.

## Asset names

Queried from `https://api.github.com/repos/storytold/<repo>/releases/latest` and `/releases/tags/v0.5.0`.

Tags keep the leading `v` (`v0.5.0`). The published filenames strip it (`photocraft-web-0.5.0.zip`, `photocraft-0.5.0-linux-x86_64.tar.gz`). The script tries the stripped name, then the tag unchanged. It downloads that one asset, not the whole release. It does not substitute a different app's file.

| App | Latest tag | Web zip on latest | Native tarball on latest | Tag `v0.5.0` |
|---|---|---|---|---|
| photocraft | `v0.5.0` | `photocraft-web-0.5.0.zip` | `photocraft-0.5.0-linux-x86_64.tar.gz` | Exists. Same assets as latest. |
| vectorcraft | `v0.7.0` | `vectorcraft-web-0.7.0.zip` | `vectorcraft-0.7.0-linux-x86_64.tar.gz` | Exists. `vectorcraft-web-0.5.0.zip` and `vectorcraft-0.5.0-linux-x86_64.tar.gz`. |
| filmcraft | `v0.4.0` | `filmcraft-web-0.4.0.zip` | `filmcraft-0.4.0-linux-x86_64.tar.gz` | **No such release** (HTTP 404). Latest **does** have a web zip. |
| lightcraft | `v0.4.0` | `lightcraft-web-0.4.0.zip` | `lightcraft-0.4.0-linux-x86_64.tar.gz` | **No such release.** Latest has a web zip. |
| pdfcraft | `v0.4.0` | `pdfcraft-web-0.4.0.zip` | `pdfcraft-0.4.0-linux-x86_64.tar.gz` | **No such release.** Latest has a web zip. |
| effectcraft | `v0.6.0` | `effectcraft-web-0.6.0.zip` | `effectcraft-0.6.0-linux-x86_64.tar.gz` | **No such release.** Latest has a web zip. |
| designcraft | `v0.4.0` | `designcraft-web-0.4.0.zip` | `designcraft-0.4.0-linux-x86_64.tar.gz` | **No such release.** Latest has a web zip. |

PdfCraft tags `v0.1.0`, `v0.1.1`, `v0.2.0`, and `v0.2.1` publish `printcraft-*` files (for example `printcraft-web-0.2.1.zip` and `printcraft-0.2.1-linux-x86_64.tar.gz`). There is no `pdfcraft-web-0.2.1.zip`. `APP=pdfcraft` `MODE=web` `VERSION=v0.2.1` fails with a clear log line and does not install PrintCraft or leave a `www` tree. `v0.4.0` is the first PdfCraft release whose assets use the `pdfcraft-` names.

The Linux tarball includes `<app>` and `<app>-cli` (verified for PhotoCraft v0.5.0: `bin/photocraft`, `bin/photocraft-cli`). A separate `*-cli-*-macos-universal.zip` exists on these releases and is not downloaded.
