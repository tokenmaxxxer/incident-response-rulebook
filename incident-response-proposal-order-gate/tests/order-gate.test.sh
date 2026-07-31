#!/usr/bin/env bash
# order-gate.sh, exercised as a real subprocess against synthetic
# PreToolUse JSON on stdin.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name path content [make_survey make_scout]
  want="$1"; name="$2"; path="$3"; content="$4"; make_survey="${5:-0}"; make_scout="${6:-0}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/docs/issue-7/reports/incident-response" "$td/docs/issue-7/proposals"
  if [ "$make_survey" = 1 ]; then echo "survey" > "$td/docs/issue-7/reports/incident-response/current-state-survey.md"; fi
  if [ "$make_scout" = 1 ]; then echo "scout" > "$td/docs/issue-7/reports/incident-response/scout-brief.md"; fi
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

run deny  no-survey-no-scout "docs/issue-7/proposals/incident-response.md" "proposal" 0 0
run allow both-present       "docs/issue-7/proposals/incident-response.md" "proposal" 1 1
run allow outside-surface    "docs/issue-7/reports/incident-response.md" "report" 0 0

# malformed JSON on stdin
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '{not valid json' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" malformed-json

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
