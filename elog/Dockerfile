# syntax=docker/dockerfile:1
# ELOG has no release tags; master is the recommended source.
ARG ELOG_REPO=https://bitbucket.org/ritt/elog
ARG ELOG_REPO_FALLBACK=https://gitea.psi.ch/ELOG/elog.git
ARG ELOG_REF=master

# ---------- build stage ----------
FROM debian:bookworm-slim AS builder
ARG ELOG_REPO
ARG ELOG_REPO_FALLBACK
ARG ELOG_REF

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git cmake make g++ libssl-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN set -eux; \
    git clone --recursive "${ELOG_REPO}" elog \
      || git clone --recursive "${ELOG_REPO_FALLBACK}" elog; \
    cd elog; \
    git checkout "${ELOG_REF}"; \
    git submodule update --init --recursive; \
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release; \
    cmake --build build -j"$(nproc)"

# Stage binaries + web resources into /opt/elog
RUN set -eux; \
    mkdir -p /opt/elog/bin; \
    for b in elogd elog elconv; do \
      f="$(find /src/elog/build -maxdepth 2 -type f -name "$b" -perm -u+x | head -n1)"; \
      if [ -n "$f" ]; then install -m 0755 "$f" /opt/elog/bin/; fi; \
    done; \
    test -x /opt/elog/bin/elogd; \
    for d in themes resources scripts; do \
      if [ -d "/src/elog/$d" ]; then cp -a "/src/elog/$d" /opt/elog/; fi; \
    done; \
    test -d /opt/elog/themes; \
    strip /opt/elog/bin/* || true

# ---------- runtime stage ----------
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libssl3 libstdc++6 jq tzdata ca-certificates nginx \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system elog \
 && useradd --system --gid elog --home-dir /data/elog --shell /usr/sbin/nologin elog

COPY --from=builder /opt/elog /opt/elog
COPY rootfs/ /
COPY run.sh /run.sh
RUN chmod a+x /run.sh \
 && rm -f /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*

ARG BUILD_VERSION=dev
LABEL \
    io.hass.name="ELOG" \
    io.hass.description="Lightweight PSI ELOG electronic logbook server" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="ELOG for Home Assistant" \
    org.opencontainers.image.source="https://github.com/rpimeekle/ha-apps" \
    org.opencontainers.image.licenses="GPL-3.0-only"

EXPOSE 8080 8099
CMD ["/run.sh"]
