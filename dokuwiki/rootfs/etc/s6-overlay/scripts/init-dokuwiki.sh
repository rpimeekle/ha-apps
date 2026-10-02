#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# DokuWiki app - one-shot initialisation
#   * seeds / upgrades the persistent wiki files in /config
#   * renders nginx and PHP settings from the app options
#   * fixes ownership so PHP (user nginx) can write to the wiki
# ==============================================================================
set -e

readonly WEBROOT="${DOKUWIKI_WEBROOT:-/var/www/dokuwiki}"
readonly DIST="${DOKUWIKI_DIST:-/usr/share/dokuwiki-dist}"
readonly STORE="${DOKUWIKI_STORE:-/config}"
readonly MARKER="${STORE}/.dokuwiki-version"

# ------------------------------------------------------------------------------
# Remove files that DokuWiki itself deleted between releases (data/deleted.files)
# from the persistent plugin / template folders, mirroring the official upgrade
# procedure. Anything still shipped in the current release is never touched.
# ------------------------------------------------------------------------------
remove_obsolete_files() {
    local line rel target
    [[ -f "${DIST}/data/deleted.files" ]] || return 0

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        case "${line}" in
            lib/plugins/?*) rel="plugins/${line#lib/plugins/}" ;;
            lib/tpl/?*)     rel="tpl/${line#lib/tpl/}" ;;
            *) continue ;;
        esac
        [[ "${rel}" == *..* ]] && continue
        [[ -e "${DIST}/${rel}" ]] && continue

        target="${STORE}/${rel}"
        if [[ -e "${target}" || -L "${target}" ]]; then
            rm -rf -- "${target}"
        fi
    done < "${DIST}/data/deleted.files"
}

# ------------------------------------------------------------------------------
# Persistent storage
# ------------------------------------------------------------------------------
image_version="$(<"${DIST}/IMAGE_VERSION")"
stored_version=""
if [[ -f "${MARKER}" ]]; then
    stored_version="$(<"${MARKER}")"
fi

mkdir -p "${STORE}/conf" "${STORE}/data" "${STORE}/plugins" "${STORE}/tpl"

if [[ ! -f "${STORE}/conf/dokuwiki.php" ]]; then
    bashio::log.info "No wiki found in ${STORE} - creating a fresh DokuWiki ${image_version}"
    cp -a "${DIST}/conf/." "${STORE}/conf/"
    cp -a "${DIST}/data/." "${STORE}/data/"
    cp -a "${DIST}/plugins/." "${STORE}/plugins/"
    cp -a "${DIST}/tpl/." "${STORE}/tpl/"

elif [[ "${stored_version}" != "${image_version}" ]]; then
    bashio::log.info "Updating wiki files from ${stored_version:-an unknown release} to ${image_version}"
    # Default config files belong to DokuWiki. Your own settings live in
    # local.php, *.local.conf, users.auth.php, acl.auth.php ... which are never
    # shipped and therefore never overwritten.
    cp -a "${DIST}/conf/." "${STORE}/conf/"
    # Refresh bundled plugins and templates; installed extensions stay put.
    cp -a "${DIST}/plugins/." "${STORE}/plugins/"
    cp -a "${DIST}/tpl/." "${STORE}/tpl/"
    # Add new data folders/files only - existing pages and media are kept.
    cp -an "${DIST}/data/." "${STORE}/data/"
    cp -a "${DIST}/data/deleted.files" "${STORE}/data/deleted.files"
    remove_obsolete_files
fi

echo "${image_version}" > "${MARKER}"

if [[ ! -f "${STORE}/README.txt" ]]; then
    cp /usr/share/dokuwiki-ha/README.txt "${STORE}/README.txt" 2>/dev/null || true
fi

# The installer is only needed until the wiki is configured
if [[ -f "${STORE}/conf/local.php" ]]; then
    rm -f "${WEBROOT}/install.php"
else
    bashio::log.notice "Wiki not configured yet - open the app's Web UI to run the installer (create the admin account)."
fi

# ------------------------------------------------------------------------------
# Options -> nginx / PHP
# ------------------------------------------------------------------------------
upload_limit="$(bashio::config 'upload_limit_mb')"
memory_limit="$(bashio::config 'memory_limit_mb')"
post_limit=$(( upload_limit + 8 ))

timezone="${TZ:-UTC}"
if ! TZ_CHECK="${timezone}" php84 -r \
    'exit(in_array(getenv("TZ_CHECK"), DateTimeZone::listIdentifiers(DateTimeZone::ALL_WITH_BC), true) ? 0 : 1);'
then
    bashio::log.warning "Time zone '${timezone}' is unknown to PHP, falling back to UTC"
    timezone="UTC"
fi

mkdir -p /etc/nginx/includes
sed \
    -e "s|__UPLOAD_LIMIT__|${upload_limit}|g" \
    /etc/nginx/templates/dokuwiki.conf.tmpl > /etc/nginx/includes/dokuwiki.conf

sed \
    -e "s|__UPLOAD_LIMIT__|${upload_limit}|g" \
    -e "s|__POST_LIMIT__|${post_limit}|g" \
    -e "s|__MEMORY_LIMIT__|${memory_limit}|g" \
    -e "s|__TIMEZONE__|${timezone}|g" \
    /etc/php84/templates/99-dokuwiki.ini.tmpl > /etc/php84/conf.d/99-dokuwiki.ini

bashio::log.info "Upload limit ${upload_limit} MB, PHP memory ${memory_limit} MB, time zone ${timezone}"

if ! nginx -t -q; then
    bashio::exit.nok "Generated nginx configuration is invalid"
fi

# ------------------------------------------------------------------------------
# Ownership - PHP runs as nginx and must be able to write the wiki
# ------------------------------------------------------------------------------
find "${STORE}/conf" "${STORE}/data" "${STORE}/plugins" "${STORE}/tpl" \
    \( ! -user nginx -o ! -group nginx \) -exec chown -h nginx:nginx {} +

bashio::log.info "DokuWiki ${image_version} is ready"
