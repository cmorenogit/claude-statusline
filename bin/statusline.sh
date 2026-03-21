#!/opt/homebrew/bin/bash
# ^ Shebang is patched by install.js to match detected bash 4+ path
set -euo pipefail
input="$(cat)"

# ── Theme & Layout ────────────────────────────────────
THEME_NAME="${STATUSLINE_THEME:-catppuccin-mocha}"
LAYOUT_NAME="${STATUSLINE_LAYOUT:-full}"
STATUSLINE_DIR="${HOME}/.claude/statusline-themes"
LAYOUT_DIR="${HOME}/.claude/statusline-layouts"
source "${STATUSLINE_DIR}/${THEME_NAME}.sh"
source "${LAYOUT_DIR}/${LAYOUT_NAME}.sh"
SEP="${SURFACE}│${RST}"

# ── Single jq call: extract all fields at once ─────────
mapfile -t _f < <(echo "$input" | jq -r '
    (.model.display_name // "?"),
    (.workspace.project_dir // ""),
    (.workspace.current_dir // ""),
    (.context_window.used_percentage // 0 | floor | tostring),
    (.transcript_path // ""),
    (.cost.total_lines_added // 0 | tostring),
    (.cost.total_lines_removed // 0 | tostring)
')
MODEL="${_f[0]}"; PROJECT_DIR="${_f[1]}"; CURRENT_DIR="${_f[2]}"
PCT="${_f[3]:-0}"; TRANSCRIPT="${_f[4]}"
ADDED="${_f[5]}"; REMOVED="${_f[6]}"

# ── Directory display ──────────────────────────────────
PROJECT_NAME="${PROJECT_DIR##*/}"
if [ "$CURRENT_DIR" = "$PROJECT_DIR" ]; then
    DIR_DISPLAY="$PROJECT_NAME"
else
    DIR_DISPLAY="$PROJECT_NAME/${CURRENT_DIR#$PROJECT_DIR/}"
fi

# ── Context color ─────────────────────────────────────
if [ "$PCT" -ge 80 ]; then CLR="$NEGATIVE"
elif [ "$PCT" -ge 60 ]; then CLR="$CAUTION"
else CLR="$POSITIVE"; fi

# ── Git branch (read .git/HEAD directly, no fork) ─────
BRANCH=""
HEAD_FILE="$CURRENT_DIR/.git/HEAD"
if [ -f "$HEAD_FILE" ]; then
    HEAD_CONTENT=$(< "$HEAD_FILE")
    if [[ "$HEAD_CONTENT" == ref:* ]]; then
        BRANCH="${HEAD_CONTENT#ref: refs/heads/}"
    else
        BRANCH="${HEAD_CONTENT:0:7}"
    fi
fi

# ── Duration (wall-clock from transcript birth time) ───
DURATION="0m"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    START_EPOCH=$(stat -f "%B" "$TRANSCRIPT" 2>/dev/null) || true
    if [ -n "$START_EPOCH" ] && [ "$START_EPOCH" -gt 0 ] 2>/dev/null; then
        ELAPSED=$(( EPOCHSECONDS - START_EPOCH ))
        if [ "$ELAPSED" -ge 3600 ]; then
            DURATION="$(( ELAPSED / 3600 ))h$(( (ELAPSED % 3600) / 60 ))m"
        elif [ "$ELAPSED" -ge 60 ]; then
            DURATION="$(( ELAPSED / 60 ))m"
        else
            DURATION="${ELAPSED}s"
        fi
    fi
fi

# ── Nerd Font icons ───────────────────────────────────
ICO_MODEL=$'\uf0e7'    #
ICO_DIR=$'\uf07b'      #
ICO_BRANCH=$'\ue725'   #
ICO_TIME=$'\uf017'     #
ICO_CTX=$'\uf085'      #
ICO_RATE=$'\uf0e7'     #
ICO_WEEK=$'\uf073'     #

# ── Rate limit helpers (no subshells — use namerefs) ──
color_for_pct() {
    local -n _clr_out=$1; local pct=$2
    if [ "$pct" -ge 90 ]; then _clr_out="$NEGATIVE"
    elif [ "$pct" -ge 70 ]; then _clr_out="$CAUTION"
    elif [ "$pct" -ge 50 ]; then _clr_out="$NOTICE"
    else _clr_out="$POSITIVE"
    fi
}

build_bar() {
    local -n _bar_out=$1; local pct="${2:-0}" width="${3:-10}"
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color filled_str empty_str
    color_for_pct bar_color "$pct"
    printf -v filled_str "%${filled}s" ""
    filled_str="${filled_str// /█}"
    printf -v empty_str "%${empty}s" ""
    empty_str="${empty_str// /░}"
    _bar_out="${bar_color}${filled_str}${SURFACE}${empty_str}${RST}"
}

format_reset_time() {
    local -n _time_out=$1; local iso_str="$2" style="$3"
    _time_out=""
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    local epoch=""
    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]]; then
        epoch=$(env TZ=UTC /bin/date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    else
        epoch=$(/bin/date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    fi
    [ -z "$epoch" ] && return
    case "$style" in
        time)
            _time_out=$(/bin/date -j -r "$epoch" +"%H:%M" 2>/dev/null) || return
            ;;
        datetime)
            local raw
            raw=$(/bin/date -j -r "$epoch" +"%b%-d %H:%M" 2>/dev/null) || return
            _time_out="${raw,,}"
            ;;
    esac
}

# ── OAuth token ────────────────────────────────────────
get_oauth_token() {
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"; return 0
    fi
    if command -v security >/dev/null 2>&1; then
        local blob token
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || true
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [ -n "$token" ] && [ "$token" != "null" ] && { echo "$token"; return 0; }
        fi
    fi
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        [ -n "$token" ] && [ "$token" != "null" ] && { echo "$token"; return 0; }
    fi
    echo ""
}

# ── Fetch usage data (cached 5min) ────────────────────
cache_file="/tmp/claude/statusline-usage-cache.json"
mkdir -p /tmp/claude

needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
    cache_age=$(( EPOCHSECONDS - cache_mtime ))
    if [ "$cache_age" -lt 300 ]; then
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

# ── Parse usage data ──────────────────────────────────
five_pct=0; seven_pct=0; extra_enabled="false"
extra_used=0; extra_limit=0; extra_pct=0
five_reset_iso=""; seven_reset_iso=""

if [ -n "$usage_data" ]; then
    mapfile -t _u < <(echo "$usage_data" | jq -r '
        (.five_hour.utilization // 0 | round | tostring),
        (.seven_day.utilization // 0 | round | tostring),
        (.extra_usage.is_enabled // false | tostring),
        (.extra_usage.used_credits // 0 | . / 100 | tostring),
        (.extra_usage.monthly_limit // 0 | . / 100 | tostring),
        (.extra_usage.utilization // 0 | round | tostring),
        (.five_hour.resets_at // ""),
        (.seven_day.resets_at // "")
    ' 2>/dev/null)
    five_pct="${_u[0]:-0}"; seven_pct="${_u[1]:-0}"
    extra_enabled="${_u[2]:-false}"; extra_used="${_u[3]:-0}"; extra_limit="${_u[4]:-0}"; extra_pct="${_u[5]:-0}"
    five_reset_iso="${_u[6]:-}"; seven_reset_iso="${_u[7]:-}"
fi

# ── Render ────────────────────────────────────────────
render
