# Layout Name — short description
#
# To create a new layout:
# 1. Copy this file: cp _template.sh my-layout.sh
# 2. Implement render() using the variables and helpers below
# 3. Install: npx @cmorenogit/claude-statusline
# 4. Activate: export STATUSLINE_LAYOUT=my-layout
#
# ── Available variables ──────────────────────────────
#
# Session:
#   MODEL        — model display name (e.g., "Opus 4.6")
#   DIR_DISPLAY  — project directory (e.g., "app-profile")
#   BRANCH       — git branch (empty if not in repo); call fit_branch <cols used by the rest of the line> to shorten it
#   WT_MARK      — worktree marker to append after BRANCH (empty outside linked worktrees); WT_MARK_LEN = its width
#   ADDED        — lines added in session
#   REMOVED      — lines removed in session
#   DURATION     — session wall-clock time (e.g., "12m", "1h30m")
#   PCT          — context window usage percentage (0-100)
#   CLR          — color for PCT (POSITIVE/CAUTION/NEGATIVE)
#
# Rate limits (only if usage_data is non-empty):
#   five_pct       — 5-hour window utilization %
#   seven_pct      — 7-day window utilization %
#   five_reset_iso — 5-hour reset time (ISO 8601)
#   seven_reset_iso — 7-day reset time (ISO 8601)
#   extra_enabled  — "true" if extra credits active
#   extra_used     — extra credits used (dollars)
#   extra_limit    — extra credits limit (dollars)
#   extra_pct      — extra credits utilization %
#
# ── Theme tokens (colors) ────────────────────────────
#
#   PRIMARY SECONDARY POSITIVE NOTICE CAUTION NEGATIVE
#   TEXT SUBTEXT OVERLAY SURFACE RST
#   SEP — pre-built separator "│" in SURFACE color
#
# ── Icons (Nerd Font) ────────────────────────────────
#
#   ICO_MODEL ICO_DIR ICO_BRANCH ICO_TIME ICO_CTX ICO_RATE ICO_WEEK ICO_WORKTREE
#
# ── Helper functions ─────────────────────────────────
#
#   color_for_pct <nameref> <pct>
#     Sets nameref to POSITIVE/NOTICE/CAUTION/NEGATIVE based on %
#
#   build_bar <nameref> <pct> [width=10]
#     Builds a block bar (█░) into nameref, colored by severity
#
#   format_reset_time <nameref> <iso_string> <style>
#     Parses ISO time into nameref. style: "time" (HH:MM) or "datetime" (mmmDD HH:MM)

render() {
    # Your layout here
    printf "Hello from my-layout\n"
}
