#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit|Bash) — enforces the phase-1 survey→scout→
# propose ORDER constraint from docs/issue-7/proposals/incident-response.md §2
# (issue-1 (a)(1)): a docs/issue-<n>/proposals/incident-response*.md write may
# not create/finalize that file until docs/issue-<n>/reports/incident-response/
# current-state-survey.md and scout-brief.md already exist on disk for the
# same issue number, or a scout-directive-compliant skip record is present in
# the survey file. This is a file-existence check, not a state-machine parse.
#
# Issue #10 phase 2: migrated to source core's gate-lib.sh (fail-closed trap,
# kill-switch polarity, path normalization) instead of hand-rolling them, and
# added Bash-tool write-target coverage via gate_bash_write_targets so a
# Bash-tool file write reaching this gate's write surface is no longer
# invisible. This gate does not use gate_reconstruct_write — it is a
# file-existence/skip-record check and never reconstructs the resulting
# write content.
#
# Kill switch: export INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}/hooks/lib/gate-lib.sh" || { echo "order-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

deny() { echo "incident-response: refused — $1" >&2; exit 2; }

gate_kill_switch_active "${INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "order-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "order-gate: empty tool-use payload on stdin; cannot evaluate the phase-1 order gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    for k in ("file_path","notebook_path"):
        v=ti.get(k)
        if isinstance(v,str) and v: print(v); break
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  python3 -c '
import os,posixpath,sys
r,t=sys.argv[1],sys.argv[2]
try: rr=posixpath.normpath(os.path.realpath(r).replace("\\","/"))
except Exception: sys.exit(1)
n=t.replace("\\","/"); a=n if posixpath.isabs(n) else posixpath.join(rr,n)
a=posixpath.normpath(a); real=posixpath.normpath(os.path.realpath(a).replace("\\","/"))
sys.exit(0 if (real==rr or real.startswith(rr+"/")) else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (phase-1 order check cannot run)."

_tool_name="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
if isinstance(e,dict):
    v=e.get("tool_name")
    if isinstance(v,str): print(v)
' 2>/dev/null || true)"

_judge() { # $1 = OG_FORCE_PATH (empty = derive from tool_input as before)
  OG_PAYLOAD="$payload" OG_ROOT="$root" OG_FORCE_PATH="${1:-}" \
  python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, re, sys, importlib.util

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("OG_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (phase-1 order).")

    root = os.environ["OG_ROOT"]
    SURFACE_RE = re.compile(r'^docs/issue-([0-9]+)/proposals/incident-response.*\.md$')

    force_path = os.environ.get("OG_FORCE_PATH", "")
    path = None
    if force_path:
        # Bash-tool candidate token, standing in for file_path (issue #10
        # requirement: gate_bash_write_targets coverage). Only path-scope
        # matching against SURFACE_RE is needed here; this gate never
        # reconstructs write content for any tool.
        path = force_path
    elif tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)  # outside root
    m = SURFACE_RE.match(rel)
    if not m:
        sys.exit(0)  # not this gate's write surface

    n = m.group(1)
    survey_rel = "docs/issue-%s/reports/incident-response/current-state-survey.md" % n
    scout_rel = "docs/issue-%s/reports/incident-response/scout-brief.md" % n
    survey_abs = os.path.join(root, survey_rel)
    scout_abs = os.path.join(root, scout_rel)

    survey_exists = os.path.isfile(survey_abs)
    scout_exists = os.path.isfile(scout_abs)

    if survey_exists and scout_exists:
        sys.exit(0)

    # Section-scoped / bounded-token-window skip-record heuristic (issue
    # #10 requirement 2). The old check — bare ("skip" in content) and
    # ("scout" in content) over the whole file — tripped on negated
    # phrasing like "we did NOT skip the scout step". Now requires either:
    #   (a) an explicit skip marker inside a heading-delimited "scout"
    #       section (same heading/section-lines extraction shape
    #       action-item-gate.sh uses for its own "action items" section), or
    #   (b) "skip" and "scout" within a ~15-token window of each other,
    #       with no negation token (not/didn't/never/n't-suffixed) present
    #       in that window.
    skip_recorded = False
    if survey_exists:
        try:
            with open(survey_abs, encoding="utf-8-sig") as fh:
                content = fh.read(1 << 20)
        except OSError:
            content = ""
        if content:
            NEGATION_TOKENS = {"not", "never"}

            lines = content.splitlines()
            heading_re = re.compile(r'^(#{1,6})\s*.*scout\b', re.I)
            section_lines = []
            in_section = False
            section_level = None
            for ln in lines:
                hm = re.match(r'^(#{1,6})\s+(.*)$', ln)
                if hm:
                    level = len(hm.group(1))
                    if heading_re.match(ln):
                        in_section = True
                        section_level = level
                        continue
                    if in_section and level <= (section_level or 1):
                        in_section = False
                        continue
                if in_section:
                    section_lines.append(ln)
                elif re.match(r'^\s*scout(\s*brief)?\s*:?\s*$', ln, re.I):
                    in_section = True
                    section_level = 99

            skip_marker_re = re.compile(r'\bskip(?:ped|ping)?\b', re.I)
            if any(skip_marker_re.search(ln) for ln in section_lines):
                skip_recorded = True

            if not skip_recorded:
                tokens = re.findall(r"[A-Za-z']+", content.lower())
                skip_idxs = [i for i, t in enumerate(tokens) if t in ("skip", "skipped", "skipping")]
                scout_idxs = [i for i, t in enumerate(tokens) if t == "scout"]
                for si in skip_idxs:
                    if skip_recorded:
                        break
                    for ci in scout_idxs:
                        if abs(si - ci) > 15:
                            continue
                        lo, hi = min(si, ci), max(si, ci)
                        window = tokens[max(0, lo - 15):hi + 1]
                        if not any(t in NEGATION_TOKENS or t.endswith("n't") for t in window):
                            skip_recorded = True
                            break

    if skip_recorded:
        sys.exit(0)

    missing = []
    if not survey_exists:
        missing.append(survey_rel)
    if not scout_exists:
        missing.append(scout_rel)

    deny(
        "write to %s requires phase-1 order (survey then scout-brief) to be "
        "on disk first, per docs/issue-7/proposals/incident-response.md §2 "
        "(issue-1 (a)(1)). Missing: %s. Create the missing file(s), or record "
        "an explicit, non-negated scout-skip (\"skip\"/\"scout\" near each "
        "other, or under a scout-heading section) in %s, before writing the "
        "proposal."
        % (rel, ", ".join(missing), survey_rel)
    )
except SystemExit:
    raise
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("order-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
}

if [ "$_tool_name" = "Bash" ]; then
  _command="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("command")
    if isinstance(v,str): print(v)
' 2>/dev/null || true)"
  _rc=0
  if [ -n "$_command" ]; then
    while IFS= read -r _cand; do
      [ -n "$_cand" ] || continue
      _judge "$_cand"
      _rc=$?
      [ "$_rc" -eq 0 ] || break
    done <<CANDS
$(gate_bash_write_targets "$_command")
CANDS
  fi
else
  _judge ""
  _rc=$?
fi

exit "$_rc"
