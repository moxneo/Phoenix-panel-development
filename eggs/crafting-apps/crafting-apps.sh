#!/bin/bash
# Crafting Apps — one Wings install/start script for every Storytold app.
# Source of truth for eggs/crafting-apps/egg-crafting-apps.json (installation
# script is this file) and for the image at /usr/local/bin/crafting-apps.
set -euo pipefail

UA="crafting-apps-egg/1.0"
API_BASE="https://api.github.com"

log() {
  echo "[crafting-apps] $*"
}

die() {
  echo "[crafting-apps] FATAL: $*" >&2
  exit 1
}

gpu_present() {
  [[ -e /dev/dri/card0 || -e /dev/dri/renderD128 || -e /dev/nvidia0 || -e /dev/nvidiactl ]]
}

log_gpu() {
  case "$GPU" in
    true|1)
      if gpu_present; then
        log "GPU=true and a GPU device node is present."
      else
        log "GPU=true but /dev/dri and NVIDIA devices are missing; continuing with the CPU compositor."
      fi
      ;;
    false|0)
      log "GPU=false; GPU devices are not required."
      ;;
  esac
}

# ponytail: CPU llvmpipe/lavapipe when no device node is passed in.
# Upgrade path: expose /dev/dri (AMD/Intel) or the NVIDIA container runtime and set GPU=true.
apply_cpu_compositor() {
  case "$GPU" in
    true|1)
      if gpu_present; then
        log "GPU=true and a device node is present; not forcing the CPU compositor."
        return 0
      fi
      log "GPU=true but /dev/dri and NVIDIA devices are missing; continuing with the llvmpipe CPU compositor."
      ;;
    false|0)
      log "GPU=false; using the llvmpipe CPU compositor."
      ;;
  esac
  export LIBGL_ALWAYS_SOFTWARE=1
  export GALLIUM_DRIVER=llvmpipe
  local lvp="/usr/share/vulkan/icd.d/lvp_icd.x86_64.json"
  if [[ -f "$lvp" ]]; then
    # Keep a missing host device out of the process. lavapipe is the software ICD.
    export VK_DRIVER_FILES="$lvp"
    export VK_ICD_FILENAMES="$lvp"
  fi
}

validate() {
  case "${APP:-}" in
    photocraft|vectorcraft|filmcraft|lightcraft|pdfcraft|effectcraft|designcraft) ;;
    *) die "APP must be one of photocraft, vectorcraft, filmcraft, lightcraft, pdfcraft, effectcraft, designcraft" ;;
  esac

  case "${MODE:-}" in
    web|native) ;;
    *) die "MODE must be web or native" ;;
  esac

  VERSION="${VERSION:-latest}"
  if [[ "$VERSION" != "latest" && ! "$VERSION" =~ ^[A-Za-z0-9._-]{1,128}$ ]]; then
    die "VERSION must be latest or a GitHub tag (letters, digits, dot, underscore, hyphen)"
  fi

  GPU="${GPU:-false}"
  case "$GPU" in
    true|false|1|0) ;;
    *) die "GPU must be true, false, 1, or 0" ;;
  esac

  if [[ -z "${CONTROL_PORT:-}" ]]; then
    CONTROL_PORT=7878
  fi
  if [[ ! "$CONTROL_PORT" =~ ^[1-9][0-9]{0,4}$ ]] || (( 10#$CONTROL_PORT < 1 || 10#$CONTROL_PORT > 65535 )); then
    die "CONTROL_PORT must be an integer from 1 to 65535"
  fi
}

require_server_port() {
  if [[ -z "${SERVER_PORT:-}" ]]; then
    die "SERVER_PORT is not set"
  fi
  if [[ ! "$SERVER_PORT" =~ ^[1-9][0-9]{0,4}$ ]] || (( 10#$SERVER_PORT < 1 || 10#$SERVER_PORT > 65535 )); then
    die "SERVER_PORT must be an integer from 1 to 65535"
  fi
}

ensure_fetch_tools() {
  if command -v curl >/dev/null && command -v jq >/dev/null && command -v unzip >/dev/null && command -v tar >/dev/null; then
    return 0
  fi
  if [[ "$(id -u)" -ne 0 ]]; then
    die "curl, jq, unzip, and tar are required to install"
  fi
  log "installing curl, ca-certificates, jq, unzip, tar"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends curl ca-certificates jq unzip tar
}

fetch_release_json() {
  local url="$1"
  local body_file code
  body_file=$(mktemp)
  code=$(curl -sS -L --retry 3 --retry-delay 2 -A "$UA" -H "Accept: application/vnd.github+json" -o "$body_file" -w "%{http_code}" "$url" || true)
  if [[ "$code" != "200" ]]; then
    echo "[crafting-apps] FATAL: missing release or HTTP ${code} fetching ${url}" >&2
    head -c 400 "$body_file" >&2 || true
    echo >&2
    rm -f "$body_file"
    exit 1
  fi
  if ! jq -e '.tag_name' "$body_file" >/dev/null; then
    rm -f "$body_file"
    die "GitHub response from ${url} has no tag_name"
  fi
  cat "$body_file"
  rm -f "$body_file"
}

resolve_release() {
  local url
  if [[ "$VERSION" == "latest" ]]; then
    url="${API_BASE}/repos/storytold/${APP}/releases/latest"
  else
    url="${API_BASE}/repos/storytold/${APP}/releases/tags/${VERSION}"
  fi
  log "resolving ${APP} ${VERSION} from ${url}"
  release_json=$(fetch_release_json "$url")
  tag=$(jq -r '.tag_name' <<<"$release_json")
  if [[ ! "$tag" =~ ^[A-Za-z0-9._-]{1,128}$ ]]; then
    die "refusing unexpected release tag: ${tag}"
  fi
  # Tags are v0.5.0. Asset names on these repos drop the leading v (0.5.0).
  # Try the stripped form first, then the tag unchanged if a release keeps the v.
  ver="${tag#v}"
  if [[ "$MODE" == "web" ]]; then
    candidates=("${APP}-web-${ver}.zip")
    if [[ "$ver" != "$tag" ]]; then
      candidates+=("${APP}-web-${tag}.zip")
    fi
  else
    candidates=("${APP}-${ver}-linux-x86_64.tar.gz")
    if [[ "$ver" != "$tag" ]]; then
      candidates+=("${APP}-${tag}-linux-x86_64.tar.gz")
    fi
  fi
}

pick_asset() {
  local candidate url
  asset_name=""
  asset_url=""
  for candidate in "${candidates[@]}"; do
    url=$(jq -r --arg n "$candidate" 'first((.assets // [])[] | select(.name == $n) | .browser_download_url) // empty' <<<"$release_json")
    if [[ -n "$url" ]]; then
      asset_name="$candidate"
      asset_url="$url"
      return 0
    fi
  done
  return 1
}

reject_asset_url() {
  case "$asset_url" in
    https://github.com/*|https://release-assets.github.com/*|https://objects.githubusercontent.com/*|https://github-releases.githubusercontent.com/*)
      ;;
    *) die "refusing asset URL outside GitHub: ${asset_url}" ;;
  esac
}

die_no_asset() {
  echo "[crafting-apps] FATAL: release ${tag} of storytold/${APP} has no ${MODE} asset." >&2
  echo "[crafting-apps] looked for: ${candidates[*]}" >&2
  echo "[crafting-apps] not installing a different app." >&2
  if [[ "$MODE" == "web" ]]; then
    echo "[crafting-apps] MODE=web was not installed. No www tree was written." >&2
  else
    echo "[crafting-apps] MODE=native was not installed. No app tree was written." >&2
  fi
  jq -r '(.assets // [])[].name' <<<"$release_json" >&2 || true
  exit 1
}

download_asset() {
  local cache_dir cache_file code rc
  cache_dir="${ROOT}/.cache/${APP}/${MODE}/${tag}"
  cache_file="${cache_dir}/${asset_name}"
  mkdir -p "$cache_dir"
  if [[ -s "$cache_file" ]]; then
    log "cache hit ${cache_file}"
  else
    log "downloading ${asset_name}"
    log "url ${asset_url}"
    set +e
    code=$(curl -fL --retry 3 --retry-delay 2 -A "$UA" -o "${cache_file}.partial" -w "%{http_code}" "$asset_url")
    rc=$?
    set -e
    if [[ "$rc" -ne 0 || "$code" != "200" ]]; then
      rm -f "${cache_file}.partial"
      die "download failed for ${asset_name} (curl ${rc}, HTTP ${code:-none})"
    fi
    mv "${cache_file}.partial" "$cache_file"
  fi
  if [[ ! -s "$cache_file" ]]; then
    rm -f "$cache_file"
    die "archive ${asset_name} is empty"
  fi
  archive_path="$cache_file"
  verify_sha256
}

verify_sha256() {
  local sums_url sums expected actual
  sums_url=$(jq -r 'first((.assets // [])[] | select(.name == "SHA256SUMS.txt" or .name == "SHA256SUMS") | .browser_download_url) // empty' <<<"$release_json")
  if [[ -z "$sums_url" ]]; then
    log "release ${tag} has no SHA256SUMS; ${asset_name} is unverified beyond the host allowlist and archive test"
    return 0
  fi
  case "$sums_url" in
    https://github.com/*) ;;
    *) die "refusing SHA256SUMS URL outside GitHub: ${sums_url}" ;;
  esac
  sums=$(curl -fsSL --retry 3 --retry-delay 2 -A "$UA" "$sums_url") || die "could not download SHA256SUMS for ${tag}"
  expected=$(awk -v n="$asset_name" '{f=$2; sub(/^\*/, "", f)} f == n {print $1; exit}' <<<"$sums")
  if [[ ! "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
    die "SHA256SUMS for ${tag} has no entry for ${asset_name}"
  fi
  actual=$(sha256sum "$archive_path" | awk '{print $1}')
  if [[ "${actual,,}" != "${expected,,}" ]]; then
    rm -f "$archive_path"
    die "SHA256 mismatch for ${asset_name} (expected ${expected}, got ${actual}); cache entry removed"
  fi
  log "sha256 ok for ${asset_name}"
}

replace_tree() {
  local stage="$1"
  local dest="$2"
  local src_dir="$stage"
  local tmp="${dest}.new"
  shopt -s nullglob dotglob
  local entries=("$stage"/*)
  if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" ]]; then
    src_dir="${entries[0]}"
  fi
  local contents=("$src_dir"/*)
  shopt -u dotglob nullglob
  if [[ ${#contents[@]} -eq 0 ]]; then
    die "archive unpacked to an empty tree"
  fi
  rm -rf "$tmp"
  mkdir -p "$tmp"
  shopt -s dotglob nullglob
  mv "$src_dir"/* "$tmp"/
  shopt -u dotglob nullglob
  rm -rf "$dest"
  mv "$tmp" "$dest"
}

unpack_selected() {
  local stage="${ROOT}/.unpack"
  rm -rf "$stage"
  mkdir -p "$stage"
  if [[ "$MODE" == "web" ]]; then
    if ! unzip -t -qq "$archive_path"; then
      rm -f "$archive_path"
      rm -rf "$stage"
      die "web zip ${asset_name} failed unzip -t; cache entry removed"
    fi
    unzip -q "$archive_path" -d "$stage"
    replace_tree "$stage" "${ROOT}/www"
    rm -rf "${ROOT}/app" "$stage"
    log "replaced ${ROOT}/www with ${APP} ${tag} (${asset_name})"
  else
    if ! tar -tzf "$archive_path" >/dev/null; then
      rm -f "$archive_path"
      rm -rf "$stage"
      die "native tarball ${asset_name} is not readable; cache entry removed"
    fi
    tar -xzf "$archive_path" -C "$stage"
    replace_tree "$stage" "${ROOT}/app"
    rm -rf "${ROOT}/www" "$stage"
    if [[ -d "${ROOT}/app/bin" ]]; then
      chmod u+x "${ROOT}/app/bin/"* 2>/dev/null || true
    fi
    log "replaced ${ROOT}/app with ${APP} ${tag} (${asset_name})"
  fi
}

write_stamp() {
  printf '%s %s %s %s\n' "$APP" "$MODE" "$tag" "$asset_name" > "${ROOT}/.crafting-apps-release"
}

copy_self() {
  local src dest
  src="${BASH_SOURCE[0]}"
  dest="${ROOT}/crafting-apps.sh"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ "$(readlink -f "$src")" == "$(readlink -f "$dest" 2>/dev/null || true)" ]]; then
    return 0
  fi
  cp "$src" "$dest"
  chmod 0755 "$dest"
}

do_install() {
  log_gpu
  if [[ "$MODE" == "web" ]]; then
    log "MODE=web uses the browser GPU (WebGPU, with WebGL2 fallback). The node GPU is not used."
  fi
  ensure_fetch_tools
  resolve_release
  if ! pick_asset; then
    die_no_asset
  fi
  reject_asset_url
  mkdir -p "$ROOT"
  download_asset
  unpack_selected
  write_stamp
  copy_self
  log "install complete"
}

read_stamp() {
  local stamp="${ROOT}/.crafting-apps-release"
  if [[ ! -f "$stamp" ]]; then
    die "nothing installed in ${ROOT}; reinstall the server"
  fi
  read -r stamp_app stamp_mode stamp_tag stamp_asset < "$stamp"
  if [[ "$stamp_app" != "$APP" || "$stamp_mode" != "$MODE" ]]; then
    die "installed ${stamp_app} ${stamp_mode} does not match APP=${APP} MODE=${MODE}; reinstall the server"
  fi
  # ponytail: VERSION=latest is whatever tag install resolved into the stamp.
  # Restart does not ask GitHub again. Reinstall to move "latest".
  # Upgrade path: resolve /releases/latest on start and re-fetch when the tag changed.
  if [[ "$VERSION" != "latest" && "$stamp_tag" != "$VERSION" ]]; then
    die "installed tag ${stamp_tag} does not match VERSION=${VERSION}; reinstall the server"
  fi
  log "using installed ${stamp_app} ${stamp_mode} ${stamp_tag} (${stamp_asset})"
}

wait_http() {
  local url="$1"
  local i
  for ((i = 0; i < 100; i++)); do
    if curl -sf -o /dev/null --max-time 1 "$url"; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

write_caddyfile() {
  local dir="${ROOT}/.caddy"
  mkdir -p "$dir"
  cat > "${dir}/Caddyfile" <<EOF
{
	admin off
	persist_config off
	auto_https off
	storage file_system ${ROOT}/.caddy/data
}
# Plain HTTP on every interface, any Host header (Wings reaches it by node IP).
http://:${SERVER_PORT} {
	bind 0.0.0.0
	root * ${ROOT}/www
	encode gzip
	header {
		Cross-Origin-Opener-Policy "same-origin"
		Cross-Origin-Embedder-Policy "require-corp"
		Cross-Origin-Resource-Policy "same-origin"
		X-Content-Type-Options "nosniff"
	}
	@wasm path *.wasm
	header @wasm Content-Type "application/wasm"
	file_server
}
EOF
}

start_web() {
  local caddyfile="${ROOT}/.caddy/Caddyfile"
  local cpid
  if [[ ! -f "${ROOT}/www/index.html" ]]; then
    die "MODE=web has no ${ROOT}/www/index.html; reinstall"
  fi
  if ! command -v caddy >/dev/null; then
    die "caddy is not installed in this image"
  fi
  log "MODE=web uses the browser GPU (WebGPU, with WebGL2 fallback). The node GPU is not used."
  # Read-only root fs: keep Caddy's HOME/XDG state under ROOT, not /.local.
  mkdir -p "${ROOT}/.caddy/data" "${ROOT}/.caddy/config"
  export HOME="$ROOT"
  export XDG_DATA_HOME="${ROOT}/.caddy/data"
  export XDG_CONFIG_HOME="${ROOT}/.caddy/config"
  write_caddyfile
  log "serving ${ROOT}/www on 0.0.0.0:${SERVER_PORT}"
  caddy run --config "$caddyfile" --adapter caddyfile &
  cpid=$!
  trap 'kill "$cpid" 2>/dev/null || true' EXIT INT TERM
  if ! wait_http "http://127.0.0.1:${SERVER_PORT}/"; then
    die "Caddy did not serve ${ROOT}/www on port ${SERVER_PORT}"
  fi
  log "ready"
  wait "$cpid"
}

resolve_bin() {
  local name="$1"
  local candidate
  for candidate in "${ROOT}/app/bin/${name}" "${ROOT}/app/${name}"; do
    if [[ -f "$candidate" ]]; then
      chmod u+x "$candidate" || true
      if [[ -x "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done
  return 1
}

ensure_token() {
  local token_file="${ROOT}/.control-token"
  if ! command -v openssl >/dev/null; then
    die "openssl is required to create the control token"
  fi
  if [[ ! -s "$token_file" ]]; then
    ( umask 077; openssl rand -hex 32 > "$token_file" )
  fi
  chmod 0600 "$token_file"
}

ensure_vnc_passwd() {
  local pw_file="${ROOT}/.vnc-passwd"
  local pw_txt="${ROOT}/.vnc-password"
  if [[ ! -s "$pw_file" || ! -s "$pw_txt" ]]; then
    command -v openssl >/dev/null || die "openssl is required to create the VNC password"
    ( umask 077
      # ~48 bits, printable, exactly 8 chars (VNC uses only the first 8). No newline.
      pw=$(openssl rand -base64 6 | head -c 8)
      [[ ${#pw} -eq 8 ]] || exit 1
      printf '%s' "$pw" > "$pw_txt"
      # x11vnc -storepasswd only takes the password in argv or from a tty.
      # Write the same hash (DES-ECB with the fixed VNC key) with the password on stdin.
      if ! openssl enc -des-ecb -nopad -K e84ad660c4721ae0 -provider legacy -provider default \
          -in "$pw_txt" -out "$pw_file" 2>/dev/null || [[ $(wc -c < "$pw_file") -ne 8 ]]; then
        echo "[crafting-apps] openssl DES unavailable; falling back to x11vnc -storepasswd (password briefly in argv)" >&2
        x11vnc -storepasswd "$pw" "$pw_file" >/dev/null 2>&1
      fi ) || die "could not create the VNC password"
    log "created VNC password; read it from ${pw_txt}"
  fi
  chmod 0600 "$pw_file" "$pw_txt"
}

start_native() {
  local gui cli novnc_web xvfb_pid vnc_pid ws_pid app_pid cli_pid
  local -a gui_cmd=()
  pids=()
  cleanup_native() {
    local pid
    for pid in "${pids[@]+"${pids[@]}"}"; do
      kill "$pid" 2>/dev/null || true
    done
  }
  trap cleanup_native EXIT INT TERM
  apply_cpu_compositor
  gui=$(resolve_bin "$APP") || die "MODE=native did not find an executable named ${APP} under ${ROOT}/app"
  ensure_token
  # These apps parse --control as a port and bind 127.0.0.1 themselves.
  # host:port is rejected (photocraft parse_control_port). Do not pass a public address.
  gui_cmd=("$gui" --control "$CONTROL_PORT")
  if grep -a -q -F -- "--control-token-file" "$gui"; then
    gui_cmd+=(--control-token-file "${ROOT}/.control-token")
  else
    log "${APP} has no --control-token-file flag; control stays on 127.0.0.1:${CONTROL_PORT} without that flag"
  fi
  if grep -a -q -F -- "--automation-read-root" "$gui"; then
    gui_cmd+=(--automation-read-root "$ROOT")
  fi
  if grep -a -q -F -- "--automation-write-root" "$gui"; then
    gui_cmd+=(--automation-write-root "$ROOT")
  fi

  if ! command -v Xvfb >/dev/null || ! command -v x11vnc >/dev/null || ! command -v websockify >/dev/null; then
    die "Xvfb, x11vnc, and websockify must be installed for MODE=native"
  fi
  novnc_web=""
  for novnc_web in /opt/novnc /usr/share/novnc /usr/share/novnc/www; do
    if [[ -f "${novnc_web}/vnc.html" ]]; then
      break
    fi
    novnc_web=""
  done
  if [[ -z "$novnc_web" ]]; then
    die "noVNC vnc.html was not found under /opt/novnc or /usr/share/novnc"
  fi

  mkdir -p "${ROOT}/.logs" "${ROOT}/.xdg"
  chmod 700 "${ROOT}/.xdg"
  export HOME="$ROOT"
  export XDG_RUNTIME_DIR="${ROOT}/.xdg"
  unset WAYLAND_DISPLAY || true
  unset WAYLAND_SOCKET || true
  export DISPLAY=:99

  # ponytail: fixed 1280x800 virtual screen. Upgrade path: an egg variable if a different size is needed.
  # ponytail: pinned upstream noVNC in /opt/novnc + bookworm websockify + x11vnc. Upgrade path: bump NOVNC_VERSION in the Dockerfile.
  Xvfb :99 -screen 0 1280x800x24 -ac +extension GLX +render -noreset >"${ROOT}/.logs/xvfb.log" 2>&1 &
  xvfb_pid=$!
  pids+=("$xvfb_pid")
  local i
  for ((i = 0; i < 100; i++)); do
    if [[ -S /tmp/.X11-unix/X99 ]]; then
      break
    fi
    if ! kill -0 "$xvfb_pid" 2>/dev/null; then
      die "Xvfb exited; see ${ROOT}/.logs/xvfb.log"
    fi
    sleep 0.1
  done
  if [[ ! -S /tmp/.X11-unix/X99 ]]; then
    die "Xvfb did not create display :99"
  fi

  ensure_vnc_passwd
  x11vnc -display :99 -localhost -rfbauth "${ROOT}/.vnc-passwd" -forever -shared -rfbport 5900 >"${ROOT}/.logs/x11vnc.log" 2>&1 &
  vnc_pid=$!
  pids+=("$vnc_pid")

  websockify --web "$novnc_web" "0.0.0.0:${SERVER_PORT}" 127.0.0.1:5900 >"${ROOT}/.logs/websockify.log" 2>&1 &
  ws_pid=$!
  pids+=("$ws_pid")

  "${gui_cmd[@]}" >"${ROOT}/.logs/gui.log" 2>&1 &
  app_pid=$!
  pids+=("$app_pid")

  if cli=$(resolve_bin "${APP}-cli"); then
    log "starting ${APP}-cli mcp"
    "$cli" mcp >"${ROOT}/.logs/cli-mcp.log" 2>&1 &
    cli_pid=$!
    pids+=("$cli_pid")
  else
    log "${APP}-cli not present after unpack; skipping mcp"
  fi

  if ! wait_http "http://127.0.0.1:${SERVER_PORT}/vnc.html"; then
    die "noVNC did not listen on port ${SERVER_PORT}"
  fi
  log "native desktop on 0.0.0.0:${SERVER_PORT} (open /vnc.html); control on 127.0.0.1:${CONTROL_PORT}"
  log "ready"
  wait -n "$app_pid" "$ws_pid"
}

do_start() {
  require_server_port
  read_stamp
  log_gpu
  if [[ "$MODE" == "web" ]]; then
    start_web
  else
    start_native
  fi
}

main() {
  local action="${1:-}"
  if [[ -z "$action" ]]; then
    if [[ -d /mnt/server && ! -d /home/container ]]; then
      action=install
    else
      action=start
    fi
  fi
  case "$action" in
    install|start) ;;
    *) die "usage: crafting-apps.sh install|start" ;;
  esac

  validate

  case "$action" in
    install) ROOT="${CRAFTING_ROOT:-/mnt/server}" ;;
    start) ROOT="${CRAFTING_ROOT:-/home/container}" ;;
  esac

  log "action=${action} app=${APP} mode=${MODE} version=${VERSION} gpu=${GPU} root=${ROOT}"
  case "$action" in
    install) do_install ;;
    start) do_start ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
