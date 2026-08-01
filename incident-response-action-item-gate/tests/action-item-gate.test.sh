#!/usr/bin/env bash
# Real-subprocess tests for hooks/action-item-gate.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"

# Production/CI supplies the real core checkout path for CORE_HOOKS_LIB
# (the gate script sources gate-lib.sh from it); this is the sandbox
# fallback so the suite is runnable standalone.
CORE_HOOKS_LIB="${CORE_HOOKS_LIB:-/tmp/claude-1000/core-ref}"
export CORE_HOOKS_LIB

pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-30s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-30s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# Self-check registry: each mandatory group increments this so "all
# green" cannot silently mean "some groups skipped."
declare -A GROUP_HIT=()
hit() { GROUP_HIT["$1"]=1; }

REC=docs/issue-7/reports/incident-response.md

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

# run_payload_raw: like run() but supplies a raw stdin payload (arbitrary
# tool_name/tool_input/env), for cases run() can't express (malformed
# JSON, kill-switch, Bash tool, pre-seeded file content, absolute paths).
run_payload_raw() { # want name payload extra_env...
  local want="$1" name="$2" payload="$3"; shift 3
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$payload" \
    | env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# helper: build a Write payload against a temp repo seeded with content
# already on disk, returning the tmp repo dir (caller must rm -rf it).
mk_repo() { # content -> prints tmp repo dir path on stdout
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$1" > "$td/docs/issue-7/reports/incident-response.md"
  printf '%s' "$td"
}

NO_SHAPE='# Incident Report
## Action Items
- Fix the retry loop eventually.
- Someone should look into the alerting gap.'

GOOD_SHAPE='# Incident Report
## Action Items
- Jiwon Jung: patch the retry loop by 2026-08-15
- Investigate alerting gap (owner TBD)'

run deny  no-owner-deadline-shape "$REC" "$NO_SHAPE"
run allow owner-deadline-shape    "$REC" "$GOOD_SHAPE"
run allow foreign-path            "docs/issue-7/reports/qa.md" "$NO_SHAPE"

# --- Group 3: malformed JSON (truncated, non-object, empty) ---------------
malformed() { # want name payload
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$3" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
malformed deny non-object-json      '"just a string"'
malformed deny truncated-json       '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/reports/incident-response.md","content":"foo'
malformed deny empty-payload        ''
hit group3_malformed

# --- Group 1: Edit with replace_all:true against a multiply-occurring old_string
EXISTING_MULTI='# Incident Report
## Action Items
- TODO: patch the retry loop by 2026-08-15
- TODO: investigate the alerting gap by 2026-08-20'
td="$(mk_repo "$EXISTING_MULTI")"
payload=$(python3 - "$td" <<'PY'
import json, sys
td = sys.argv[1]
ev = {
    "tool_name": "Edit",
    "tool_input": {
        "file_path": "docs/issue-7/reports/incident-response.md",
        "old_string": "TODO",
        "new_string": "Jiwon Jung",
        "replace_all": True,
    },
    "cwd": td,
}
print(json.dumps(ev))
PY
)
printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report allow "$got" "edit-replace-all-true-multi-occurrence"
hit group1_edit_replace_all

# --- Group 2: MultiEdit with mixed replace_all true/false in one call -----
EXISTING_MULTI2='# Incident Report
## Action Items
- OWNER1: patch the retry loop by DEADLINE1
- OWNER1: investigate the alerting gap by DEADLINE1'
td="$(mk_repo "$EXISTING_MULTI2")"
payload=$(python3 - "$td" <<'PY'
import json, sys
td = sys.argv[1]
ev = {
    "tool_name": "MultiEdit",
    "tool_input": {
        "file_path": "docs/issue-7/reports/incident-response.md",
        "edits": [
            {"old_string": "OWNER1", "new_string": "Jiwon Jung", "replace_all": True},
            {"old_string": "DEADLINE1", "new_string": "2026-08-15", "replace_all": False},
        ],
    },
    "cwd": td,
}
print(json.dumps(ev))
PY
)
printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report allow "$got" "multiedit-mixed-replace-all"
hit group2_multiedit_mixed

# --- Group 4: kill-switch set to unrecognized garbage -> stays ACTIVE -----
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$NO_SHAPE")" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF=banana /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report deny "$got" "kill-switch-unrecognized-value-stays-active"
hit group4_kill_switch

# recognized on-spelling actually disables (sanity: bad shape would
# normally deny, but the switch is on, so it must allow). Uses stdin
# redirection (not a pipe) because the gate exits before reading stdin
# once the kill switch disables it, which would SIGPIPE a pipe writer.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
pf="$td/payload.json"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$NO_SHAPE")" "$td" > "$pf"
env CLAUDE_PROJECT_DIR="$td" INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF=1 /bin/bash "$HOOKS/action-item-gate.sh" < "$pf" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report allow "$got" "kill-switch-recognized-on-disables"

# --- Group 5: absolute file_path + ./-prefixed relative variant -----------
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
abs="$td/docs/issue-7/reports/incident-response.md"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$abs" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$NO_SHAPE")" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report deny "$got" "absolute-file-path-same-scope"

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "./docs/issue-7/reports/incident-response.md" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$NO_SHAPE")" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report deny "$got" "dot-slash-prefixed-relative-path"
hit group5_abs_and_dotslash

# --- Group 6: Bash-tool file write reaching the same target ---------------
# Deny case: file already exists with bad shape, Bash command writes to it.
BAD_FILE_CONTENT="$NO_SHAPE"
td="$(mk_repo "$BAD_FILE_CONTENT")"
payload=$(python3 - "$td" <<'PY'
import json, sys
td = sys.argv[1]
ev = {
    "tool_name": "Bash",
    "tool_input": {"command": "cat >> docs/issue-7/reports/incident-response.md <<'EOF'\nmore text\nEOF"},
    "cwd": td,
}
print(json.dumps(ev))
PY
)
printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report deny "$got" "bash-write-to-bad-shape-record"

# Allow case: file already has good shape, Bash command targets it.
td="$(mk_repo "$GOOD_SHAPE")"
payload=$(python3 - "$td" <<'PY'
import json, sys
td = sys.argv[1]
ev = {
    "tool_name": "Bash",
    "tool_input": {"command": "cat >> docs/issue-7/reports/incident-response.md <<'EOF'\nmore text\nEOF"},
    "cwd": td,
}
print(json.dumps(ev))
PY
)
printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"
report allow "$got" "bash-write-equivalent-to-write-tool-allow"
hit group6_bash_write

# --- Group 7: semantic regression — mid-sentence capitalized word must NOT
# be treated as an owner, even with a deadline present. -------------------
MID_SENTENCE_CAP='# Incident Report
## Action Items
- Investigate alerting gap by 2026-08-15'
run deny mid-sentence-capitalized-word-not-owner "$REC" "$MID_SENTENCE_CAP"
hit group7_semantic_owner

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"

# --- Self-check: assert every mandatory group actually ran ---------------
required_groups=(
  group1_edit_replace_all
  group2_multiedit_mixed
  group3_malformed
  group4_kill_switch
  group5_abs_and_dotslash
  group6_bash_write
  group7_semantic_owner
)
missing=0
for g in "${required_groups[@]}"; do
  if [ -z "${GROUP_HIT[$g]:-}" ]; then
    echo "SELF-CHECK FAIL: required test group not exercised: $g" >&2
    missing=$((missing+1))
  fi
done
if [ "$missing" -eq 0 ]; then
  printf 'self-check: all %d mandatory groups exercised\n' "${#required_groups[@]}"
else
  fail=$((fail+missing))
fi

[ "$fail" -eq 0 ]
