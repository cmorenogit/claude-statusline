# Compact layout — single line, no bars, no reset times
render() {
    local LINE="${PRIMARY}${ICO_MODEL} ${MODEL}${RST} ${SEP} ${TEXT}${ICO_DIR} ${DIR_DISPLAY}${RST}"
    # model │ dir │ branch[wt] │ +a/-r — everything but the branch name itself
    fit_branch $(( 2 + ${#MODEL} + 3 + 2 + ${#DIR_DISPLAY} + 3 + 2 + WT_MARK_LEN + 3 + ${#ADDED} + ${#REMOVED} + 3 + 3 + 3 + ${#PCT} + 1 + 3 + 2 + ${#DURATION} ))
    [ -n "$BRANCH" ] && LINE+=" ${SEP} ${POSITIVE}${ICO_BRANCH} ${BRANCH}${RST}${WT_MARK}"
    LINE+=" ${SEP} ${POSITIVE}+${ADDED}${RST}/${NEGATIVE}-${REMOVED}${RST}"
    LINE+=" ${SEP} ${SECONDARY}${ICO_CTX}  ${CLR}${PCT}%%${RST}"
    LINE+=" ${SEP} ${SUBTEXT}${ICO_TIME} ${DURATION}${RST}"

    if [ -n "$usage_data" ]; then
        color_for_pct five_clr "$five_pct"
        color_for_pct seven_clr "$seven_pct"

        LINE+=" ${SEP} ${NOTICE}${ICO_RATE} ${five_clr}${five_pct}%%${RST}"
        LINE+=" ${SEP} ${PRIMARY}${ICO_WEEK} ${seven_clr}${seven_pct}%%${RST}"

        if [ "$extra_enabled" = "true" ]; then
            color_for_pct extra_clr "$extra_pct"
            printf -v extra_used_fmt "%.2f" "$extra_used"
            LINE+=" ${SEP} ${CAUTION}$ ${extra_clr}\$${extra_used_fmt}${RST}"
        fi
    fi

    printf "${LINE}\n"
}
