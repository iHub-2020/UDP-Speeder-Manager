# ============================================================================
# UDP-Speeder-Manager Docker Image
# ============================================================================
# Project: UDP-Speeder-Manager
# Author: iHub-2020
# Version: v2.2.0
# Base Image: Alpine Linux
# Date: 2026-01-17
# Description: UDP network accelerator with Forward Error Correction (FEC)
# Repository: https://github.com/iHub-2020/UDP-Speeder-Manager
# Upstream: https://github.com/iHub-2020/UDPspeeder
# Changelog:
#   v2.2.0 - Fix build: use precompiled binary from official release
#   v2.1.0 - Add persistent volume support
#   v2.0.0 - Migrate to Alpine Linux
# ============================================================================

FROM alpine:latest

LABEL maintainer="iHub-2020" \
      description="UDP network accelerator with FEC" \
      org.opencontainers.image.title="UDP-Speeder-Manager" \
      org.opencontainers.image.description="UDP network accelerator with FEC"

ARG SPEEDER_VERSION=20230206.0
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${SPEEDER_VERSION}"

# Install runtime dependencies
RUN apk add --no-cache su-exec bash curl ca-certificates

# Download precompiled binary from official repository
RUN ARCH=$(uname -m) && \
    case ${ARCH} in \
        x86_64) BINARY_ARCH="x86_64" ;; \
        aarch64) BINARY_ARCH="arm" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/iHub-2020/UDPspeeder/releases/download/${SPEEDER_VERSION}/speederv2_binaries.tar.gz" -o /tmp/speeder.tar.gz && \
    tar -xzf /tmp/speeder.tar.gz -C /tmp && \
    mv /tmp/speederv2_${BINARY_ARCH} /usr/local/bin/speederv2 && \
    chmod +x /usr/local/bin/speederv2 && \
    rm -rf /tmp/*

# Create user and directories
RUN addgroup -g 1000 speeder && \
    adduser -D -u 1000 -G speeder -s /bin/bash speeder && \
    mkdir -p /app/config /app/logs && \
    touch /app/logs/.keep && \
    echo "# UDP-Speeder-Manager config directory" > /app/config/README.txt && \
    chown -R 1000:1000 /app && \
    chmod -R 755 /app

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /app

# Expose default port
EXPOSE 29900/udp

# Volume for persistent data
VOLUME ["/app/config", "/app/logs"]

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /entrypoint.sh health

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
