#!/bin/bash
# ============================================================================
# UDPspeeder Docker Entrypoint Script
# ============================================================================
# 项目: UDP-Speeder-Manager
# 版本: v1.1.0
# 日期: 2026-01-16
# 描述: Docker 容器启动脚本，支持健康检查和动态用户切换
# ============================================================================

set -e

# 健康检查函数
health_check() {
    if pgrep -x speederv2 > /dev/null 2>&1; then
        exit 0
    else
        exit 1
    fi
}

# 处理 PUID/PGID
setup_user() {
    PUID=${PUID:-1000}
    PGID=${PGID:-1000}
    
    if [ "$PUID" != "0" ] || [ "$PGID" != "0" ]; then
        echo "Setting up user with PUID=$PUID PGID=$PGID"
        
        # 创建组（如果不存在）
        if ! getent group speeder > /dev/null 2>&1; then
            groupadd -g $PGID speeder 2>/dev/null || groupmod -g $PGID speeder
        fi
        
        # 创建用户（如果不存在）
        if ! getent passwd speeder > /dev/null 2>&1; then
            useradd -u $PUID -g $PGID -m -s /bin/bash speeder 2>/dev/null || usermod -u $PUID -g $PGID speeder
        fi
        
        # ⭐ 强制重新设置持久化目录权限
        mkdir -p /app/config /app/logs
        chown -R $PUID:$PGID /app
        chmod -R 755 /app
    fi
}

# 如果是健康检查调用
if [ "$1" = "health" ]; then
    health_check
fi

# 设置用户
setup_user

# 默认参数
MODE="${MODE:-server}"
LOCAL_ADDR="${LOCAL_ADDR:-0.0.0.0}"
LOCAL_PORT="${LOCAL_PORT:-29900}"
REMOTE_ADDR="${REMOTE_ADDR:-127.0.0.1}"
REMOTE_PORT="${REMOTE_PORT:-7777}"
FEC_PARAMS="${FEC_PARAMS:-20:10}"
PASSWORD="${PASSWORD:-passwd}"
WORK_MODE="${WORK_MODE:-0}"
TIMEOUT="${TIMEOUT:-8}"
QUEUE_LEN="${QUEUE_LEN:-200}"
INTERVAL="${INTERVAL:-0}"
JITTER="${JITTER:-0}"
MTU="${MTU:-1250}"
REPORT="${REPORT:-0}"
DISABLE_OBSCURE="${DISABLE_OBSCURE:-0}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
LOG_FILE="${LOG_FILE:-}"  # ⭐ 新增：可选日志文件路径

# 构建命令
CMD="/usr/local/bin/speederv2"

if [ "$MODE" = "server" ] || [ "$MODE" = "-s" ]; then
    CMD="$CMD -s"
elif [ "$MODE" = "client" ] || [ "$MODE" = "-c" ]; then
    CMD="$CMD -c"
else
    echo "Error: MODE must be 'server' or 'client'"
    exit 1
fi

CMD="$CMD -l${LOCAL_ADDR}:${LOCAL_PORT}"
CMD="$CMD -r${REMOTE_ADDR}:${REMOTE_PORT}"
CMD="$CMD -f${FEC_PARAMS}"
CMD="$CMD -k\"${PASSWORD}\""
CMD="$CMD --mode ${WORK_MODE}"
CMD="$CMD --timeout ${TIMEOUT}"

[ "$MTU" != "1250" ] && CMD="$CMD --mtu ${MTU}"
[ "$QUEUE_LEN" != "200" ] && CMD="$CMD -q${QUEUE_LEN}"
[ "$INTERVAL" != "0" ] && CMD="$CMD -i${INTERVAL}"
[ "$JITTER" != "0" ] && CMD="$CMD -j${JITTER}"
[ "$REPORT" != "0" ] && CMD="$CMD --report ${REPORT}"
[ "$DISABLE_OBSCURE" = "1" ] && CMD="$CMD --disable-obscure"
[ -n "$EXTRA_ARGS" ] && CMD="$CMD $EXTRA_ARGS"

echo "=========================================="
echo "UDP-Speeder Docker-Manager Container"
echo "=========================================="
echo "Mode: $MODE"
echo "Listen: ${LOCAL_ADDR}:${LOCAL_PORT}"
echo "Remote: ${REMOTE_ADDR}:${REMOTE_PORT}"
echo "FEC: ${FEC_PARAMS}"
echo "Work Mode: ${WORK_MODE}"
echo "Timeout: ${TIMEOUT}ms"
[ "$QUEUE_LEN" != "200" ] && echo "Queue Len: ${QUEUE_LEN}"
[ "$INTERVAL" != "0" ] && echo "Interval: ${INTERVAL}ms"
[ "$JITTER" != "0" ] && echo "Jitter: ${JITTER}ms"
[ "$REPORT" != "0" ] && echo "Report: ${REPORT}s"
echo "=========================================="
echo "Starting: $CMD"
echo "=========================================="

# ⭐ 日志重定向支持（可选）
if [ -n "$LOG_FILE" ]; then
    echo "Logging to: $LOG_FILE"
    if [ "${PUID:-1000}" != "0" ] && [ "${PGID:-1000}" != "0" ]; then
        exec gosu speeder sh -c "$CMD 2>&1 | tee -a $LOG_FILE"
    else
        exec sh -c "$CMD 2>&1 | tee -a $LOG_FILE"
    fi
else
    if [ "${PUID:-1000}" != "0" ] && [ "${PGID:-1000}" != "0" ]; then
        exec gosu speeder $CMD
    else
        exec $CMD
    fi
fi
