#!/usr/bin/env bash
# order-gate.sh, exercised as a real subprocess against synthetic
# PreToolUse JSON on stdin.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"

# Production/CI supplies the real core checkout path via CLAUDE_PLUGIN_ROOT_CORE (the
# gate script sources gate-lib.sh from it); this is the sandbox fallback so
# the test suite is runnable standalone.
CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-/tmp/claude-1000/core-ref}"
export CLAUDE_PLUGIN_ROOT_CORE

pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# Required mandatory-group self-check (issue #10 requirement 3): incremented
# once per required group below, asserted at the end so "all green" cannot
# silently mean "some groups skipped."
declare -A GROUPS_HIT=()
mark_group() { GROUPS_HIT["$1"]=1; }
REQUIRED_GROUPS="edit-replace-all multiedit-mixed malformed-json kill-switch-garbage abs-and-dot-relative bash-write-target semantic-negation-regression"

run() { # want name path content [make_survey make_scout]
  want="$1"; name="$2"; path="$3"; content="$4"; make_survey="${5:-0}"; make_scout="${6:-0}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/docs/issue-7/reports/incident-response" "$td/docs/issue-7/proposals"
  if [ "$make_survey" = 1 ]; then echo "survey" > "$td/docs/issue-7/reports/incident-response/current-state-survey.md"; fi
  if [ "$make_scout" = 1 ]; then echo "scout" > "$td/docs/issue-7/reports/incident-response/scout-brief.md"; fi
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# run_payload: like run() but takes an already-built JSON payload string,
# for cases that need a shape run() can't build (Edit/MultiEdit/Bash/env
# overrides). Sets up the same survey/scout-brief fixture scaffolding.
run_payload() { # want name payload_json [make_survey make_scout] [extra_env...]
  want="$1"; name="$2"; payload="$3"; make_survey="${4:-0}"; make_scout="${5:-0}"; shift 5 || shift $#
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/docs/issue-7/reports/incident-response" "$td/docs/issue-7/proposals"
  if [ "$make_survey" = 1 ]; then echo "survey" > "$td/docs/issue-7/reports/incident-response/current-state-survey.md"; fi
  if [ "$make_scout" = 1 ]; then echo "scout" > "$td/docs/issue-7/reports/incident-response/scout-brief.md"; fi
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" "$@" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# run_payload_in_dir: like run_payload but the caller has already created
# the temp dir/fixtures and just wants the payload run against it (used for
# the semantic-negation regression case, which needs custom survey content).
run_payload_in_dir() { # want name td payload_json
  want="$1"; name="$2"; td="$3"; payload="$4"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report "$want" "$got" "$name"
}

# ---- baseline coverage (pre-existing) ----
run deny  no-survey-no-scout "docs/issue-7/proposals/incident-response.md" "proposal" 0 0
run allow both-present       "docs/issue-7/proposals/incident-response.md" "proposal" 1 1
run allow outside-surface    "docs/issue-7/reports/incident-response.md" "report" 0 0

# ---- group: malformed JSON (truncated / non-object top-level / empty) ----
for shape in truncated non-object empty; do
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  case "$shape" in
    truncated) body='{not valid json' ;;
    non-object) body='"just a string"' ;;
    empty) body='' ;;
  esac
  printf '%s' "$body" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" "malformed-json-$shape"
done
mark_group malformed-json

# ---- group: Edit with replace_all:true targeting the write surface ----
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
echo "old old old" > "$td/docs/issue-7/proposals/incident-response.md"
payload='{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-7/proposals/incident-response.md","old_string":"old","new_string":"new","replace_all":true}}'
run_payload_in_dir deny edit-replace-all-no-survey "$td" "$payload"
rm -rf "$td"
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals" "$td/docs/issue-7/reports/incident-response"
echo "old old old" > "$td/docs/issue-7/proposals/incident-response.md"
echo "survey" > "$td/docs/issue-7/reports/incident-response/current-state-survey.md"
echo "scout" > "$td/docs/issue-7/reports/incident-response/scout-brief.md"
run_payload_in_dir allow edit-replace-all-both-present "$td" "$payload"
rm -rf "$td"
mark_group edit-replace-all

# ---- group: MultiEdit with mixed replace_all true/false ----
payload='{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-7/proposals/incident-response.md","edits":[{"old_string":"a","new_string":"b","replace_all":true},{"old_string":"x","new_string":"y","replace_all":false}]}}'
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
echo "a a x x" > "$td/docs/issue-7/proposals/incident-response.md"
run_payload_in_dir deny multiedit-mixed-no-survey "$td" "$payload"
rm -rf "$td"
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals" "$td/docs/issue-7/reports/incident-response"
echo "a a x x" > "$td/docs/issue-7/proposals/incident-response.md"
echo "survey" > "$td/docs/issue-7/reports/incident-response/current-state-survey.md"
echo "scout" > "$td/docs/issue-7/reports/incident-response/scout-brief.md"
run_payload_in_dir allow multiedit-mixed-both-present "$td" "$payload"
rm -rf "$td"
mark_group multiedit-mixed

# ---- group: kill-switch set to an unrecognized garbage value -> stays ACTIVE ----
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
printf '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/proposals/incident-response.md","content":"x"}}' \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF=banana /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" kill-switch-garbage-stays-active
mark_group kill-switch-garbage

# sanity: a recognized on-spelling still disables the gate
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
printf '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/proposals/incident-response.md","content":"x"}}' \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF=1 /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report allow "$got" kill-switch-recognized-on-disables

# ---- group: absolute file_path + ./-prefixed relative variant ----
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
abs_path="$td/docs/issue-7/proposals/incident-response.md"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$abs_path" \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" absolute-path-matches-scope

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
printf '{"tool_name":"Write","tool_input":{"file_path":"./docs/issue-7/proposals/incident-response.md","content":"x"}}' \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" dot-relative-path-matches-scope
mark_group abs-and-dot-relative

# ---- group: Bash-tool command reaching the same target a Write would hit ----
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
printf '{"tool_name":"Bash","tool_input":{"command":"echo hi > docs/issue-7/proposals/incident-response.md"}}' \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" bash-write-target-no-survey

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals" "$td/docs/issue-7/reports/incident-response"
echo "survey" > "$td/docs/issue-7/reports/incident-response/current-state-survey.md"
echo "scout" > "$td/docs/issue-7/reports/incident-response/scout-brief.md"
printf '{"tool_name":"Bash","tool_input":{"command":"echo hi > docs/issue-7/proposals/incident-response.md"}}' \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report allow "$got" bash-write-target-both-present

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals"
printf '{"tool_name":"Bash","tool_input":{"command":"cat notes.txt"}}' \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$CLAUDE_PLUGIN_ROOT_CORE" /bin/bash "$HOOKS/order-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report allow "$got" bash-command-no-matching-target
mark_group bash-write-target

# ---- group: semantic regression — negated "skip" must NOT count as a skip record ----
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals" "$td/docs/issue-7/reports/incident-response"
cat > "$td/docs/issue-7/reports/incident-response/current-state-survey.md" <<'EOF'
# Current-state survey

We considered the scout step carefully. To be clear: we did NOT skip the
scout step; the scout-brief simply has not been written yet.
EOF
# scout-brief.md intentionally absent
payload='{"tool_name":"Write","tool_input":{"file_path":"docs/issue-7/proposals/incident-response.md","content":"proposal"}}'
run_payload_in_dir deny semantic-negation-not-treated-as-skip "$td" "$payload"
rm -rf "$td"

# positive control: a genuine non-negated skip record (bounded window) is honored
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals" "$td/docs/issue-7/reports/incident-response"
cat > "$td/docs/issue-7/reports/incident-response/current-state-survey.md" <<'EOF'
# Current-state survey

We decided to skip the scout step for this small change.
EOF
run_payload_in_dir allow semantic-genuine-skip-still-honored "$td" "$payload"
rm -rf "$td"

# positive control: heading-scoped skip record
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/proposals" "$td/docs/issue-7/reports/incident-response"
cat > "$td/docs/issue-7/reports/incident-response/current-state-survey.md" <<'EOF'
# Current-state survey

## Scout

Skipped for this change; nothing further to investigate.
EOF
run_payload_in_dir allow semantic-heading-scoped-skip-honored "$td" "$payload"
rm -rf "$td"
mark_group semantic-negation-regression

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"

# Self-check: every mandatory group must have been exercised.
missing_groups=""
for g in $REQUIRED_GROUPS; do
  [ -n "${GROUPS_HIT[$g]:-}" ] || missing_groups="$missing_groups $g"
done
if [ -n "$missing_groups" ]; then
  echo "SELF-CHECK FAIL: mandatory group(s) not exercised:$missing_groups" >&2
  fail=$((fail+1))
fi
got_count=${#GROUPS_HIT[@]}
want_count=$(printf '%s\n' $REQUIRED_GROUPS | wc -l)
if [ "$got_count" -ne "$want_count" ]; then
  echo "SELF-CHECK FAIL: expected $want_count mandatory groups, hit $got_count" >&2
  fail=$((fail+1))
fi

[ "$fail" -eq 0 ]
