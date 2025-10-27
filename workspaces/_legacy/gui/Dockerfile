FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DEFAULT_TZ="Europe/Dublin"
ARG DEFAULT_LOCALE="en_IE.UTF-8"
ARG DEFAULT_LANGUAGE="en_IE:en"

# Base deps + TZ/locale + X11/WM + noVNC + audio + utils + fonts
ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg \
      tzdata locales \
      xvfb x11vnc fluxbox novnc websockify \
      xterm ffmpeg pulseaudio pulseaudio-utils \
      wmctrl xdotool x11-utils jq xauth \
      fonts-liberation fonts-noto-color-emoji; \
    # Timezone & locale
    ln -fs "/usr/share/zoneinfo/${DEFAULT_TZ}" /etc/localtime; \
    dpkg-reconfigure -f noninteractive tzdata; \
    sed -i "s|^# \(${DEFAULT_LOCALE} \)UTF-8|\1UTF-8|" /etc/locale.gen || true; \
    grep -q "^${DEFAULT_LOCALE} UTF-8$" /etc/locale.gen || echo "${DEFAULT_LOCALE} UTF-8" >> /etc/locale.gen; \
    locale-gen; \
    update-locale LANG="${DEFAULT_LOCALE}" LC_ALL="${DEFAULT_LOCALE}" LANGUAGE="${DEFAULT_LANGUAGE}"; \
    rm -rf /var/lib/apt/lists/*

# Google Chrome (signed-by keyring)
RUN set -eux; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg; \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends google-chrome-stable; \
    rm -rf /var/lib/apt/lists/*

ARG APPLY_CHROME_POLICY=0
ARG REDUCE_FLUXBOX_MENU=0

ENV APPLY_CHROME_POLICY=${APPLY_CHROME_POLICY} \
    REDUCE_FLUXBOX_MENU=${REDUCE_FLUXBOX_MENU} \
    CHROME_BIN=/usr/bin/google-chrome \
    DISPLAY=:99 \
    TZ=${DEFAULT_TZ} \
    LANG=${DEFAULT_LOCALE} \
    LC_ALL=${DEFAULT_LOCALE} \
    LANGUAGE=${DEFAULT_LANGUAGE}

# Scripts used by the desktop entrypoint
COPY .devcontainer/gui/scripts/start-desktop.sh /usr/local/bin/start-desktop.sh
COPY .devcontainer/gui/scripts/novnc-audio-bridge.sh /usr/local/bin/novnc-audio-bridge.sh
COPY .devcontainer/gui/scripts/fluxbox-setup.sh /usr/local/bin/fluxbox-setup.sh
COPY .devcontainer/gui/scripts/apply-chrome-policy.sh /usr/local/bin/apply-chrome-policy.sh
RUN chmod +x /usr/local/bin/*.sh

RUN if [ "$APPLY_CHROME_POLICY" = "1" ]; then \
      /usr/local/bin/apply-chrome-policy.sh; \
    else \
      echo "[gui] Chrome policy disabled at build time"; \
    fi && \
    if [ "$REDUCE_FLUXBOX_MENU" = "1" ]; then \
      /usr/local/bin/fluxbox-setup.sh; \
    else \
      echo "[gui] Fluxbox menu reduction disabled at build time"; \
    fi && \
    mkdir -p /opt/novnc && chown -R vscode:vscode /opt/novnc

EXPOSE 6080 6081 9222

USER vscode

CMD ["/usr/local/bin/start-desktop.sh"]
