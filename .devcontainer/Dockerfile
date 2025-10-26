# Base
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DEBIAN_FRONTEND=noninteractive
# Flip to "false" if you don't want the noVNC/VNC stack baked in.
ARG INSTALL_NOVNC=true

# --- Common base packages (system-level; suitable for Dockerfile) ---
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    jq \
    xz-utils \
    zip \
    unzip \
    # X11 helpers used previously in post-create
    wmctrl \
    xdotool \
    x11-utils \
    && rm -rf /var/lib/apt/lists/*

# --- Google Chrome repo & install (moved from script to image build) ---
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    google-chrome-stable \
    xterm \
    ffmpeg \
    pulseaudio-utils \
    && rm -rf /var/lib/apt/lists/*

# (optional) make Chrome discoverable to tools that look for CHROME_BIN
ENV CHROME_BIN=/usr/bin/google-chrome

# --- Optional noVNC/VNC headless desktop stack ---
# (Installed at build so you don't apt-install during post-create.)
RUN if [ "$INSTALL_NOVNC" = "true" ]; then \
    apt-get update \
    && apt-get install -y --no-install-recommends \
    novnc \
    websockify \
    x11vnc \
    xvfb \
    fluxbox \
    && rm -rf /var/lib/apt/lists/*; \
    fi

# --- Chrome policy file (use a separate RUN for the heredoc to avoid parser issues) ---
RUN set -eux; \
    install -d -m 0755 /etc/opt/chrome/policies/managed; \
    cat >/etc/opt/chrome/policies/managed/classroom.json <<'JSON'
{
  "DeveloperToolsAvailability": 1,
  "ExtensionDeveloperModeSettings": 1,
  "ShowHomeButton": true,
  "ShowDownloadButton": true,
  "ShowDownloadsToolbarButton": true,
  "ExtensionInstallBlocklist": ["*"],
  "ExtensionSettings": {
    "*": { "installation_mode": "blocked" },
    "fmkadmapgofadopljbjfkapdkoienihi": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx",
      "toolbar_pin": "force_pinned"
    }
  }
}
JSON

# Mirror policy for Chromium if present (separate RUN avoids the stray ';' after heredoc)
RUN set -eux; \
    install -d -m 0755 /etc/chromium/policies/managed; \
    cp /etc/opt/chrome/policies/managed/classroom.json /etc/chromium/policies/managed/classroom.json || true

# You can still layer Dev Container Features (Node, Python, CUDA, etc.) via devcontainer.json
