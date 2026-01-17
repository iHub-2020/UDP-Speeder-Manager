# ============================================================================
# UDP-Speeder-Manager Docker Image (Build from Source)
# ============================================================================
# Project: UDP-Speeder-Manager
# Author: iHub-2020
# Version: v2.2.0
# Base Image: Alpine Linux
# Date: 2026-01-17
# Description: UDP network accelerator with FEC (compiled from official source)
# Repository: https://github.com/iHub-2020/UDP-Speeder-Manager
# Upstream: https://github.com/wangyu-/UDPspeeder
# ============================================================================

FROM alpine:latest AS builder

ARG SPEEDER_VERSION=20230206.0

# Install build dependencies
RUN apk add --no-cache build-base git linux-headers

WORKDIR /build

# Clone official UDPspeeder repository
RUN git clone --depth 1 --branch ${SPEEDER_VERSION} \
    https://github.com/wangyu-/UDPspeeder.git . || \
    git clone --depth 1 https://github.com/wangyu-/UDPspeeder.git .

# Compile static binary
RUN make -j$(nproc) && \
    strip speederv2_amd64 || strip speederv2_* || true

# ============================================================================
# Runtime Image
# ============================================================================
FROM alpine:latest

ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="iHub-2020" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="UDP-Speeder-Manager" \
      org.opencontainers.image.description="UDP network accelerator with FEC"

# Install runtime dependencies
RUN apk add --no-cache su-exec bash

# Copy binary from builder
COPY --from=builder /build/speederv2_* /usr/local/bin/speederv2

# Create user and directories
RUN chmod +x /usr/local/bin/speederv2 && \
    addgroup -g 1000 speeder && \
    adduser -D -u 1000 -G speeder -s /bin/bash speeder && \
    mkdir -p /app/config /app/logs && \
    touch /app/logs/.keep && \
    echo "# UDP-Speeder config directory" > /app/config/README.txt && \
    chown -R 1000:1000 /app && \
    chmod -R 755 /app

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app

EXPOSE 29900/udp

VOLUME ["/app/config", "/app/logs"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /entrypoint.sh health

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
