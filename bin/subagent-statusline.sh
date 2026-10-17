#!/usr/bin/env bash
# Subagent rows for Claude Code's agent panel (subagentStatusLine).
#   running   → name · model[ · effort] · elapsed · tokens ↑ (growing) / ⏸ (flat for 4 ticks) · description
#   finished  → name · model · ✓ done 12m ago (✗ failed / ■ killed) · tokens · description
# stdin:  {columns, tasks:[{id,name,agentType,status,description,startTime,model,effort,tokenCount,tokenSamples,cwd}]}
# stdout: one JSON line per row: {"id": "...", "content": "..."}; on any error, print nothing
#         so Claude Code keeps its default rows.
# Env: SUBAGENT_SL_LOG=<file> appends the payload (without descriptions) whenever it changes.
input="$(cat)"
now="${EPOCHSECONDS:-$(date +%s)}"

# When each task was first seen finished: the payload has no end time. One state
# file per session, or concurrent sessions would overwrite each other's entries.
STATE_DIR="${TMPDIR:-/tmp}/claude-subagent-sl"
mkdir -p "$STATE_DIR" 2>/dev/null
sid=$(printf '%s' "$input" | jq -r '.session_id // "default" | gsub("[^A-Za-z0-9_-]"; "_")' 2>/dev/null) || exit 0
STATE="$STATE_DIR/finished-$sid.json"
[ -s "$STATE" ] || echo '{}' > "$STATE"

state=$(printf '%s' "$input" | jq -c --argjson now "$now" --slurpfile st "$STATE" '
  ($st[0] // {}) as $old
  | [.tasks[]? | select(.status != "running") | .id] as $done
  | reduce $done[] as $id ({}; .[$id] = ($old[$id] // $now))' 2>/dev/null) || exit 0
printf '%s' "$state" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"

if [ -n "${SUBAGENT_SL_LOG:-}" ]; then
    snap=$(printf '%s' "$input" | jq -c '[.tasks[]? | {id, name, agentType, status, model, effort, tokenCount, cwd}]' 2>/dev/null)
    last="$STATE_DIR/last-log-$sid"
    if [ -n "$snap" ] && [ "$snap" != "$(cat "$last" 2>/dev/null)" ]; then
        printf '%s\t%s\n' "$now" "$snap" >> "$SUBAGENT_SL_LOG"
        printf '%s' "$snap" > "$last"
    fi
fi

printf '%s' "$input" | jq -c --argjson now "$now" --argjson st "$state" '
  def short_model: if . == null then "?" else sub("^claude-"; "") | sub("-[0-9]{8}$"; "") end;
  def dur: floor as $s
    | if $s >= 3600 then "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor)m"
      elif $s >= 60 then "\($s / 60 | floor)m\($s % 60)s" else "\($s)s" end;
  def ktok: if . >= 1000 then "\(. / 1000 | floor)k" else tostring end;
  (.columns // 120) as $cols
  | .tasks[]? as $t
  | ($t.tokenSamples // []) as $s
  | (if $t.status == "running" then
       (if ($s | length) >= 4 and $s[-1] == $s[-4] then " ⏸"
        elif ($s | length) >= 2 and $s[-1] > $s[-2] then " ↑" else "" end) as $trend
       | [ ((($now * 1000) - ($t.startTime // ($now * 1000))) / 1000 | dur),
           (($t.tokenCount // 0 | ktok) + $trend) ]
     else
       (($now - ($st[$t.id] // $now)) | dur) as $ago
       | [ ({"completed": "✓ done", "failed": "✗ failed", "killed": "■ killed"}[$t.status] // $t.status)
             + " \($ago) ago",
           ($t.tokenCount // 0 | ktok) ]
     end) as $mid
  | ([ ($t.name // $t.agentType // "agent"),
       ($t.model | short_model),
       (if $t.effort != null then ($t.effort | tostring) else empty end) ] + $mid
     | join(" · ")) as $head
  | ($t.description // "") as $desc
  | ($cols - ($head | length) - 3) as $room
  | {id: $t.id,
     content: (if $desc == "" or $room < 8 then $head
               elif ($desc | length) > $room then "\($head) · \($desc[0:($room - 1)])…"
               else "\($head) · \($desc)" end)}' 2>/dev/null
exit 0
