# Base
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DEBIAN_FRONTEND=noninteractive
# Flip to "false" if you don't want the noVNC/VNC stack baked in.
ARG INSTALL_NOVNC=true
# Make timezone/locale configurable at build time
ARG DEFAULT_TZ=Etc/UTC
ARG DEFAULT_LOCALE=en_IE.UTF-8

# --- Common base packages (system-level; suitable for Dockerfile) ---
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  git \
  jq \
  xz-utils \
  zip \
  unzip \
  tzdata \
  locales \
  # X11 helpers used previously in post-create
  wmctrl \
  xdotool \
  x11-utils; \
  # Configure timezone (noninteractive)
  ln -fs "/usr/share/zoneinfo/${DEFAULT_TZ}" /etc/localtime; \
  dpkg-reconfigure -f noninteractive tzdata; \
  # Generate and set locale
  printf "%s UTF-8\n" "${DEFAULT_LOCALE}" > /etc/locale.gen; \
  locale-gen; \
  update-locale LANG="${DEFAULT_LOCALE}" LC_ALL="${DEFAULT_LOCALE}"; \
  rm -rf /var/lib/apt/lists/*

# Default envs (apps can still choose any IANA tz in Intl)
ENV TZ=${DEFAULT_TZ} \
  LANG=${DEFAULT_LOCALE} \
  LC_ALL=${DEFAULT_LOCALE} \
  LANGUAGE=${DEFAULT_LOCALE%.*}:${DEFAULT_LOCALE%.*}

# --- Google Chrome repo & install ---
RUN set -eux; \
  mkdir -p /etc/apt/keyrings; \
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg; \
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
  > /etc/apt/sources.list.d/google-chrome.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  google-chrome-stable \
  xterm \
  ffmpeg \
  pulseaudio-utils; \
  rm -rf /var/lib/apt/lists/*

# (optional) make Chrome discoverable to tools that look for CHROME_BIN
ENV CHROME_BIN=/usr/bin/google-chrome

# --- Optional noVNC/VNC headless desktop stack ---
# (Installed at build so you don't apt-install during post-create.)
RUN if [ "$INSTALL_NOVNC" = "true" ]; then \
  set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  novnc \
  websockify \
  x11vnc \
  xvfb \
  fluxbox; \
  rm -rf /var/lib/apt/lists/*; \
  fi

# --- Chrome policy file (separate RUN for heredoc to avoid parser issues) ---
RUN set -eux; \
  install -d -m 0755 /etc/opt/chrome/policies/managed; \
  cat >/etc/opt/chrome/policies/managed/classroom.json <<'JSON'
{
  "DeveloperToolsAvailability": 1,
  "ExtensionDeveloperModeSettings": 1,
  "ShowHomeButton": true,
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

# Mirror policy for Chromium if present
RUN set -eux; \
  install -d -m 0755 /etc/chromium/policies/managed; \
  cp /etc/opt/chrome/policies/managed/classroom.json /etc/chromium/policies/managed/classroom.json || true

# Notes:
# - Flip INSTALL_NOVNC via build args in devcontainer.json/compose to trim the image when not needed.
# - Intl/Date issues in headless Chrome are often due to missing tz/locale data; this Dockerfile installs and configures both.
# - You can still layer Dev Container Features (Node, Python, CUDA, etc.) via devcontainer.json
