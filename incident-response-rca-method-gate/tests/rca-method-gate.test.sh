#!/usr/bin/env bash
# rca-method-gate.sh, exercised as a real subprocess against synthetic
# PreToolUse JSON on stdin.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/incident-response.md
run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
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

# malformed JSON on stdin -> deny
malformed() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  printf 'not json at all' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/rca-method-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" malformed-json
}
malformed

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
