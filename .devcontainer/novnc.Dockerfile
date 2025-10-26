FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
# Build-time defaults; can be overridden in compose
ARG DEFAULT_TZ=Europe/Dublin
ARG DEFAULT_LOCALE=en_IE.UTF-8
ARG DEFAULT_LANGUAGE=en_IE:en

# Core utilities + GUI stack + tz/locale + helpers
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg \
      tzdata locales \
      x11vnc xvfb fluxbox novnc websockify \
      xterm ffmpeg pulseaudio-utils \
      wmctrl xdotool x11-utils; \
    # Configure timezone
    ln -fs "/usr/share/zoneinfo/${DEFAULT_TZ}" /etc/localtime; \
    dpkg-reconfigure -f noninteractive tzdata; \
    # Configure locales (ensure the requested locale exists)
    sed -i "s/^# \(${DEFAULT_LOCALE//\//\/} \)UTF-8/\1UTF-8/" /etc/locale.gen || true; \
    grep -q "^${DEFAULT_LOCALE} UTF-8$" /etc/locale.gen || echo "${DEFAULT_LOCALE} UTF-8" >> /etc/locale.gen; \
    locale-gen; \
    update-locale LANG="${DEFAULT_LOCALE}" LC_ALL="${DEFAULT_LOCALE}" LANGUAGE="${DEFAULT_LANGUAGE}"; \
    rm -rf /var/lib/apt/lists/*

# Install Google Chrome (modern, signed-by repo)
RUN set -eux; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg; \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends google-chrome-stable; \
    rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/google-chrome \
    DISPLAY=:99 \
    TZ=${DEFAULT_TZ} \
    LANG=${DEFAULT_LOCALE} \
    LC_ALL=${DEFAULT_LOCALE} \
    LANGUAGE=${DEFAULT_LANGUAGE}

COPY .devcontainer/scripts/start-desktop.sh /usr/local/bin/start-desktop.sh
RUN chmod +x /usr/local/bin/start-desktop.sh

EXPOSE 6080
CMD ["/usr/local/bin/start-desktop.sh"]
