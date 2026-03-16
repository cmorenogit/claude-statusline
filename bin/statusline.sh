#!/opt/homebrew/bin/bash
# ^ Shebang is patched by install.js to match detected bash 4+ path
set -euo pipefail
input="$(cat)"

# ── Colors ─────────────────────────────────────────────
C='\033[36m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'; D='\033[90m'; RST='\033[0m'
W='\033[38;2;220;220;220m'
ORANGE='\033[38;2;255;176;85m'

# ── Detect platform ───────────────────────────────────
IS_MAC=false
[[ "$(uname)" == "Darwin" ]] && IS_MAC=true

# ── Single jq call: extract all fields at once ─────────
mapfile -t _f < <(echo "$input" | jq -r '
    (.model.display_name // "?"),
    (.workspace.project_dir // ""),
    (.workspace.current_dir // ""),
    (.context_window.used_percentage // 0 | floor | tostring),
    (.context_window.context_window_size // 200000 | tostring),
    (.transcript_path // ""),
    (.cost.total_lines_added // 0 | tostring),
    (.cost.total_lines_removed // 0 | tostring)
')
MODEL="${_f[0]}"; PROJECT_DIR="${_f[1]}"; CURRENT_DIR="${_f[2]}"
PCT="${_f[3]:-0}"; CTX_SIZE="${_f[4]}"; TRANSCRIPT="${_f[5]}"
ADDED="${_f[6]}"; REMOVED="${_f[7]}"

# ── Directory display ──────────────────────────────────
PROJECT_NAME="${PROJECT_DIR##*/}"
if [ "$CURRENT_DIR" = "$PROJECT_DIR" ]; then
    DIR_DISPLAY="$PROJECT_NAME"
else
    DIR_DISPLAY="$PROJECT_NAME/${CURRENT_DIR#$PROJECT_DIR/}"
fi

# ── Context color + bar ────────────────────────────────
if [ "$PCT" -ge 80 ]; then CLR="$R"
elif [ "$PCT" -ge 60 ]; then CLR="$Y"
else CLR="$G"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '#')$(printf "%${EMPTY}s" | tr ' ' '-')

# ── Git branch ─────────────────────────────────────────
BRANCH=""
if git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$CURRENT_DIR" branch --show-current 2>/dev/null || true)
fi

# ── Duration (wall-clock from transcript birth time) ───
DURATION="0m"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    START_EPOCH=""
    if $IS_MAC; then
        START_EPOCH=$(stat -f "%B" "$TRANSCRIPT" 2>/dev/null) || true
    else
        START_EPOCH=$(stat -c "%W" "$TRANSCRIPT" 2>/dev/null) || true
        # Fallback to mtime if birth time not supported
        [ "$START_EPOCH" = "0" ] || [ -z "$START_EPOCH" ] && \
            START_EPOCH=$(stat -c "%Y" "$TRANSCRIPT" 2>/dev/null) || true
    fi
    if [ -n "$START_EPOCH" ] && [ "$START_EPOCH" -gt 0 ] 2>/dev/null; then
        ELAPSED=$(( $(date +%s) - START_EPOCH ))
        if [ "$ELAPSED" -ge 3600 ]; then
            DURATION="$(( ELAPSED / 3600 ))h$(( (ELAPSED % 3600) / 60 ))m"
        elif [ "$ELAPSED" -ge 60 ]; then
            DURATION="$(( ELAPSED / 60 ))m"
        else
            DURATION="${ELAPSED}s"
        fi
    fi
fi

# ── Context window label ──────────────────────────────
if [ "$CTX_SIZE" -ge 1000000 ]; then CTX_LABEL="1M"
else CTX_LABEL="200K"; fi

# ── Line 1 ─────────────────────────────────────────────
LINE="${C}${MODEL}${RST} ${D}(${CTX_LABEL})${RST} | ${DIR_DISPLAY}"
[ -n "$BRANCH" ] && LINE+=" | ${BRANCH}"
LINE+=" | ${CLR}[${BAR}]${RST} ${PCT}%% | ${DURATION} | ${G}+${ADDED}${RST}/${R}-${REMOVED}${RST}"
printf "${LINE}\n"

# ── Rate limit helpers ─────────────────────────────────
color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$R"
    elif [ "$pct" -ge 70 ]; then printf "$Y"
    elif [ "$pct" -ge 50 ]; then printf "$ORANGE"
    else printf "$G"
    fi
}

build_bar() {
    local pct="${1:-0}" width="${2:-8}"
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color filled_str="" empty_str=""
    bar_color=$(color_for_pct "$pct")
    local i
    for ((i=0; i<filled; i++)); do filled_str+="●"; done
    for ((i=0; i<empty; i++)); do empty_str+="○"; done
    printf "${bar_color}${filled_str}${D}${empty_str}${RST}"
}

format_reset_time() {
    local iso_str="$1" style="$2"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    local epoch=""
    if $IS_MAC; then
        if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]]; then
            epoch=$(env TZ=UTC /bin/date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        else
            epoch=$(/bin/date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        fi
    else
        epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    fi
    [ -z "$epoch" ] && return
    case "$style" in
        time)
            if $IS_MAC; then
                /bin/date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]'
            else
                date -d "@$epoch" +"%l:%M%P" 2>/dev/null | sed 's/^ //'
            fi
            ;;
        datetime)
            if $IS_MAC; then
                /bin/date -j -r "$epoch" +"%b %-d, %l:%M%p" 2>/dev/null | sed 's/  / /g; s/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]'
            else
                date -d "@$epoch" +"%b %-d, %l:%M%P" 2>/dev/null | sed 's/  / /g; s/^ //'
            fi
            ;;
    esac
}

# ── OAuth token ────────────────────────────────────────
get_oauth_token() {
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"; return 0
    fi
    # macOS Keychain
    if command -v security >/dev/null 2>&1; then
        local blob token
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || true
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [ -n "$token" ] && [ "$token" != "null" ] && { echo "$token"; return 0; }
        fi
    fi
    # Credentials file
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        [ -n "$token" ] && [ "$token" != "null" ] && { echo "$token"; return 0; }
    fi
    # Linux secret-tool
    if command -v secret-tool >/dev/null 2>&1; then
        local blob token
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null) || true
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [ -n "$token" ] && [ "$token" != "null" ] && { echo "$token"; return 0; }
        fi
    fi
    echo ""
}

# ── Fetch usage data (cached 60s) ─────────────────────
cache_file="/tmp/claude/statusline-usage-cache.json"
mkdir -p /tmp/claude

needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
    if $IS_MAC; then
        cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
    else
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null)
    fi
    cache_age=$(( $(date +%s) - cache_mtime ))
    if [ "$cache_age" -lt 60 ]; then
        needs_refresh=false
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
fi

if $needs_refresh; then
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.34" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || true
        if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            usage_data="$response"
            echo "$response" > "$cache_file"
        fi
    fi
    [ -z "$usage_data" ] && [ -f "$cache_file" ] && usage_data=$(cat "$cache_file" 2>/dev/null)
fi

# ── Line 2: rate limits ───────────────────────────────
if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
    mapfile -t _u < <(echo "$usage_data" | jq -r '
        (.five_hour.utilization // 0 | round | tostring),
        (.seven_day.utilization // 0 | round | tostring),
        (.extra_usage.is_enabled // false | tostring),
        (.extra_usage.used_credits // 0 | . / 100 | tostring),
        (.extra_usage.monthly_limit // 0 | . / 100 | tostring),
        (.extra_usage.utilization // 0 | round | tostring),
        (.five_hour.resets_at // ""),
        (.seven_day.resets_at // "")
    ')
    five_pct="${_u[0]:-0}"; seven_pct="${_u[1]:-0}"
    extra_enabled="${_u[2]:-false}"; extra_used="${_u[3]:-0}"; extra_limit="${_u[4]:-0}"; extra_pct="${_u[5]:-0}"
    five_reset_iso="${_u[6]:-}"; seven_reset_iso="${_u[7]:-}"

    bar_width=8
    five_bar=$(build_bar "$five_pct" "$bar_width")
    five_clr=$(color_for_pct "$five_pct")
    five_reset=$(format_reset_time "$five_reset_iso" "time")

    seven_bar=$(build_bar "$seven_pct" "$bar_width")
    seven_clr=$(color_for_pct "$seven_pct")
    seven_reset=$(format_reset_time "$seven_reset_iso" "datetime")

    RATE="${W}current${RST} ${five_bar} ${five_clr}$(printf "%2d" "$five_pct")%%${RST}"
    [ -n "$five_reset" ] && RATE+=" ${D}⟳${RST} ${W}${five_reset}${RST}"
    RATE+="  ${D}│${RST}  ${W}weekly${RST} ${seven_bar} ${seven_clr}$(printf "%2d" "$seven_pct")%%${RST}"
    [ -n "$seven_reset" ] && RATE+=" ${D}⟳${RST} ${W}${seven_reset}${RST}"

    if [ "$extra_enabled" = "true" ]; then
        extra_bar=$(build_bar "$extra_pct" "$bar_width")
        extra_clr=$(color_for_pct "$extra_pct")
        extra_used_fmt=$(printf "%.2f" "$extra_used")
        extra_limit_fmt=$(printf "%.2f" "$extra_limit")
        RATE+="  ${D}│${RST}  ${W}extra${RST} ${extra_bar} ${extra_clr}\$${extra_used_fmt}${D}/${RST}${W}\$${extra_limit_fmt}${RST}"
    fi

    printf "${RATE}\n"
fi
