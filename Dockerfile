FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    mktorrent \
    mediainfo \
    python3 \
    coreutils \
    grep \
    sed

COPY . /opt/cale-push/

# Default data directories
RUN mkdir -p /config /media /torrents /data

# Config can be mounted at /config or provided via LACALE_CONFIG
ENV LACALE_CONFIG=/config/config

WORKDIR /opt/cale-push
ENTRYPOINT ["/opt/cale-push/docker-entrypoint.sh"]
CMD ["help"]
