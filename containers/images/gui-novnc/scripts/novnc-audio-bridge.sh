#!/usr/bin/env bash
set -euo pipefail

NOVNC_ROOT="${1:-/opt/novnc}"
: "${NOVNC_AUDIO_PORT_EFFECTIVE:=6081}"

log() { echo "[audio] $*"; }

need() { command -v "$1" >/dev/null 2>&1; }

# Ensure XDG_RUNTIME_DIR for PulseAudio
ensure_xdg_runtime() {
  if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    local dir="/run/user/$(id -u)"
    mkdir -p "$dir" || true
    chmod 700 "$dir" || true
    export XDG_RUNTIME_DIR="$dir"
  fi
}

start_pulseaudio() {
  if need pulseaudio; then
    pulseaudio --check >/dev/null 2>&1 || pulseaudio --start >/dev/null 2>&1 || true
  else
    log "pulseaudio missing; audio bridge disabled."
    exit 0
  fi
}

ensure_null_sink() {
  if need pactl; then
    if ! pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -qx "novnc_sink"; then
      pactl load-module module-null-sink sink_name=novnc_sink sink_properties=device.description=NoVNC >/dev/null 2>&1 || true
    fi
    pactl set-default-sink novnc_sink >/dev/null 2>&1 || true
    while read -r sink_input _; do
      [[ -z "$sink_input" ]] && continue
      pactl move-sink-input "$sink_input" novnc_sink >/dev/null 2>&1 || true
    done < <(pactl list short sink-inputs 2>/dev/null || true)
  fi
}

start_ffmpeg_stream() {
  if ! need ffmpeg; then
    log "ffmpeg missing; audio bridge disabled."
    exit 0
  fi

  local pattern="ffmpeg .*novnc_sink\.monitor.*${NOVNC_AUDIO_PORT_EFFECTIVE}/audio\.ogg"
  if ! pgrep -f "$pattern" >/dev/null 2>&1; then
    log "Starting ffmpeg pulseaudio→HTTP on :${NOVNC_AUDIO_PORT_EFFECTIVE}/audio.ogg"
    nohup ffmpeg -nostdin -loglevel error \
      -f pulse -i novnc_sink.monitor \
      -ac 2 -ar 44100 \
      -codec:a libopus -b:a 128k \
      -f ogg -content_type audio/ogg \
      -listen 1 "http://0.0.0.0:${NOVNC_AUDIO_PORT_EFFECTIVE}/audio.ogg" \
      >/tmp/novnc-audio.log 2>&1 &
  fi
}

inject_player_script() {
  local helper="$NOVNC_ROOT/app/airnub-audio.js"
  mkdir -p "$(dirname "$helper")"
  cat >"$helper" <<EOF
(function () {
  const params = new URLSearchParams(window.location.search);
  const fallbackPort = ${NOVNC_AUDIO_PORT_EFFECTIVE};
  let port = parseInt(params.get('audio_port') || '', 10);
  if (!Number.isFinite(port)) port = fallbackPort;
  const proto = window.location.protocol === 'https:' ? 'https:' : 'http:';
  const streamUrl = proto + '//' + window.location.hostname + ':' + port + '/audio.ogg';
  const audio = new Audio(streamUrl);
  audio.autoplay = true; audio.loop = true; audio.muted = true; audio.preload = 'auto'; audio.playsInline = true;
  audio.style.display = 'none';
  const ensurePlay = () => audio.play().catch(()=>{});
  let notice=null; const removeNotice=()=>{ if(notice){notice.remove(); notice=null;} };
  const gesture=()=>{ audio.muted=false; ensurePlay(); removeNotice(); window.removeEventListener('pointerdown',gesture); window.removeEventListener('keydown',gesture); };
  const showNotice=()=>{ if(!audio.muted||notice) return; notice=document.createElement('div'); notice.innerHTML='Remote audio ready. <strong>Click or press any key</strong> to hear it.'; notice.style.cssText='position:fixed;z-index:9999;top:12px;right:12px;padding:10px 14px;background:rgba(0,0,0,.75);color:#fff;font:13px system-ui;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.45);cursor:pointer'; notice.addEventListener('click',()=>{audio.muted=false;ensurePlay();removeNotice();},{once:true}); document.body.appendChild(notice); };
  const attach=()=>{ if(!audio.isConnected) document.body.appendChild(audio); };
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',attach,{once:true}); else attach();
  ensurePlay(); setTimeout(showNotice,1200);
  window.addEventListener('pointerdown',gesture); window.addEventListener('keydown',gesture); window.addEventListener('focus',ensurePlay);
  document.addEventListener('visibilitychange',()=>{ if(!document.hidden) ensurePlay(); });
  audio.addEventListener('playing',removeNotice); audio.addEventListener('error',()=> setTimeout(ensurePlay,3000));
  setInterval(()=>{ if(!document.hidden) ensurePlay(); },15000);
})();
EOF

  # Add <script> before </body> if missing
  if [[ -f "$NOVNC_ROOT/vnc.html" ]] && ! grep -Fq "app/airnub-audio.js" "$NOVNC_ROOT/vnc.html"; then
    awk '
      /<\/body>/ && !added { print "    <script src=\"app/airnub-audio.js\"></script>"; added=1 }
      { print }
      END { if (!added) print "    <script src=\"app/airnub-audio.js\"></script>" }
    ' "$NOVNC_ROOT/vnc.html" > "$NOVNC_ROOT/vnc.html.tmp"
    mv "$NOVNC_ROOT/vnc.html.tmp" "$NOVNC_ROOT/vnc.html"
  fi
}

ensure_xdg_runtime
start_pulseaudio
ensure_null_sink
start_ffmpeg_stream
inject_player_script
log "Audio bridge ready (port ${NOVNC_AUDIO_PORT_EFFECTIVE})."
