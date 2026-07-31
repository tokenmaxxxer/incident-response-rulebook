#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — incident-response phase-1
# proposal CONTENT-shape constraint, per docs/issue-7/proposals/
# incident-response.md §3 (approved) and docs/issue-1/proposals/
# methodology-norms.md (a)(2)-(3).
#
# Write surface: docs/issue-<n>/proposals/incident-response*.md
#
# Requires four elements be present in the resulting full text:
#   (i)   a reference to the current-state survey
#   (ii)  a reference to the scout brief, or an explicit stated skip
#   (iii) an explicit adopt/skip list
#   (iv)  rationale tying an adopted item back to this role's own
#         decision boundary (issue-1 / 장애 후 무엇을 배웠고 재발을
#         무엇으로 막을 것인가)
#
# Kill switch: export INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-incident-response}"
deny() { echo "incident-response: refused — $1" >&2; exit 2; }

case "${INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "evidence-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "evidence-gate: empty tool-use payload on stdin; cannot evaluate the evidence gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("file_path")
    if isinstance(v,str) and v: print(v)
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
[ -z "$root" ] && deny "no project root could be determined; failing closed (evidence check cannot run)."

EG_PAYLOAD="$payload" EG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("EG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge proposal content on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on the evidence gate.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (evidence gate).")

    root = posixpath.normpath(os.environ["EG_ROOT"].replace("\\", "/"))
    SURFACE_RE = re.compile(r'^docs/issue-[0-9]+/proposals/incident-response.*\.md$', re.I)

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    if tool not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    path = ti.get("file_path")
    if not (isinstance(path, str) and path):
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    if not SURFACE_RE.match(rel):
        sys.exit(0)  # not this gate's own write surface

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on the evidence gate." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text

    if new_text is None:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the evidence-shape elements can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    missing = []

    # (i) current-state survey reference
    if not has_any("current-state-survey", "current-state survey", "current state survey"):
        missing.append(
            "(i) no reference to the current-state survey (per docs/issue-1/proposals/"
            "methodology-norms.md (a)(2))"
        )

    # (ii) scout brief reference, or an explicit stated skip
    scout_referenced = has_any("scout-brief", "scout brief")
    scout_skip_stated = has_any("scout skip", "skipped scouting") or (
        has_any("bugfix") and has_any("no design decision")
    )
    if not (scout_referenced or scout_skip_stated):
        missing.append(
            "(ii) no reference to the scout brief and no explicit stated scout-directive "
            "skip reason (per docs/issue-1/proposals/methodology-norms.md (a)(2))"
        )

    # (iii) explicit adopt/skip list
    if not (has_any("adopt") and has_any("skip")):
        missing.append(
            "(iii) no explicit adopt/skip list (per docs/issue-1/proposals/"
            "methodology-norms.md (a)(3))"
        )

    # (iv) rationale tying an adopted item back to this role's own decision boundary
    if not has_any("issue-1", "decision boundary", "장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가"):
        missing.append(
            "(iv) no rationale tying an adopted item back to this role's own decision "
            "boundary (per docs/issue-1/proposals/methodology-norms.md (a)(3))"
        )

    if missing:
        deny(
            "proposal write to %s is missing required element(s): %s" % (rel, "; ".join(missing))
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("evidence-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "incident-response: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
