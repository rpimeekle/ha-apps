#!/usr/bin/env bash
# TrueNAS ingress app entrypoint: renders the proxy config from the app
# options, runs a start-up self-test and starts nginx.
set -euo pipefail

OPTIONS=/data/options.json
GEN=/run/truenas
SHIM=/usr/share/ha-ingress/shim.js
mkdir -p "${GEN}" /run/nginx

log() { echo "[$(date '+%F %T')] [truenas] $*"; }
die() { log "ERROR: $*"; exit 1; }

# Allow plain `docker run -e TRUENAS_URL=...` testing outside Home Assistant
if [ ! -f "${OPTIONS}" ]; then
  log "No ${OPTIONS} found, using environment (standalone mode)"
  mkdir -p /data
  jq -n --arg u "${TRUENAS_URL:-}" '{truenas_url:$u, verify_ssl:false, log_requests:true}' > "${OPTIONS}"
fi

opt() { jq -r "$1 // empty | tostring" "${OPTIONS}"; }

TRUENAS_URL="$(opt '.truenas_url')"
VERIFY_SSL="$(opt '.verify_ssl')"
LOG_REQUESTS="$(opt '.log_requests')"

[ -n "${TRUENAS_URL}" ] || die "truenas_url is not set. Open the app's Configuration tab and enter e.g. https://192.168.1.20"

URL_RE='^(https?)://([^/:]+|\[[0-9a-fA-F:]+\])(:([0-9]+))?(/.*)?$'
[[ "${TRUENAS_URL}" =~ ${URL_RE} ]] || die "truenas_url '${TRUENAS_URL}' is not a valid http(s) URL"
T_SCHEME="${BASH_REMATCH[1]}"
T_HOST="${BASH_REMATCH[2]}"
T_PORT="${BASH_REMATCH[4]:-}"
if [ -z "${T_PORT}" ]; then
  if [ "${T_SCHEME}" = "https" ]; then T_PORT=443; else T_PORT=80; fi
fi
UPSTREAM="${T_SCHEME}://${T_HOST}:${T_PORT}"
if [ -n "${BASH_REMATCH[5]:-}" ] && [ "${BASH_REMATCH[5]}" != "/" ]; then
  log "Ignoring path '${BASH_REMATCH[5]}' in truenas_url (the UI is always served from /ui/)"
fi

if [[ ! "${T_HOST}" =~ ^[0-9.]+$ && ! "${T_HOST}" =~ ^\[ ]]; then
  getent hosts "${T_HOST}" >/dev/null || die "Cannot resolve '${T_HOST}'. Use the TrueNAS IP address instead (.local names usually don't resolve inside apps)."
fi

# ---- generated nginx snippets ------------------------------------------------
{
  echo "proxy_pass ${UPSTREAM};"
  # TrueNAS sees a same-origin request for its own address
  echo "proxy_set_header Host \$proxy_host;"
  echo "proxy_set_header Origin \"${UPSTREAM}\";"
  if [ "${T_SCHEME}" = "https" ]; then
    echo "proxy_ssl_server_name on;"
    if [ "${VERIFY_SSL}" = "true" ]; then
      echo "proxy_ssl_verify on;"
      echo "proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;"
    else
      echo "proxy_ssl_verify off;   # TrueNAS ships a self-signed certificate"
    fi
  fi
} > "${GEN}/upstream.conf"

# Browser shim: drop comment lines, collapse whitespace, insert the panel prefix
SHIM_MIN="$(grep -v '^[[:space:]]*//' "${SHIM}" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
case "${SHIM_MIN}" in *"'"*|*'$'*) die "shim.js must not contain ' or \$ characters";; esac
SHIM_MIN="${SHIM_MIN//__PREFIX__/\$http_x_ingress_path}"
printf "sub_filter '<head>' '<head><script>%s</script>';\n" "${SHIM_MIN}" > "${GEN}/inject.conf"

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
  local tls=(-k) out code loc
  [ "${VERIFY_SSL}" = "true" ] && tls=()

  local err
  out="$(curl -sS -m 10 "${tls[@]}" -o /tmp/ui.html -w '%{http_code} %{redirect_url}' "${UPSTREAM}/ui/" 2>/tmp/curl.err)" || true
  err="$(tr '\n' ' ' < /tmp/curl.err)"; rm -f /tmp/curl.err
  code="${out%% *}"; loc="${out#* }"
  case "${code}" in
    200)
      if grep -q '<base href="/ui/">' /tmp/ui.html; then
        log "Self-test TrueNAS (${UPSTREAM}): OK"
      else
        log "Self-test TrueNAS (${UPSTREAM}): answered, but the page doesn't look like the TrueNAS UI (no <base href=\"/ui/\">)."
      fi ;;
    301|302|307|308)
      log "Self-test TrueNAS (${UPSTREAM}): REDIRECTED to ${loc}"
      if [[ "${loc}" == https://* && "${T_SCHEME}" == http ]]; then
        log "  TrueNAS forces HTTPS. Set truenas_url to https://${T_HOST} (with the HTTPS port if it isn't 443)."
      fi ;;
    403)
      log "Self-test TrueNAS (${UPSTREAM}): FORBIDDEN (HTTP 403)."
      log "  If TrueNAS has a Web Interface allowlist (System > General Settings > GUI), add your Home Assistant machine's IP." ;;
    000|"")
      log "Self-test TrueNAS (${UPSTREAM}): UNREACHABLE (${err:-no response})."
      if [ "${VERIFY_SSL}" = "true" ]; then
        log "  verify_ssl is on: TrueNAS's default certificate is self-signed, so turn it off unless you installed a trusted one."
      else
        log "  Check the address and port (Web Interface HTTP/HTTPS port in TrueNAS)."
      fi ;;
    *)
      log "Self-test TrueNAS (${UPSTREAM}): unexpected HTTP ${code}" ;;
  esac
  rm -f /tmp/ui.html

  if [ "${code}" = "200" ]; then
    out="$(curl -sS -m 10 -H 'X-Ingress-Path: /api/hassio_ingress/SELFTEST' http://127.0.0.1:8099/ui/ 2>&1)" || true
    if grep -q '<base href="/api/hassio_ingress/SELFTEST/ui/">' <<< "${out}" \
       && grep -q 'var P = "/api/hassio_ingress/SELFTEST"' <<< "${out}"; then
      log "Self-test panel: OK (base path and URL fix injected)"
    else
      log "Self-test panel: PROBLEM - index.html was not rewritten; the sidebar panel will not load"
    fi
  fi
}
selftest &

log "Proxying the TrueNAS web UI at ${UPSTREAM}"
exec nginx -g 'daemon off;'
