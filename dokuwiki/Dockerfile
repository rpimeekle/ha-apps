# https://developers.home-assistant.io/docs/apps/configuration#app-dockerfile
# Multi-arch Home Assistant base image (Alpine 3.24 + s6-overlay + bashio)
FROM ghcr.io/home-assistant/base:3.24-2026.08.0

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Supplied by the Supervisor / CI at build time
ARG BUILD_ARCH=amd64
ARG BUILD_VERSION=dev

# DokuWiki release to bundle (https://download.dokuwiki.org/archive)
ARG DOKUWIKI_VERSION="2026-07-14c"
ARG DOKUWIKI_MD5="7fe581ad8609205fd6a733b9e8ddd70c"

# The init step may take a while on very large wikis (permission fix-ups)
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# 1. Install nginx + PHP 8.4 (DokuWiki "Mort" needs PHP 8.2+)
# 2. Download and verify the official DokuWiki release
# 3. Move conf/, data/, lib/plugins and lib/tpl out of the webroot. They are
#    seeded into /config (addon_configs) on first start and symlinked back,
#    so wiki content survives restarts, rebuilds and updates.
# 4. Fail the build early if a PHP extension DokuWiki needs is missing
RUN \
    apk add --no-cache \
        nginx \
        php84 \
        php84-bz2 \
        php84-ctype \
        php84-curl \
        php84-dom \
        php84-fileinfo \
        php84-fpm \
        php84-gd \
        php84-iconv \
        php84-intl \
        php84-ldap \
        php84-mbstring \
        php84-opcache \
        php84-openssl \
        php84-pdo_sqlite \
        php84-session \
        php84-simplexml \
        php84-sodium \
        php84-sqlite3 \
        php84-xml \
        php84-xmlreader \
        php84-xmlwriter \
        php84-zip \
    \
    && curl -fsSL -o /tmp/dokuwiki.tgz \
        "https://download.dokuwiki.org/src/dokuwiki/dokuwiki-${DOKUWIKI_VERSION}.tgz" \
    && if [ -n "${DOKUWIKI_MD5}" ]; then \
        echo "${DOKUWIKI_MD5}  /tmp/dokuwiki.tgz" | md5sum -c - ; \
    fi \
    && mkdir -p /var/www/dokuwiki /usr/share/dokuwiki-dist \
    && tar -xzf /tmp/dokuwiki.tgz -C /var/www/dokuwiki --strip-components=1 \
    && rm -f /tmp/dokuwiki.tgz \
    \
    && cd /var/www/dokuwiki \
    && mv conf /usr/share/dokuwiki-dist/conf \
    && mv data /usr/share/dokuwiki-dist/data \
    && mv lib/plugins /usr/share/dokuwiki-dist/plugins \
    && mv lib/tpl /usr/share/dokuwiki-dist/tpl \
    && ln -s /config/conf conf \
    && ln -s /config/data data \
    && ln -s /config/plugins lib/plugins \
    && ln -s /config/tpl lib/tpl \
    && echo "${DOKUWIKI_VERSION}" > /usr/share/dokuwiki-dist/IMAGE_VERSION \
    \
    && php84 -r 'foreach (["gd","mbstring","xml","zlib","openssl","intl","session","json","pdo_sqlite"] as $e) { if (!extension_loaded($e)) { fwrite(STDERR, "missing php extension: $e\n"); exit(1); } }'

COPY rootfs /

# Tolerate Windows checkouts (CRLF) and lost executable bits
RUN \
    find /etc/s6-overlay /etc/nginx /etc/php84 /var/www/dokuwiki/inc/preload.php /usr/share/dokuwiki-ha \
        -type f -exec sed -i 's/\r$//' {} + \
    && chmod a+x \
        /etc/s6-overlay/scripts/*.sh \
        /etc/s6-overlay/s6-rc.d/*/run \
        /etc/s6-overlay/s6-rc.d/*/finish

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="app" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.name="DokuWiki" \
    io.hass.description="Lightweight, database-free wiki for Home Assistant" \
    org.opencontainers.image.title="DokuWiki for Home Assistant" \
    org.opencontainers.image.description="DokuWiki ${DOKUWIKI_VERSION} on nginx + PHP-FPM with Home Assistant ingress support" \
    org.opencontainers.image.source="https://github.com/rpimeekle/ha-apps" \
    org.opencontainers.image.licenses="MIT"
