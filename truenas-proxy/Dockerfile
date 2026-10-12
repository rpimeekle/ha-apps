# syntax=docker/dockerfile:1
FROM alpine:3.22
RUN apk add --no-cache nginx bash curl jq tzdata ca-certificates
COPY rootfs/ /
COPY run.sh /run.sh
RUN chmod a+x /run.sh

ARG BUILD_VERSION=dev
LABEL \
    io.hass.name="TrueNAS UI" \
    io.hass.description="TrueNAS web interface via Home Assistant ingress" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="TrueNAS UI for Home Assistant" \
    org.opencontainers.image.source="https://github.com/rpimeekle/ha-apps" \
    org.opencontainers.image.licenses="MIT"

EXPOSE 8099
CMD ["/run.sh"]
