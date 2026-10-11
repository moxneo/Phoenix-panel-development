# Local image for the Crafting Apps Wings egg.
# Tag: crafting-apps:latest
# Build on the Wings node (this repo does not push a registry):
#   docker build -t crafting-apps:latest eggs/crafting-apps
FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587

# GPU device nodes are optional. vulkan-loader (libvulkan1) is installed either way.
# ponytail: upstream noVNC (/opt/novnc), bookworm websockify/x11vnc and mesa lavapipe. Upgrade path: bump NOVNC_VERSION
# or a vendor Vulkan ICD when the host GPU should win over llvmpipe.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        unzip \
        tar \
        openssl \
        libxkbcommon0 \
        libxkbcommon-x11-0 \
        libwayland-client0 \
        libwayland-cursor0 \
        libwayland-egl1 \
        libx11-6 \
        libx11-xcb1 \
        libxcursor1 \
        libxrandr2 \
        libxi6 \
        libxcb1 \
        libvulkan1 \
        mesa-vulkan-drivers \
        libegl1 \
        libgl1 \
        libgl1-mesa-dri \
        libgtk-3-0 \
        libdbus-1-3 \
        fontconfig \
        fonts-dejavu-core \
        libfreetype6 \
        libasound2 \
        xvfb \
        x11vnc \
        python3 \
        python3-websockify \
    && rm -rf /var/lib/apt/lists/*

ARG CADDY_VERSION=2.11.7
ARG CADDY_SHA256=727b91701a392de6ebc5027509f548bf39979e5216340d0faed8fa5e69c84f8b
RUN curl -fsSL -A "crafting-apps-egg/1.0" -o /tmp/caddy.tar.gz \
        "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" \
    && echo "${CADDY_SHA256}  /tmp/caddy.tar.gz" | sha256sum -c - \
    && tar -C /usr/local/bin -xzf /tmp/caddy.tar.gz caddy \
    && chmod 0755 /usr/local/bin/caddy \
    && rm /tmp/caddy.tar.gz

# noVNC web client from upstream: bookworm's 1.3 package fails in current
# Safari/Brave ("Script error."). websockify stays the bookworm python3 package.
ARG NOVNC_VERSION=1.7.0
ARG NOVNC_SHA256=b1003a11b6e6e8d8f7f5e5586daae7f8ca651d8aee0aa155ff9ac841c48f52c6
RUN curl -fsSL -A "crafting-apps-egg/1.0" -o /tmp/novnc.tar.gz \
        "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" \
    && echo "${NOVNC_SHA256}  /tmp/novnc.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/novnc \
    && tar -C /opt/novnc --strip-components=1 -xzf /tmp/novnc.tar.gz \
    && test -f /opt/novnc/vnc.html \
    && rm /tmp/novnc.tar.gz

COPY crafting-apps.sh /usr/local/bin/crafting-apps
RUN chmod 0755 /usr/local/bin/crafting-apps

WORKDIR /home/container
CMD ["/usr/local/bin/crafting-apps", "start"]
