#!/usr/bin/env bash
# rca-method-gate.sh, exercised as a real subprocess against synthetic
# PreToolUse JSON on stdin.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"

# Production/CI supplies the real core checkout path via CORE_HOOKS_LIB;
# this is the sandbox fallback so the gate script can source gate-lib.sh.
CORE_HOOKS_LIB="${CORE_HOOKS_LIB:-/tmp/claude-1000/core-ref}"
export CORE_HOOKS_LIB

pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# Self-check registry: mandatory group counter (issue #10 requirement 3).
declare -A GROUPS_SEEN=()
mark_group() { GROUPS_SEEN["$1"]=1; }

REC=docs/issue-7/reports/incident-response.md

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

# run_raw: send an arbitrary JSON payload (built by caller) instead of the
# Write-shaped helper above, with optional extra env (e.g. kill-switch var).
run_raw() { # want name file payload_json [extra_env...]
  local want="$1" name="$2" file="$3" payload="$4"; shift 4
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  [ -n "$file" ] && mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

NO_METHOD='Impact: checkout down 20 minutes.
Primary cause: DB connection pool exhaustion.
Contributing factor: no alerting on pool saturation.
Action items: add alert, owner=jiwon, due 2026-08-15.'

NO_DISTINCTION='Impact: checkout down 20 minutes.
RCA method: 5 Whys applied to trace the failure chain.
Cause: DB connection pool exhaustion.
Action items: add alert, owner=jiwon, due 2026-08-15.'

GOOD='Impact: checkout down 20 minutes.
RCA method: 5 Whys applied to trace the failure chain.
Primary cause: DB connection pool exhaustion.
Contributing factor: no alerting on pool saturation.
Action items: add alert, owner=jiwon, due 2026-08-15.'

run deny  missing-rca-method    "$REC" "$NO_METHOD"
run deny  missing-distinction   "$REC" "$NO_DISTINCTION"
run allow both-present          "$REC" "$GOOD"
run allow outside-write-surface "docs/issue-7/proposals/incident-response.md" "$NO_METHOD"

# --- Group 3: malformed JSON on stdin -> deny (truncated / non-object / empty)
malformed() { # want name payload
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  printf '%s' "$3" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
malformed deny truncated-json '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/reports/incident-response.md","content":"x"'
malformed deny non-object-json '"just a string"'
malformed deny empty-json ''
mark_group malformed_json

# --- Group 1: Edit with replace_all:true against a multiply-occurring old_string
edit_replace_all() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  cat > "$td/$REC" <<'EOF'
Impact: checkout down 20 minutes.
RCA method: 5 Whys applied to trace the failure chain.
Cause: TBD.
Cause: TBD.
Action items: add alert, owner=jiwon, due 2026-08-15.
EOF
  payload="$(python3 -c '
import json
print(json.dumps({
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "'"$REC"'",
    "old_string": "Cause: TBD.",
    "new_string": "Primary cause: DB pool exhaustion.\nContributing factor: no alerting.",
    "replace_all": True
  },
  "cwd": "'"$td"'"
}))
')"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report allow "$got" edit-replace-all-multi-occurrence
  mark_group edit_replace_all
}
edit_replace_all

# --- Group 2: MultiEdit with mixed replace_all true/false in one call
multiedit_mixed() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  cat > "$td/$REC" <<'EOF'
Impact: checkout down 20 minutes.
Method: TBD.
Cause: TBD.
Cause: TBD.
Action items: add alert, owner=jiwon, due 2026-08-15.
EOF
  payload="$(python3 -c '
import json
print(json.dumps({
  "tool_name": "MultiEdit",
  "tool_input": {
    "file_path": "'"$REC"'",
    "edits": [
      {"old_string": "Method: TBD.", "new_string": "RCA method: 5 Whys applied.", "replace_all": False},
      {"old_string": "Cause: TBD.", "new_string": "Primary cause: X.\nContributing factor: Y.", "replace_all": True}
    ]
  },
  "cwd": "'"$td"'"
}))
')"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report allow "$got" multiedit-mixed-replace-all
  mark_group multiedit_mixed
}
multiedit_mixed

# --- Group 4: kill-switch set to unrecognized garbage value -> gate stays ACTIVE
killswitch_garbage() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$NO_METHOD")" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF=banana /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" killswitch-garbage-value-stays-active
  mark_group killswitch_garbage
}
killswitch_garbage

# --- Group 5: absolute file_path matching the same scope + "./"-prefixed relative
absolute_and_dot_relative() {
  # absolute path
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$td/$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$NO_METHOD")" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" absolute-file-path-same-scope

  # "./"-prefixed relative path
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "./$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$NO_METHOD")" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" dot-slash-prefixed-relative-path
  mark_group absolute_and_dot_relative
}
absolute_and_dot_relative

# --- Group 6: Bash-tool file write reaching the same target as a Write call
bash_write_target() {
  # deny case: file exists on the write surface but lacks required elements
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$NO_METHOD" > "$td/$REC"
  payload="$(python3 -c '
import json
print(json.dumps({
  "tool_name": "Bash",
  "tool_input": {"command": "cat notes.txt >> '"$REC"'"},
  "cwd": "'"$td"'"
}))
')"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" bash-write-target-missing-elements

  # allow case: file already satisfies both elements
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$GOOD" > "$td/$REC"
  payload="$(python3 -c '
import json
print(json.dumps({
  "tool_name": "Bash",
  "tool_input": {"command": "cat notes.txt >> '"$REC"'"},
  "cwd": "'"$td"'"
}))
')"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report allow "$got" bash-write-target-elements-present
  mark_group bash_write_target
}
bash_write_target

# --- Group 7 (semantic regression): "primary" and "contributing" appear in
# unrelated, cross-section paragraphs -> must NOT pass the distinction check.
CROSS_SECTION='Impact: checkout down 20 minutes.
RCA method: 5 Whys applied to trace the failure chain.

## Root cause
Cause: DB connection pool exhaustion. This was the primary driver of the
outage window and took the longest to diagnose.

## Unrelated notes
The on-call engineer was contributing to a different incident at the same
time, which delayed the initial response.

Action items: add alert, owner=jiwon, due 2026-08-15.'
run deny cross-section-distinction-not-scoped "$REC" "$CROSS_SECTION"
mark_group semantic_cross_section

# --- Self-check: assert every mandatory group actually ran (no silent skip).
EXPECTED_GROUPS="edit_replace_all multiedit_mixed malformed_json killswitch_garbage absolute_and_dot_relative bash_write_target semantic_cross_section"
missing_groups=""
for g in $EXPECTED_GROUPS; do
  [ -n "${GROUPS_SEEN[$g]:-}" ] || missing_groups="$missing_groups $g"
done
if [ -n "$missing_groups" ]; then
  fail=$((fail+1))
  printf 'FAIL   %-34s missing:%s\n' "self-check-all-groups-ran" "$missing_groups"
else
  pass=$((pass+1))
  printf 'ok     %-34s %d/%d groups\n' "self-check-all-groups-ran" "$(echo $EXPECTED_GROUPS | wc -w)" "$(echo $EXPECTED_GROUPS | wc -w)"
fi

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
