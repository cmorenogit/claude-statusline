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
    (.cost.total_lines_removed // 0 | tostring),
    (.workspace.git_worktree // ""),
    (.rate_limits.five_hour.used_percentage // "" | if . == "" then . else round | tostring end),
    (.rate_limits.seven_day.used_percentage // "" | if . == "" then . else round | tostring end),
    (.rate_limits.five_hour.resets_at // "" | tostring),
    (.rate_limits.seven_day.resets_at // "" | tostring)
')
MODEL="${_f[0]}"; PROJECT_DIR="${_f[1]}"; CURRENT_DIR="${_f[2]}"
PCT="${_f[3]:-0}"; TRANSCRIPT="${_f[4]}"
ADDED="${_f[5]}"; REMOVED="${_f[6]}"
GIT_WORKTREE="${_f[7]:-}"
RL_FIVE_PCT="${_f[8]:-}"; RL_SEVEN_PCT="${_f[9]:-}"
RL_FIVE_RESET="${_f[10]:-}"; RL_SEVEN_RESET="${_f[11]:-}"

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

# ── Git branch (read HEAD directly, no fork) ──────────
# Walks up to the repo root. In a linked worktree `.git` is a file
# ("gitdir: <path>"), so HEAD lives in that gitdir, not in .git/HEAD.
BRANCH=""
IS_WORKTREE=false
_dir="$CURRENT_DIR"
while [ -n "$_dir" ] && [ ! -e "$_dir/.git" ]; do
    [ "$_dir" = "/" ] && { _dir=""; break; }
    _dir="${_dir%/*}"; [ -z "$_dir" ] && _dir="/"
done
HEAD_FILE=""
if [ -n "$_dir" ] && [ -d "$_dir/.git" ]; then
    HEAD_FILE="$_dir/.git/HEAD"
elif [ -n "$_dir" ] && [ -f "$_dir/.git" ]; then
    _gitdir=$(< "$_dir/.git"); _gitdir="${_gitdir#gitdir: }"
    [[ "$_gitdir" != /* ]] && _gitdir="$_dir/$_gitdir"
    HEAD_FILE="$_gitdir/HEAD"
    if [[ "$_gitdir" == */.git/worktrees/* ]]; then
        IS_WORKTREE=true
        # Show the main repo name instead of the (long, branch-like) worktree folder name
        _main="${_gitdir%/.git/worktrees/*}"
        DIR_DISPLAY="${_main##*/}"
        [ "$CURRENT_DIR" != "$_dir" ] && DIR_DISPLAY+="/${CURRENT_DIR#$_dir/}"
    fi
fi
if [ -n "$HEAD_FILE" ] && [ -f "$HEAD_FILE" ]; then
    HEAD_CONTENT=$(< "$HEAD_FILE")
    if [[ "$HEAD_CONTENT" == ref:* ]]; then
        BRANCH="${HEAD_CONTENT#ref: refs/heads/}"
    else
        BRANCH="${HEAD_CONTENT:0:7}"
    fi
fi
[ -n "$GIT_WORKTREE" ] && IS_WORKTREE=true

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
ICO_WORKTREE=$'\U000f0645'  # 󰙅 md-file_tree

# Linked worktrees get their own marker (icon + label in one color) so the main
# checkout and a worktree never look alike. Layouts append it after the branch.
WT_MARK=""; WT_MARK_LEN=0
if $IS_WORKTREE && [ -n "$BRANCH" ]; then
    WT_MARK=" ${SECONDARY}${ICO_WORKTREE} wt${RST}"; WT_MARK_LEN=5
fi

# Shorten BRANCH so the line fits the terminal. $1 = visible columns the rest of
# the line uses. Claude Code sets COLUMNS (tput can't see the terminal here).
# First drops the type prefix (feature/, fix/…), then cuts the middle, keeping
# the start (usually the issue id) and the tail.
fit_branch() {
    [ -z "$BRANCH" ] || [ -z "${COLUMNS:-}" ] && return
    local avail=$(( COLUMNS - $1 - 4 ))
    [ "$avail" -lt 16 ] && avail=16
    [ "${#BRANCH}" -le "$avail" ] && return
    [[ "$BRANCH" == */* ]] && BRANCH="${BRANCH#*/}"
    [ "${#BRANCH}" -le "$avail" ] && return
    local head=$(( (avail - 1) * 2 / 3 ))
    local tail=$(( avail - 1 - head ))
    BRANCH="${BRANCH:0:head}…${BRANCH: -tail}"
}

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
    if [[ "$iso_str" =~ ^[0-9]+$ ]]; then
        epoch="$iso_str"  # stdin rate_limits.*.resets_at: Unix epoch seconds
    elif [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]]; then
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

# Claude Code (Pro/Max) sends rate_limits on stdin: use them and skip the API
# call. The API is only a fallback (no rate_limits on stdin) or opt-in via
# STATUSLINE_EXTRA_USAGE=1, since only the API reports extra-usage credits.
STDIN_LIMITS=false
if [ -n "$RL_FIVE_PCT$RL_SEVEN_PCT" ] && [ "${STATUSLINE_EXTRA_USAGE:-0}" != "1" ]; then
    STDIN_LIMITS=true
    needs_refresh=false
fi

if ! $STDIN_LIMITS && [ -f "$cache_file" ]; then
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

if $STDIN_LIMITS; then
    five_pct="${RL_FIVE_PCT:-0}"; seven_pct="${RL_SEVEN_PCT:-0}"
    five_reset_iso="$RL_FIVE_RESET"; seven_reset_iso="$RL_SEVEN_RESET"
    usage_data="stdin"  # layouts render the rate-limit block when this is non-empty
elif [ -n "$usage_data" ]; then
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
