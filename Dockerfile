# ============================================================================
# UDP-Speeder Docker Image
# ============================================================================
# 项目: UDP-Speeder-Manager
# 版本: v2.1
# 基础镜像: Debian 12 (Bookworm)
# 日期: 2026-01-16
# 描述: 双边网络加速工具，通过 FEC 技术对抗丢包
# ============================================================================

FROM debian:12-slim AS builder

LABEL maintainer="UDP-Speeder-Manager Project"
LABEL description="UDP network accelerator with FEC"

ARG BUILD_DATE
ARG VCS_REF

# 安装编译依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# 复制源码
COPY . .

# 生成版本信息并编译 (参考makefile: all target)
RUN echo "const char *gitversion = \"${VCS_REF:-unknown}\";" > git_version.h && \
    g++ -std=c++11 -Wall -Wextra -Wno-unused-variable \
        -Wno-unused-parameter -Wno-missing-field-initializers \
        -O2 -static -o speederv2 -I. \
        main.cpp log.cpp common.cpp lib/fec.cpp lib/rs.cpp \
        crc32/Crc32.cpp packet.cpp delay_manager.cpp fd_manager.cpp \
        connection.cpp fec_manager.cpp misc.cpp tunnel_client.cpp \
        tunnel_server.cpp my_ev.cpp -isystem libev -lrt

# ============================================================================
# 运行时镜像
# ============================================================================
FROM debian:12-slim

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.title="UDP-Speeder"
LABEL org.opencontainers.image.description="UDP network accelerator with FEC"

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    procps \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# 创建用户 (UID/GID=1000)
RUN groupadd -g 1000 speeder && \
    useradd -u 1000 -g 1000 -m -s /bin/bash speeder

# 复制二进制文件和脚本
COPY --from=builder /build/speederv2 /usr/local/bin/
COPY docker/entrypoint.sh /entrypoint.sh

# 设置权限
RUN chmod +x /usr/local/bin/speederv2 /entrypoint.sh && \
    mkdir -p /app/config /app/logs && \
    chown -R 1000:1000 /app

# 暴露端口 (默认4096，>1024无需特殊权限)
EXPOSE 29900/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /entrypoint.sh health

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
