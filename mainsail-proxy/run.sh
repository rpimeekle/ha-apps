#!/usr/bin/env bash
# Mainsail app entrypoint: renders the Moonraker/webcam proxy config from the
# app options, runs a start-up self-test and starts nginx.
set -euo pipefail

OPTIONS=/data/options.json
GEN=/run/mainsail
mkdir -p "${GEN}" /run/nginx

log() { echo "[$(date '+%F %T')] [mainsail] $*"; }
die() { log "ERROR: $*"; exit 1; }

# Allow plain `docker run -e MOONRAKER_URL=...` testing outside Home Assistant
if [ ! -f "${OPTIONS}" ]; then
  log "No ${OPTIONS} found, using environment (standalone mode)"
  mkdir -p /data
  jq -n --arg u "${MOONRAKER_URL:-}" --arg k "${MOONRAKER_API_KEY:-}" --arg w "${WEBCAM_URL:-}" \
    '{moonraker_url:$u, moonraker_api_key:$k, webcam_url:$w, log_requests:true}' > "${OPTIONS}"
fi

opt() { jq -r "$1 // empty | tostring" "${OPTIONS}"; }

MOONRAKER_URL="$(opt '.moonraker_url')"
API_KEY="$(opt '.moonraker_api_key')"
WEBCAM_URL="$(opt '.webcam_url')"
LOG_REQUESTS="$(opt '.log_requests')"

[ -n "${MOONRAKER_URL}" ] || die "moonraker_url is not set. Open the app's Configuration tab and enter e.g. http://192.168.1.50:7125"

# Split http(s)://host[:port][/...] ; only scheme, host and port are used
URL_RE='^(https?)://([^/:]+|\[[0-9a-fA-F:]+\])(:([0-9]+))?(/.*)?$'
[[ "${MOONRAKER_URL}" =~ ${URL_RE} ]] || die "moonraker_url '${MOONRAKER_URL}' is not a valid http(s) URL"
M_SCHEME="${BASH_REMATCH[1]}"
M_HOST="${BASH_REMATCH[2]}"
M_PORT="${BASH_REMATCH[4]:-}"
if [ -z "${M_PORT}" ]; then
  M_PORT=7125
  log "moonraker_url has no port, assuming Moonraker's default 7125"
fi
UPSTREAM="${M_SCHEME}://${M_HOST}:${M_PORT}"
[ -n "${BASH_REMATCH[5]:-}" ] && [ "${BASH_REMATCH[5]}" != "/" ] && \
  log "Ignoring path '${BASH_REMATCH[5]}' in moonraker_url (Moonraker is served from its root)"

# nginx resolves the host once at start; fail early with a clear message
if [[ ! "${M_HOST}" =~ ^[0-9.]+$ && ! "${M_HOST}" =~ ^\[ ]]; then
  getent hosts "${M_HOST}" >/dev/null || die "Cannot resolve '${M_HOST}'. Use the Moonraker machine's IP address instead (.local names usually don't resolve inside apps)."
fi

# ---- generated nginx snippets ------------------------------------------------
{
  echo "proxy_pass ${UPSTREAM};"
  echo "proxy_set_header Host \$proxy_host;"
  # Moonraker sees the request as coming from the Home Assistant machine.
  # Drop client-supplied forwarding headers so they can't spoof trusted_clients.
  echo "proxy_set_header X-Forwarded-For \"\";"
  echo "proxy_set_header X-Real-IP \"\";"
  # Same-origin through the proxy: no CORS needed, and Moonraker's websocket
  # origin check would reject the Home Assistant origin.
  echo "proxy_set_header Origin \"\";"
  if [ -n "${API_KEY}" ]; then
    echo "proxy_set_header X-Api-Key \"${API_KEY//\"/}\";"
  fi
  [ "${M_SCHEME}" = "https" ] && echo "proxy_ssl_server_name on;"
} > "${GEN}/moonraker.conf"

if [ -n "${WEBCAM_URL}" ]; then
  [[ "${WEBCAM_URL}" =~ ^https?://[^/]+ ]] || die "webcam_url '${WEBCAM_URL}' is not a valid http(s) URL"
  W_BASE="${WEBCAM_URL%/}/"
  cat > "${GEN}/webcam.conf" <<CONF
location /webcam/ {
    proxy_pass ${W_BASE};
    proxy_set_header Host \$proxy_host;
    proxy_buffering off;              # MJPEG streams
    proxy_read_timeout 1d;
}
CONF
  log "Webcam: /webcam/ -> ${W_BASE}"
else
  : > "${GEN}/webcam.conf"
fi

if [ "${LOG_REQUESTS}" = "true" ]; then
  cat > "${GEN}/logging.conf" <<'CONF'
log_format panel '[proxy] "$request" $status upstream=$upstream_status time=${upstream_response_time}s';
access_log /dev/stdout panel;
CONF
else
  echo "access_log off;" > "${GEN}/logging.conf"
fi

nginx -t -q || die "nginx configuration test failed (see above)"

# ---- start-up self-test (runs once nginx is up) --------------------------------
selftest() {
  sleep 2
  local code body state
  local hdr=()
  [ -n "${API_KEY}" ] && hdr=(-H "X-Api-Key: ${API_KEY}")

  body="$(curl -sS -m 10 -o - -w '\n%{http_code}' "${hdr[@]}" "${UPSTREAM}/server/info" 2>&1)" || true
  code="${body##*$'\n'}"; body="${body%$'\n'*}"
  case "${code}" in
    200)
      state="$(printf '%s' "${body}" | jq -r '.result.klippy_state // "unknown"' 2>/dev/null || echo unknown)"
      log "Self-test Moonraker (${UPSTREAM}): OK, Klipper state: ${state}" ;;
    401|403)
      log "Self-test Moonraker (${UPSTREAM}): REFUSED (HTTP ${code})."
      log "  Add your Home Assistant machine's IP to [authorization] trusted_clients in moonraker.conf,"
      log "  or set moonraker_api_key in this app's options." ;;
    000|"")
      body="${body//$'\n'/ }"
      log "Self-test Moonraker (${UPSTREAM}): UNREACHABLE (${body:-no response})."
      log "  Check the address and port, and that Moonraker is running." ;;
    *)
      log "Self-test Moonraker (${UPSTREAM}): unexpected HTTP ${code}" ;;
  esac

  if curl -sS -m 5 -H 'X-Ingress-Path: /api/hassio_ingress/SELFTEST' http://127.0.0.1:8099/ \
       | grep -q 'src="/api/hassio_ingress/SELFTEST/assets/'; then
    log "Self-test panel: OK (Mainsail paths follow the ingress prefix)"
  else
    log "Self-test panel: PROBLEM - Mainsail paths are not being rewritten; the sidebar panel will not load"
  fi
}
selftest &

log "Mainsail $(jq -r .version /var/www/mainsail/release_info.json 2>/dev/null || echo '?') -> Moonraker ${UPSTREAM}"
exec nginx -g 'daemon off;'
