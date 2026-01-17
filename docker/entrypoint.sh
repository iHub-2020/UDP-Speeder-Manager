#!/bin/bash
# ============================================================================
# UDP-Speeder-Manager Docker Entrypoint Script
# ============================================================================
# Project: UDP-Speeder-Manager
# Author: iHub-2020
# Version: v2.1.0
# Date: 2026-01-17
# Description: Docker container startup script with health check and user management
# Repository: https://github.com/iHub-2020/UDP-Speeder-Manager
# Changelog:
#   v2.1.0 - Fix persistent volume, enable default logging
#   v2.0.0 - Migrate to Alpine, separate basic/advanced parameters
#   v1.1.0 - Restructure the project
#   v1.0.0 - Initial release
# ============================================================================

set -e

# Health check function
health_check() {
    if pgrep -x speederv2 > /dev/null 2>&1; then
        exit 0
    else
        exit 1
    fi
}

# Setup user with PUID/PGID
setup_user() {
    PUID=${PUID:-1000}
    PGID=${PGID:-1000}
    
    if [ "$PUID" != "0" ] || [ "$PGID" != "0" ]; then
        echo "[INFO] Setting up user with PUID=$PUID PGID=$PGID"
        
        # Create group if not exists
        if ! getent group speeder > /dev/null 2>&1; then
            addgroup -g $PGID speeder 2>/dev/null || true
        fi
        
        # Create user if not exists
        if ! getent passwd speeder > /dev/null 2>&1; then
            adduser -D -u $PUID -G speeder speeder 2>/dev/null || true
        fi
        
        # Ensure persistent directories exist with correct permissions
        mkdir -p /app/config /app/logs
        chown -R $PUID:$PGID /app
        chmod -R 755 /app
        
        echo "[INFO] Persistent directories initialized"
        ls -la /app/
    fi
}

# Handle health check call
if [ "$1" = "health" ]; then
    health_check
fi

# Setup user
setup_user

# ============================================================================
# Basic Parameters (Required for normal usage)
# ============================================================================
MODE="${MODE:-server}"                  # Mode: server or client
LOCAL_ADDR="${LOCAL_ADDR:-0.0.0.0}"     # Local listen address
LOCAL_PORT="${LOCAL_PORT:-29900}"       # Local listen port
REMOTE_ADDR="${REMOTE_ADDR:-127.0.0.1}" # Remote target address
REMOTE_PORT="${REMOTE_PORT:-7777}"      # Remote target port
FEC_PARAMS="${FEC_PARAMS:-20:10}"       # FEC ratio (x:y = send y redundant for every x packets)
PASSWORD="${PASSWORD:-passwd}"          # XOR encryption key
WORK_MODE="${WORK_MODE:-0}"             # FEC mode: 0 (default, no MTU issue) or 1 (lower latency)
TIMEOUT="${TIMEOUT:-8}"                 # FEC encoding timeout (ms)

# ============================================================================
# Advanced Parameters (Optional, for fine-tuning)
# ============================================================================
QUEUE_LEN="${QUEUE_LEN:-}"              # FEC queue length (mode 0 only, default: 200)
INTERVAL="${INTERVAL:-}"                # Scatter packets interval to protect burst loss (ms)
JITTER="${JITTER:-}"                    # Simulated jitter (ms, default: 0)
MTU="${MTU:-}"                          # MTU value (default: 1250, don't change unless necessary)
REPORT="${REPORT:-}"                    # Send/recv report interval (seconds, 0=disabled)
DISABLE_OBSCURE="${DISABLE_OBSCURE:-0}" # Disable packet obfuscation (1=disable)
EXTRA_ARGS="${EXTRA_ARGS:-}"            # Additional custom arguments

# ============================================================================
# Logging Configuration (Default enabled)
# ============================================================================
LOG_FILE="${LOG_FILE:-/app/logs/speeder.log}"  # Default log file path
ENABLE_STDOUT="${ENABLE_STDOUT:-1}"            # Also output to stdout (1=yes, 0=no)

# ============================================================================
# Build Command
# ============================================================================
CMD="/usr/local/bin/speederv2"

# Set mode
if [ "$MODE" = "server" ] || [ "$MODE" = "-s" ]; then
    CMD="$CMD -s"
elif [ "$MODE" = "client" ] || [ "$MODE" = "-c" ]; then
    CMD="$CMD -c"
else
    echo "[ERROR] MODE must be 'server' or 'client'"
    exit 1
fi

# Basic parameters (always included)
CMD="$CMD -l${LOCAL_ADDR}:${LOCAL_PORT}"
CMD="$CMD -r${REMOTE_ADDR}:${REMOTE_PORT}"
CMD="$CMD -f${FEC_PARAMS}"
CMD="$CMD -k\"${PASSWORD}\""
CMD="$CMD --mode ${WORK_MODE}"
CMD="$CMD --timeout ${TIMEOUT}"

# Advanced parameters (only add if set)
[ -n "$MTU" ] && CMD="$CMD --mtu ${MTU}"
[ -n "$QUEUE_LEN" ] && CMD="$CMD -q${QUEUE_LEN}"
[ -n "$INTERVAL" ] && CMD="$CMD -i${INTERVAL}"
[ -n "$JITTER" ] && CMD="$CMD -j${JITTER}"
[ -n "$REPORT" ] && [ "$REPORT" != "0" ] && CMD="$CMD --report ${REPORT}"
[ "$DISABLE_OBSCURE" = "1" ] && CMD="$CMD --disable-obscure"
[ -n "$EXTRA_ARGS" ] && CMD="$CMD $EXTRA_ARGS"

# ============================================================================
# Display Configuration
# ============================================================================
echo "=========================================="
echo "UDP-Speeder-Manager Container"
echo "=========================================="
echo "Mode: $MODE"
echo "Listen: ${LOCAL_ADDR}:${LOCAL_PORT}"
echo "Remote: ${REMOTE_ADDR}:${REMOTE_PORT}"
echo "FEC: ${FEC_PARAMS}"
echo "Work Mode: ${WORK_MODE}"
echo "Timeout: ${TIMEOUT}ms"
[ -n "$QUEUE_LEN" ] && echo "Queue Len: ${QUEUE_LEN}"
[ -n "$INTERVAL" ] && echo "Interval: ${INTERVAL}ms"
[ -n "$JITTER" ] && echo "Jitter: ${JITTER}ms"
[ -n "$REPORT" ] && [ "$REPORT" != "0" ] && echo "Report: ${REPORT}s"
echo "Log File: ${LOG_FILE}"
echo "=========================================="
echo "Starting: $CMD"
echo "=========================================="

# ============================================================================
# Execute with logging
# ============================================================================
# Ensure log file directory exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chown ${PUID:-1000}:${PGID:-1000} "$LOG_FILE" 2>/dev/null || true

if [ "${PUID:-1000}" != "0" ]; then
    if [ "$ENABLE_STDOUT" = "1" ]; then
        # Output to both file and stdout
        exec su-exec speeder sh -c "$CMD 2>&1 | tee -a $LOG_FILE"
    else
        # Output to file only
        exec su-exec speeder sh -c "$CMD >> $LOG_FILE 2>&1"
    fi
else
    if [ "$ENABLE_STDOUT" = "1" ]; then
        exec sh -c "$CMD 2>&1 | tee -a $LOG_FILE"
    else
        exec sh -c "$CMD >> $LOG_FILE 2>&1"
    fi
fi
