#!/usr/bin/env bash
# Real-subprocess tests for hooks/action-item-gate.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-30s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-30s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/incident-response.md

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
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

# Malformed JSON on stdin -> deny.
malformed() {
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf 'not json at all' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/action-item-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" malformed-json-stdin
}
malformed

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
