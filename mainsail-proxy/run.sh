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

# ---- webcam -------------------------------------------------------------------
# normalize_url URL -> scheme://host[:port]/path (lower-case host, default port
# dropped, query removed), the same form a browser's URL().href produces
normalize_url() {
  local u="${1%%\?*}" re='^([A-Za-z]+)://([^/:]+|\[[0-9a-fA-F:]+\])(:([0-9]+))?(/[^?#]*)?$'
  [[ "${u}" =~ ${re} ]] || return 1
  local sch="${BASH_REMATCH[1],,}" host="${BASH_REMATCH[2],,}" port="${BASH_REMATCH[4]:-}" path="${BASH_REMATCH[5]:-/}"
  [[ "${sch}" == http || "${sch}" == https ]] || return 1
  if [[ "${sch}:${port}" == "http:80" || "${sch}:${port}" == "https:443" ]]; then port=""; fi
  printf '%s://%s%s%s' "${sch}" "${host}" "${port:+:${port}}" "${path}"
}

# Mainsail keeps its webcam list in Moonraker; read it for detection and the self-test
WEBCAMS="${GEN}/webcams.json"
rm -f "${WEBCAMS}"
cam_hdr=()
[ -n "${API_KEY}" ] && cam_hdr=(-H "X-Api-Key: ${API_KEY}")
if curl -sf -m 5 "${cam_hdr[@]}" "${UPSTREAM}/server/webcams/list" -o "${WEBCAMS}.tmp" 2>/dev/null \
   && jq -e '.result.webcams | type == "array"' "${WEBCAMS}.tmp" >/dev/null 2>&1; then
  jq '[.result.webcams[] | select(.enabled != false) | {name, stream_url, snapshot_url, service}]' "${WEBCAMS}.tmp" > "${WEBCAMS}"
fi
rm -f "${WEBCAMS}.tmp"

# cam_fetch URL -> "OK" or a reason. Streams never end, so a time-out after the
# headers arrived is fine: only the status and content type matter.
cam_fetch() {
  local out err code type
  out="$(curl -sS -m 4 -o /dev/null -w '%{http_code} %{content_type}' "$1" 2>/tmp/cam.err)" || true
  err="$(grep -v 'Operation timed out' /tmp/cam.err | tr '\n' ' ')"; rm -f /tmp/cam.err
  code="${out%% *}"; type="${out#* }"
  case "${code}" in
    200) case "${type}" in
           image/*|multipart/*) echo OK ;;
           *) echo "answered with '${type:-unknown}', not a camera image" ;;
         esac ;;
    000|"") echo "unreachable (${err:-no response})" ;;
    *) echo "HTTP ${code}" ;;
  esac
}

# W_BASE: where the panel's webcam/ goes, for cameras set up as /webcam/...
# CAM_BASES: every camera address the panel routes. A full camera address that
# starts with CAM_BASES[i] is shown through the panel at webcams/<i>/.
W_BASE=""
CAM_BASES=()
# add_base BASE -> adds BASE to CAM_BASES; fails if it was already there
add_base() {
  local b
  for b in "${CAM_BASES[@]}"; do [ "${b}" = "$1" ] && return 1; done
  CAM_BASES+=("$1")
}
# route_of URL -> the routed camera address URL starts with (longest), if any
route_of() {
  local b best=""
  for b in "${CAM_BASES[@]}"; do
    if [[ -n "$1" && "$1" == "${b}"* && ${#b} -gt ${#best} ]]; then best="${b}"; fi
  done
  printf '%s' "${best}"
}

if [ -n "${WEBCAM_URL}" ]; then
  if [[ "${WEBCAM_URL}" == *\?* ]]; then
    log "webcam_url should be the camera's base address: ignoring '?${WEBCAM_URL#*\?}'"
  fi
  W_BASE="$(normalize_url "${WEBCAM_URL}")" || die "webcam_url '${WEBCAM_URL}' is not a valid http(s) URL"
  # A stream or snapshot address (.../stream, .../snapshot) is an easy mistake;
  # Mainsail appends those itself, so proxy the streamer's base instead
  if [[ "${W_BASE%/}" =~ ^https?://[^/]+(/.*)?/(stream|snapshot)$ ]]; then
    W_BASE="${W_BASE%/}"; W_BASE="${W_BASE%/*}/"
    log "webcam_url '${WEBCAM_URL}' looks like a stream address; using the camera streamer's base ${W_BASE}"
  fi
  W_BASE="${W_BASE%/}/"
  log "Webcam: using webcam_url ${W_BASE}"
  add_base "${W_BASE}"
fi

if [ -s "${WEBCAMS}" ]; then
  # Each camera with a full http(s) address: route its scheme://host:port/
  while IFS= read -r u; do
    n="$(normalize_url "${u}")" || continue
    [[ "${n}" =~ ^(https?://[^/]+)/ ]] || continue
    if add_base "${BASH_REMATCH[1]}/"; then
      log "Webcam: detected ${BASH_REMATCH[1]}/ from Mainsail's webcam settings"
    fi
  done < <(jq -r '.[] | (.stream_url // ""), (.snapshot_url // "") | select(test("^https?://"; "i"))' "${WEBCAMS}")

  if [ -z "${W_BASE}" ] && jq -e 'any(.[]; [(.stream_url // ""), (.snapshot_url // "")] | any(test("^/?webcam/")))' "${WEBCAMS}" >/dev/null; then
    # /webcam/ is served by the web server on the Klipper machine (port 80 on
    # MainsailOS/KIAUH installs). Only use it if a camera image comes back.
    cand="$(normalize_url "http://${M_HOST}/webcam/")"
    verdict="$(cam_fetch "${cand}?action=snapshot")"
    if [ "${verdict}" = OK ]; then
      W_BASE="${cand}"
      log "Webcam: cameras using /webcam/ go to ${W_BASE} (the Moonraker host's web server)"
    else
      log "Webcam: cameras use /webcam/, but ${cand} ${verdict}, so they won't show in the panel."
      log "  Set webcam_url to the address that serves /webcam/ (ending in /webcam/), or give them a full address in Mainsail."
    fi
  fi
fi

# The addresses are written into nginx config and into a JS string: keep them plain
SAFE_URL_RE='^https?://[][A-Za-z0-9._~:/%@!,;=+-]+$'
for b in "${W_BASE}" "${CAM_BASES[@]}"; do
  [ -z "${b}" ] || [[ "${b}" =~ ${SAFE_URL_RE} ]] || die "webcam address '${b}' contains unsupported characters"
done

# cam_location PATH TARGET -> nginx location proxying PATH to the camera at TARGET
cam_location() {
  cat <<CONF
location $1 {
    proxy_pass $2;
    proxy_set_header Host \$proxy_host;
    proxy_buffering off;              # MJPEG streams
    proxy_read_timeout 1d;
}
CONF
}
{
  if [ -n "${W_BASE}" ]; then
    cam_location /webcam/ "${W_BASE}"
  else
    # Fail clearly instead of serving the Mainsail page as a "camera"
    cat <<'CONF'
location /webcam/ {
    default_type text/plain;
    return 503 "No camera address: set webcam_url in the Mainsail app options\n";
}
CONF
  fi
  for i in "${!CAM_BASES[@]}"; do
    cam_location "/webcams/${i}/" "${CAM_BASES[${i}]}"
  done
} > "${GEN}/webcam.conf"
printf "sub_filter '__HA_WEBCAM_BASES__' '%s';\n" "${CAM_BASES[*]}" > "${GEN}/webcam_filter.conf"

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

  webcam_selftest
}

webcam_selftest() {
  local count i name url up verdict n via
  count=0
  [ -s "${WEBCAMS}" ] && count="$(jq length "${WEBCAMS}")"
  if [ "${count}" = 0 ]; then
    if [ -z "${W_BASE}" ]; then
      log "Self-test webcam: no cameras set up in Mainsail"
    else
      verdict="$(cam_fetch "${W_BASE}?action=snapshot")"
      log "Self-test webcam (${W_BASE}): ${verdict}"
    fi
    return
  fi
  for ((i = 0; i < count; i++)); do
    name="$(jq -r ".[${i}].name // \"camera $((i + 1))\"" "${WEBCAMS}")"
    # Prefer the snapshot address (a single image), fall back to the stream
    url="$(jq -r ".[${i}] | if ((.snapshot_url // \"\") != \"\") then .snapshot_url else (.stream_url // \"\") end" "${WEBCAMS}")"
    up=""
    if [[ "${url}" =~ ^[Hh][Tt][Tt][Pp][Ss]?:// ]]; then
      n="$(normalize_url "${url}")" || n=""
      via="$(route_of "${n}")"
      if [ -z "${via}" ]; then
        log "Self-test webcam '${name}': uses ${url%%\?*}, which the panel can't route,"
        log "  so it will only show at home over plain http. Check the address in Mainsail's webcam settings."
        continue
      fi
      up="${url}"
    elif [[ "${url}" == /webcam/* || "${url}" == webcam/* ]]; then
      if [ -z "${W_BASE}" ]; then
        log "Self-test webcam '${name}': uses ${url%%\?*} but nothing serves /webcam/ for the panel."
        log "  Set webcam_url to the address that serves /webcam/ (ending in /webcam/), or give the camera a full address in Mainsail."
        continue
      fi
      via="${W_BASE}"
      up="${W_BASE}${url#*webcam/}"
    else
      log "Self-test webcam '${name}': uses '${url}', which the panel can't route (only full addresses and /webcam/ are supported)"
      continue
    fi
    verdict="$(cam_fetch "${up}")"
    if [ "${verdict}" = OK ]; then
      log "Self-test webcam '${name}': OK (shown through the panel via ${via})"
    else
      log "Self-test webcam '${name}': PROBLEM - ${up%%\?*} ${verdict}"
      case "${verdict}" in
        answered*) log "  That address returns a web page (often Mainsail itself), not the camera. Use the camera streamer's own address." ;;
        unreachable*) log "  Home Assistant can't reach the camera: check it's on the same network and its port is open to other machines." ;;
      esac
    fi
  done
}

selftest &

log "Mainsail $(jq -r .version /var/www/mainsail/release_info.json 2>/dev/null || echo '?') -> Moonraker ${UPSTREAM}"
exec nginx -g 'daemon off;'
