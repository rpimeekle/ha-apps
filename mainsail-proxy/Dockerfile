# syntax=docker/dockerfile:1
# Pinned Mainsail release. Bump it together with the app version; the patch
# step fails the build if a new release changes the code it adjusts.
ARG MAINSAIL_VERSION=v2.19.0

# ---------- fetch + patch stage ----------
FROM alpine:3.22 AS builder
ARG MAINSAIL_VERSION
RUN apk add --no-cache curl unzip python3
COPY patch_mainsail.py /patch_mainsail.py
RUN set -eux; \
    curl -fsSL -o /tmp/mainsail.zip \
      "https://github.com/mainsail-crew/mainsail/releases/download/${MAINSAIL_VERSION}/mainsail.zip"; \
    mkdir -p /www; \
    unzip -q /tmp/mainsail.zip -d /www; \
    python3 /patch_mainsail.py /www

# ---------- runtime stage ----------
FROM alpine:3.22
RUN apk add --no-cache nginx bash curl jq tzdata ca-certificates
COPY --from=builder /www /var/www/mainsail
COPY rootfs/ /
COPY run.sh /run.sh
RUN chmod a+x /run.sh

ARG BUILD_VERSION=dev
ARG MAINSAIL_VERSION
LABEL \
    io.hass.name="Mainsail" \
    io.hass.description="Mainsail web interface for Klipper via Home Assistant ingress" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="Mainsail for Home Assistant" \
    org.opencontainers.image.version="${BUILD_VERSION}-mainsail-${MAINSAIL_VERSION}" \
    org.opencontainers.image.source="https://github.com/rpimeekle/ha-apps" \
    org.opencontainers.image.licenses="GPL-3.0-only"

EXPOSE 8099
CMD ["/run.sh"]
