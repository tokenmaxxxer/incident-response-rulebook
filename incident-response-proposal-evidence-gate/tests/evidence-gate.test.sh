#!/usr/bin/env bash
# Exercises evidence-gate.sh as a real subprocess against synthetic
# PreToolUse JSON.
set -uo pipefail

# Production/CI supplies the real core checkout path via CLAUDE_PLUGIN_ROOT_CORE;
# this is the sandbox fallback so the test file is runnable standalone.
CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-/tmp/claude-1000/core-ref2}"
export CLAUDE_PLUGIN_ROOT_CORE

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-28s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-28s want=%s got=%s\n' "$3" "$1" "$2"; [ -n "${DEBUG_TESTS:-}" ] && printf '  log: %s\n' "$LAST_LOG"; fi; }

# Self-check counter: incremented once per mandatory group so "all green"
# cannot silently mean "some groups skipped."
declare -A GROUP_HIT
mark_group() { GROUP_HIT["$1"]=1; }

TARGET=docs/issue-7/proposals/incident-response.md

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  LAST_LOG="$(cat "$td/out.log" 2>/dev/null || true)"
  rm -rf "$td"; report "$1" "$got" "$2"
}

# run_raw: like run(), but takes a fully-formed JSON payload on stdin and
# an optional extra env assignment (NAME=value), for cases (Edit,
# MultiEdit, Bash, kill-switch) that don't fit the Write-only run() shape.
run_raw() { # want name file payload_json [extra_env...]
  _rr_want="$1"; _rr_name="$2"; _rr_file="$3"; _rr_payload="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$_rr_file")"
  shift 4
  printf '%s' "$_rr_payload" \
    | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" "$@" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  LAST_LOG="$(cat "$td/out.log" 2>/dev/null || true)"
  rm -rf "$td"; report "$_rr_want" "$got" "$_rr_name"
}

ALL_FOUR='current-state-survey referenced.
scout-brief referenced.
Adopt: keep the survey step.
Skip: skip the extra tooling.
This ties back to issue-1 decision boundary.'

MISSING_I='scout-brief referenced.
Adopt: keep the survey step.
Skip: skip the extra tooling.
This ties back to issue-1 decision boundary.'

MISSING_II='current-state-survey referenced.
Adopt: keep the survey step.
Skip: skip the extra tooling.
This ties back to issue-1 decision boundary.'

MISSING_III='current-state-survey referenced.
scout-brief referenced.
This ties back to issue-1 decision boundary.'

MISSING_IV='current-state-survey referenced.
scout-brief referenced.
Adopt: keep the survey step.
Skip: skip the extra tooling.'

run deny  missing-survey-i     "$TARGET" "$MISSING_I"
run deny  missing-scout-ii     "$TARGET" "$MISSING_II"
run deny  missing-adopt-iii    "$TARGET" "$MISSING_III"
run deny  missing-rationale-iv "$TARGET" "$MISSING_IV"
run allow all-four-present     "$TARGET" "$ALL_FOUR"
run allow outside-write-surface "docs/issue-7/reports/incident-response.md" "no elements here"
mark_group baseline

# malformed JSON on stdin — extend beyond the single truncated case that
# existed before migration: truncated, non-object top-level, and empty.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf 'not json' | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" malformed-json-truncated

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '["not", "an", "object"]' | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" malformed-json-non-object

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '' | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" malformed-json-empty
mark_group malformed-json

# --- Group 1: Edit with replace_all:true against a multiply-occurring
# old_string on this gate's write surface -> reconstructed text judged
# correctly (both occurrences replaced, so both required tags land).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/proposals"
cat >"$td/docs/issue-7/proposals/incident-response.md" <<'EOF'
current-state-survey referenced.
scout-brief referenced.
PLACEHOLDER
This ties back to issue-1 decision boundary. PLACEHOLDER
EOF
payload_json="$(python3 -c '
import json
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {
        "file_path": "docs/issue-7/proposals/incident-response.md",
        "old_string": "PLACEHOLDER",
        "new_string": "Adopt: keep the survey step.\nSkip: skip the extra tooling.",
        "replace_all": True,
    },
}))
')"
printf '%s' "$payload_json" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
LAST_LOG="$(cat "$td/out.log" 2>/dev/null || true)"
rm -rf "$td"; report allow "$got" edit-replace-all-true
mark_group edit-replace-all

# --- Group 2: MultiEdit with mixed replace_all true/false edits in one call.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/proposals"
cat >"$td/docs/issue-7/proposals/incident-response.md" <<'EOF'
current-state-survey referenced.
SCOUT_PLACEHOLDER
LIST_PLACEHOLDER LIST_PLACEHOLDER
This ties back to issue-1 decision boundary. LIST_PLACEHOLDER
EOF
payload_json="$(python3 -c '
import json
print(json.dumps({
    "tool_name": "MultiEdit",
    "tool_input": {
        "file_path": "docs/issue-7/proposals/incident-response.md",
        "edits": [
            {"old_string": "SCOUT_PLACEHOLDER", "new_string": "scout-brief referenced.", "replace_all": False},
            {"old_string": "LIST_PLACEHOLDER", "new_string": "Adopt: keep it.\nSkip: skip it.", "replace_all": True},
        ],
    },
}))
')"
printf '%s' "$payload_json" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
LAST_LOG="$(cat "$td/out.log" 2>/dev/null || true)"
rm -rf "$td"; report allow "$got" multiedit-mixed-replace-all
mark_group multiedit-mixed

# --- Group 4: kill-switch set to an unrecognized garbage value -> gate
# must stay ACTIVE (deny the bad-shape fixture), not disabled.
run_raw deny kill-switch-garbage-value "$TARGET" "$(python3 -c '
import json
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": "docs/issue-7/proposals/incident-response.md", "content": "no required elements here"},
}))
')" INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF=banana
mark_group kill-switch-garbage

# also: a genuinely-recognized on-spelling really does disable the gate,
# so the garbage-value case above is a meaningful regression test and not
# an accidental always-deny.
run_raw allow kill-switch-recognized-on "$TARGET" "$(python3 -c '
import json
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": "docs/issue-7/proposals/incident-response.md", "content": "no required elements here"},
}))
')" INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF=true

# --- Group 5: absolute file_path matching the same scope a relative
# fixture already matches, plus a "./"-prefixed relative variant.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
payload_json="$(python3 -c '
import json, sys
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": sys.argv[1] + "/docs/issue-7/proposals/incident-response.md", "content": "no required elements here"},
}))
' "$td")"
printf '%s' "$payload_json" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" absolute-file-path

run deny  dot-slash-relative-path "./$TARGET" "no required elements here"
mark_group absolute-and-dot-relative

# --- Group 6: a Bash-tool tool_input.command containing a file write to
# the same target a Write call would hit -> equivalent deny/allow to the
# Write-tool case (path-scope detection; the gate denies conservatively
# since it cannot inspect the resulting content of a Bash write).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
payload_json="$(python3 -c '
import json
print(json.dumps({
    "tool_name": "Bash",
    "tool_input": {"command": "printf \"x\" >> docs/issue-7/proposals/incident-response.md"},
}))
')"
printf '%s' "$payload_json" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" bash-write-same-target

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
payload_json="$(python3 -c '
import json
print(json.dumps({
    "tool_name": "Bash",
    "tool_input": {"command": "printf \"x\" >> docs/issue-7/reports/incident-response.md"},
}))
')"
printf '%s' "$payload_json" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report allow "$got" bash-write-outside-surface
mark_group bash-write-detection

# --- Group 7: semantic regression case — a document where "adopt" and
# "skip" (or "scout" mentioned without an actual skip statement) appear in
# UNRELATED sections/paragraphs must NOT pass (section-scoping fix).
UNRELATED_ADOPT_SKIP='current-state-survey referenced.
scout-brief referenced.

## Adopt

We adopt the survey-first workflow going forward.

## Unrelated Notes

Nothing here is a skip record; this paragraph just happens to mention we
did not skip the retro meeting last quarter, which is unrelated to any
adopt/skip list.

This ties back to issue-1 decision boundary.'
run deny cross-section-adopt-skip-not-scoped "$TARGET" "$UNRELATED_ADOPT_SKIP"

NEGATED_SCOUT='current-state-survey referenced.

## Scout

We did NOT skip the scout step; scouting was fully performed and is not
skipped in any sense.

Adopt: keep the survey step. Skip: skip the extra tooling.
This ties back to issue-1 decision boundary.'
run deny negated-scout-skip-not-treated-as-skip "$TARGET" "$NEGATED_SCOUT"

# "never skipped scouting" is itself a negation of skip — must not satisfy
# scout_skip_stated, and with no real scout-brief reference/scout section
# this must still be denied for missing element (ii).
NEVER_SKIPPED_SCOUTING='current-state-survey referenced.

We never skipped scouting for this change.

Adopt: keep the survey step. Skip: skip the extra tooling.
This ties back to issue-1 decision boundary.'
run deny never-skipped-scouting-not-treated-as-skip "$TARGET" "$NEVER_SKIPPED_SCOUTING"
mark_group semantic-scoping-regression

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"

# Self-check: every required group must have run.
REQUIRED_GROUPS=(baseline malformed-json edit-replace-all multiedit-mixed kill-switch-garbage absolute-and-dot-relative bash-write-detection semantic-scoping-regression)
missing_groups=0
for g in "${REQUIRED_GROUPS[@]}"; do
  if [ -z "${GROUP_HIT[$g]:-}" ]; then
    echo "SELF-CHECK FAIL: required group not exercised: $g" >&2
    missing_groups=$((missing_groups+1))
  fi
done
if [ "$missing_groups" -ne 0 ]; then
  echo "SELF-CHECK FAIL: $missing_groups required group(s) missing" >&2
  fail=$((fail+missing_groups))
else
  echo "SELF-CHECK ok: all ${#REQUIRED_GROUPS[@]} required groups exercised"
fi

[ "$fail" -eq 0 ]
