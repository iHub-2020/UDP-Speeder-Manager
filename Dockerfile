# ============================================================================
# UDP-Speeder-Manager Docker Image
# ============================================================================
# Project: UDP-Speeder-Manager
# Version: v2.1
# Base Image: Alpine Linux
# Date: 2026-01-17
# Description: UDP network accelerator with Forward Error Correction (FEC)
# Repository: https://github.com/iHub-2020/UDP-Speeder-Manager
# ============================================================================

FROM alpine:latest AS builder

LABEL maintainer="iHub-2020"
LABEL description="UDP network accelerator with FEC"

ARG BUILD_DATE
ARG VCS_REF

# Install build dependencies
RUN apk add --no-cache build-base git

WORKDIR /build

# Copy source code
COPY . .

# Generate version info and compile (static binary)
RUN echo "const char *gitversion = \"${VCS_REF:-unknown}\";" > git_version.h && \
    g++ -std=c++11 -Wall -Wextra -Wno-unused-variable \
        -Wno-unused-parameter -Wno-missing-field-initializers \
        -O2 -static -o speederv2 -I. \
        main.cpp log.cpp common.cpp lib/fec.cpp lib/rs.cpp \
        crc32/Crc32.cpp packet.cpp delay_manager.cpp fd_manager.cpp \
        connection.cpp fec_manager.cpp misc.cpp tunnel_client.cpp \
        tunnel_server.cpp my_ev.cpp -lrt

# ============================================================================
# Runtime Image
# ============================================================================
FROM alpine:latest

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.title="UDP-Speeder-Manager"
LABEL org.opencontainers.image.description="UDP network accelerator with FEC"

# Install runtime dependencies (su-exec for user switching)
RUN apk add --no-cache su-exec bash

# Create user (UID/GID=1000)
RUN addgroup -g 1000 speeder && \
    adduser -D -u 1000 -G speeder -s /bin/bash speeder

# Copy binary and entrypoint script
COPY --from=builder /build/speederv2 /usr/local/bin/
COPY docker/entrypoint.sh /entrypoint.sh

# Set permissions
RUN chmod +x /usr/local/bin/speederv2 /entrypoint.sh && \
    mkdir -p /app/config /app/logs && \
    chown -R 1000:1000 /app

# Expose default port
EXPOSE 29900/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /entrypoint.sh health

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
