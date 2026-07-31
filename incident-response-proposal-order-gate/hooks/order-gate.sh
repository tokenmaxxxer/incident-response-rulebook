#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — enforces the phase-1 survey→scout→
# propose ORDER constraint from docs/issue-7/proposals/incident-response.md §2
# (issue-1 (a)(1)): a docs/issue-<n>/proposals/incident-response*.md write may
# not create/finalize that file until docs/issue-<n>/reports/incident-response/
# current-state-survey.md and scout-brief.md already exist on disk for the
# same issue number, or a scout-directive-compliant skip record is present in
# the survey file. This is a file-existence check, not a state-machine parse.
#
# Kill switch: export INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF=1
set -uo pipefail

deny() { echo "incident-response: refused — $1" >&2; exit 2; }

case "${INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

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

OG_PAYLOAD="$payload" OG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("OG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge the phase-1 order on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on the phase-1 order gate.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (phase-1 order).")

    root = posixpath.normpath(os.environ["OG_ROOT"].replace("\\", "/"))
    SURFACE_RE = re.compile(r'^docs/issue-([0-9]+)/proposals/incident-response.*\.md$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    m = SURFACE_RE.match(rel)
    if not m:
        sys.exit(0)  # not this gate's write surface

    n = m.group(1)
    survey_rel = "docs/issue-%s/reports/incident-response/current-state-survey.md" % n
    scout_rel = "docs/issue-%s/reports/incident-response/scout-brief.md" % n
    survey_abs = posixpath.join(root, survey_rel)
    scout_abs = posixpath.join(root, scout_rel)

    survey_exists = os.path.isfile(survey_abs)
    scout_exists = os.path.isfile(scout_abs)

    if survey_exists and scout_exists:
        sys.exit(0)

    # Lightweight skip-record heuristic: literal words "skip" and "scout"
    # together somewhere in the survey file.
    skip_recorded = False
    if survey_exists:
        try:
            with open(survey_abs, encoding="utf-8-sig") as fh:
                content = fh.read(1 << 20).lower()
            skip_recorded = ("skip" in content) and ("scout" in content)
        except OSError:
            pass

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
        "an explicit scout-skip (mentioning both \"skip\" and \"scout\") in "
        "%s, before writing the proposal."
        % (rel, ", ".join(missing), survey_rel)
    )
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("order-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "incident-response: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
