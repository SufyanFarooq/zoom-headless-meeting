#!/bin/bash

# Script to check server resources and calculate bot capacity

load_env_file() {
    local env_file="$1"
    [ -f "$env_file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue
                ;;
        esac

        if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            continue
        fi

        local key="${line%%=*}"
        local value="${line#*=}"

        # Strip matching surrounding quotes only; do not execute the file.
        if [[ "$value" =~ ^\".*\"$ ]]; then
            value="${value:1:${#value}-2}"
        elif [[ "$value" =~ ^\'.*\'$ ]]; then
            value="${value:1:${#value}-2}"
        fi

        export "$key=$value"
    done < "$env_file"
}

# Load local .env when present so capacity reflects current deployment config.
load_env_file ".env"

echo "🔍 Checking Server Resources..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DOCKER_CMD=""
DOCKER_ERROR=""

if command -v docker > /dev/null 2>&1; then
    if docker info > /dev/null 2>&1; then
        DOCKER_CMD="docker"
    elif command -v sudo > /dev/null 2>&1 && sudo -n docker info > /dev/null 2>&1; then
        DOCKER_CMD="sudo -n docker"
    else
        DOCKER_ERROR="Docker is installed but this user cannot access it directly. Run this script with sudo or add the user to the docker group."
    fi
fi

# Get CPU info
echo "📊 CPU Information:"
CPU_CORES=$(nproc 2>/dev/null || echo "unknown")
echo "  Total CPU Cores: $CPU_CORES"

if [ "$CPU_CORES" != "unknown" ]; then
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo "  Current CPU Usage: ${CPU_USAGE}%"
fi
echo ""

# Get Memory info
echo "💾 Memory Information:"
if command -v free > /dev/null 2>&1; then
    MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
    MEM_USED=$(free -h | grep Mem | awk '{print $3}')
    MEM_AVAIL=$(free -h | grep Mem | awk '{print $7}')
    MEM_USAGE_PERCENT=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
    
    echo "  Total Memory: $MEM_TOTAL"
    echo "  Used Memory: $MEM_USED"
    echo "  Available Memory: $MEM_AVAIL"
    echo "  Memory Usage: ${MEM_USAGE_PERCENT}%"
    
    # Get raw values in MB for calculations
    MEM_TOTAL_MB=$(free -m | grep Mem | awk '{print $2}')
    MEM_AVAIL_MB=$(free -m | grep Mem | awk '{print $7}')
else
    echo "  free command not available"
    MEM_TOTAL_MB=0
    MEM_AVAIL_MB=0
fi
echo ""

# Get Disk space
echo "💿 Disk Space:"
if command -v df > /dev/null 2>&1; then
    df -h / | tail -1 | awk '{print "  Total: " $2 " | Used: " $3 " | Available: " $4 " | Usage: " $5}'
    DISK_AVAIL=$(df -m / | tail -1 | awk '{print $4}')
else
    echo "  df command not available"
    DISK_AVAIL=0
fi
echo ""

# Docker resource usage
echo "🐳 Docker Resource Usage:"
if [ -n "$DOCKER_CMD" ]; then
    RUNNING_CONTAINERS=$($DOCKER_CMD ps -q | wc -l)
    echo "  Running Containers: $RUNNING_CONTAINERS"
    
    if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
        echo ""
        echo "  Container Resource Usage:"
        $DOCKER_CMD stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | head -11
    fi
elif [ -n "$DOCKER_ERROR" ]; then
    echo "  $DOCKER_ERROR"
else
    echo "  Docker not available"
fi
echo ""

# Calculate bot capacity
echo "📈 Bot Capacity Calculation:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

get_mb() {
    local v="$1"
    if [[ "$v" =~ [Mm]$ ]]; then
        echo "${v%[Mm]}"
    elif [[ "$v" =~ [Gg]$ ]]; then
        local g="${v%[Gg]}"
        awk "BEGIN {printf \"%.0f\", $g * 1024}"
    else
        echo "$v"
    fi
}

has_effective_resource_value() {
    local v="${1:-}"
    local lower
    lower=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
    [ -n "$lower" ] || return 1
    case "$lower" in
        0|0.0|0m|0mb|0g|0gb)
            return 1
            ;;
    esac
    return 0
}

BOT_CPU_LIMIT="${BOT_CPU_LIMIT:-${VIDEO_CPU_LIMIT:-0.3}}"
BOT_MEMORY_LIMIT="$(get_mb "${BOT_MEMORY_LIMIT:-${VIDEO_MEM_LIMIT:-256M}}")"
BOT_CPU_RESERVATION="${BOT_CPU_RESERVATION:-${VIDEO_CPU_RESERVATION:-0.05}}"
BOT_MEMORY_RESERVATION="$(get_mb "${BOT_MEMORY_RESERVATION:-${VIDEO_MEM_RESERVATION:-128M}}")"

THROTTLE_ENABLED="${BOT_POST_JOIN_THROTTLE_ENABLED:-false}"
if [[ "$THROTTLE_ENABLED" =~ ^(1|true|yes|y|on)$ ]]; then
    if has_effective_resource_value "${BOT_POST_JOIN_THROTTLE_CPU:-}"; then
        BOT_CPU_LIMIT="${BOT_POST_JOIN_THROTTLE_CPU}"
    fi
    if has_effective_resource_value "${BOT_POST_JOIN_THROTTLE_MEMORY:-}"; then
        BOT_MEMORY_LIMIT="$(get_mb "${BOT_POST_JOIN_THROTTLE_MEMORY}")"
    fi
    if has_effective_resource_value "${BOT_POST_JOIN_THROTTLE_MEMORY_RESERVATION:-}"; then
        BOT_MEMORY_RESERVATION="$(get_mb "${BOT_POST_JOIN_THROTTLE_MEMORY_RESERVATION}")"
    fi
fi

echo "Current Bot Configuration:"
echo "  CPU Limit: ${BOT_CPU_LIMIT} cores per bot"
echo "  Memory Limit: ${BOT_MEMORY_LIMIT}MB per bot"
echo "  CPU Reservation: ${BOT_CPU_RESERVATION} cores per bot"
echo "  Memory Reservation: ${BOT_MEMORY_RESERVATION}MB per bot"
if [[ "$THROTTLE_ENABLED" =~ ^(1|true|yes|y|on)$ ]]; then
    echo "  Post-Join Throttle: enabled"
fi
echo ""

if [ "$CPU_CORES" != "unknown" ] && [ "$MEM_AVAIL_MB" -gt 0 ]; then
    # Calculate based on limits (more conservative)
    # Use awk for floating point division if bc is not available
    if command -v bc > /dev/null 2>&1; then
        MAX_BOTS_CPU_LIMIT=$(echo "scale=0; $CPU_CORES / $BOT_CPU_LIMIT" | bc 2>/dev/null | cut -d. -f1)
        MAX_BOTS_MEM_LIMIT=$(echo "scale=0; $MEM_AVAIL_MB / $BOT_MEMORY_LIMIT" | bc 2>/dev/null | cut -d. -f1)
        MAX_BOTS_CPU_RES=$(echo "scale=0; $CPU_CORES / $BOT_CPU_RESERVATION" | bc 2>/dev/null | cut -d. -f1)
        MAX_BOTS_MEM_RES=$(echo "scale=0; $MEM_AVAIL_MB / $BOT_MEMORY_RESERVATION" | bc 2>/dev/null | cut -d. -f1)
    else
        # Fallback to awk for division
        MAX_BOTS_CPU_LIMIT=$(awk "BEGIN {printf \"%.0f\", $CPU_CORES / $BOT_CPU_LIMIT}")
        MAX_BOTS_MEM_LIMIT=$(awk "BEGIN {printf \"%.0f\", $MEM_AVAIL_MB / $BOT_MEMORY_LIMIT}")
        MAX_BOTS_CPU_RES=$(awk "BEGIN {printf \"%.0f\", $CPU_CORES / $BOT_CPU_RESERVATION}")
        MAX_BOTS_MEM_RES=$(awk "BEGIN {printf \"%.0f\", $MEM_AVAIL_MB / $BOT_MEMORY_RESERVATION}")
    fi
    
    # Ensure we have valid numbers
    MAX_BOTS_CPU_LIMIT=${MAX_BOTS_CPU_LIMIT:-0}
    MAX_BOTS_MEM_LIMIT=${MAX_BOTS_MEM_LIMIT:-0}
    MAX_BOTS_CPU_RES=${MAX_BOTS_CPU_RES:-0}
    MAX_BOTS_MEM_RES=${MAX_BOTS_MEM_RES:-0}
    
    # Take the minimum of limit-based calculations (safest)
    if [ "$MAX_BOTS_CPU_LIMIT" -lt "$MAX_BOTS_MEM_LIMIT" ]; then
        MAX_BOTS_SAFE=$MAX_BOTS_CPU_LIMIT
    else
        MAX_BOTS_SAFE=$MAX_BOTS_MEM_LIMIT
    fi
    
    # Take the minimum of reservation-based calculations (optimistic)
    if [ "$MAX_BOTS_CPU_RES" -lt "$MAX_BOTS_MEM_RES" ]; then
        MAX_BOTS_OPTIMISTIC=$MAX_BOTS_CPU_RES
    else
        MAX_BOTS_OPTIMISTIC=$MAX_BOTS_MEM_RES
    fi
    
    echo "Estimated Bot Capacity:"
    echo "  Based on Limits (conservative): $MAX_BOTS_SAFE bots"
    echo "  Based on Reservations (optimistic): $MAX_BOTS_OPTIMISTIC bots"
    echo ""
    echo "📊 Detailed Breakdown:"
    echo "  CPU Limit: $MAX_BOTS_CPU_LIMIT bots ($CPU_CORES cores / $BOT_CPU_LIMIT per bot)"
    echo "  Memory Limit: $MAX_BOTS_MEM_LIMIT bots ($MEM_AVAIL_MB MB / $BOT_MEMORY_LIMIT MB per bot)"
    echo "  CPU Reservation: $MAX_BOTS_CPU_RES bots ($CPU_CORES cores / $BOT_CPU_RESERVATION per bot)"
    echo "  Memory Reservation: $MAX_BOTS_MEM_RES bots ($MEM_AVAIL_MB MB / $BOT_MEMORY_RESERVATION MB per bot)"
    echo ""
    echo "💡 Recommendation:"
    if [ -n "$DOCKER_CMD" ]; then
        CURRENT_BOTS=$($DOCKER_CMD ps --format "{{.Names}}" | grep -cE '^zoom-bot-[0-9]+-.*-[0-9]+$' || echo "0")
    else
        CURRENT_BOTS=0
    fi
    REMAINING_SAFE=$((MAX_BOTS_SAFE - CURRENT_BOTS))
    REMAINING_OPTIMISTIC=$((MAX_BOTS_OPTIMISTIC - CURRENT_BOTS))
    
    if [ "$MAX_BOTS_SAFE" -lt 10 ]; then
        echo "  ⚠️  Limited capacity. Consider:"
        echo "     - Reducing bot memory limit (if possible)"
        echo "     - Reducing bot CPU limit (if acceptable)"
        echo "     - Using a larger server"
    elif [ "$MAX_BOTS_SAFE" -lt 50 ]; then
        echo "  ✅ Can run $MAX_BOTS_SAFE bots safely (currently: $CURRENT_BOTS)"
        echo "  💡 Can add $REMAINING_SAFE more bots safely"
        echo "  💡 Can potentially run up to $MAX_BOTS_OPTIMISTIC bots with reservations"
        if [ "$REMAINING_OPTIMISTIC" -gt 0 ]; then
            echo "  💡 Can add $REMAINING_OPTIMISTIC more bots with reservations"
        fi
    else
        echo "  ✅ Excellent capacity! Can run $MAX_BOTS_SAFE+ bots (currently: $CURRENT_BOTS)"
        echo "  💡 Can add $REMAINING_SAFE more bots safely"
        echo "  💡 Can potentially run up to $MAX_BOTS_OPTIMISTIC bots with reservations"
        if [ "$REMAINING_OPTIMISTIC" -gt 0 ]; then
            echo "  💡 Can add $REMAINING_OPTIMISTIC more bots with reservations"
        fi
    fi
else
    echo "  ⚠️  Cannot calculate capacity (missing CPU or memory info)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
