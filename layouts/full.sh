# Full layout — 2 lines with progress bars and reset times
render() {
    # ── Line 1 ────────────────────────────────────────
    local LINE="${PRIMARY}${ICO_MODEL} ${MODEL}${RST} ${SEP} ${TEXT}${ICO_DIR} ${DIR_DISPLAY}${RST}"
    [ -n "$BRANCH" ] && LINE+=" ${SEP} ${POSITIVE}${ICO_BRANCH} ${BRANCH}${RST}"
    LINE+=" ${SEP} ${POSITIVE}+${ADDED}${RST}/${NEGATIVE}-${REMOVED}${RST}"
    printf "${LINE}\n"

    # ── Line 2 ────────────────────────────────────────
    build_bar ctx_bar "$PCT"
    local LINE2="${SECONDARY}${ICO_CTX}  ${RST}${ctx_bar} ${CLR}${PCT}%%${RST}"
    LINE2+=" ${SEP} ${SUBTEXT}${ICO_TIME} ${DURATION}${RST}"

    if [ -n "$usage_data" ]; then
        build_bar five_bar "$five_pct"
        color_for_pct five_clr "$five_pct"
        format_reset_time five_reset "$five_reset_iso" "time"

        build_bar seven_bar "$seven_pct"
        color_for_pct seven_clr "$seven_pct"
        format_reset_time seven_reset "$seven_reset_iso" "datetime"

        LINE2+=" ${SEP} ${NOTICE}${ICO_RATE}  ${RST}${five_bar} ${five_clr}${five_pct}%%${RST}"
        [ -n "$five_reset" ] && LINE2+=" ${NOTICE}󰑐${RST} ${OVERLAY}${five_reset}${RST}"
        LINE2+=" ${SEP} ${PRIMARY}${ICO_WEEK}  ${RST}${seven_bar} ${seven_clr}${seven_pct}%%${RST}"

        [ -n "$seven_reset" ] && LINE2+=" ${PRIMARY}󰑐${RST} ${OVERLAY}${seven_reset}${RST}"

        if [ "$extra_enabled" = "true" ]; then
            build_bar extra_bar "$extra_pct"
            color_for_pct extra_clr "$extra_pct"
            printf -v extra_used_fmt "%.2f" "$extra_used"
            printf -v extra_limit_fmt "%.2f" "$extra_limit"
            LINE2+=" ${SEP} ${CAUTION}$ ${RST}${extra_bar} ${extra_clr}\$${extra_used_fmt}${SURFACE}/${RST}${TEXT}\$${extra_limit_fmt}${RST}"
        fi
    fi

    printf "${LINE2}\n"
}
