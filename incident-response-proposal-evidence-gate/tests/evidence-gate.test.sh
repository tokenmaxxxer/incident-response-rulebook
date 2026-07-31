#!/usr/bin/env bash
# Exercises evidence-gate.sh as a real subprocess against synthetic
# PreToolUse JSON.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-28s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-28s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

TARGET=docs/issue-7/proposals/incident-response.md

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/evidence-gate.sh" >"$td/out.log" 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  LAST_LOG="$(cat "$td/out.log" 2>/dev/null || true)"
  rm -rf "$td"; report "$1" "$got" "$2"
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

# malformed JSON on stdin
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf 'not json' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/evidence-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" malformed-json

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
