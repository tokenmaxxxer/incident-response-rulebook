#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — incident-response phase-2 record,
# ADDITIVE to (never a replacement for) core's generic field-presence gate.
#
# Target: docs/issue-<n>/reports/incident-response.md — this role's phase-2
# write surface.
#
# Requires, beyond generic field presence:
#   1. An RCA-method name is present (5 Whys / causal chain / fishbone /
#      fault tree), case-insensitive substring match.
#   2. A primary-vs-contributing-factor textual distinction is present
#      ("primary" together with "contributing" or "secondary"), a
#      lightweight lexical check, not semantic.
#
# Per docs/issue-1/proposals/incident-response.md (b)1-3.
#
# Explicitly NOT gated here: blamelessness/tone language — per issue-1 (c),
# that is documented guidance, not machine-checkable, and intentionally out
# of scope for this gate.
#
# Kill switch: export INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-incident-response}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "rca-method-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "rca-method-gate: empty tool-use payload on stdin; cannot evaluate the RCA-method gate."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (RCA-method check cannot run)."

RG_PAYLOAD="$payload" RG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("RG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge RCA-method fields on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on RCA-method.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (RCA-method).")

    root = posixpath.normpath(os.environ["RG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/incident-response\.md$')

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
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not this gate's write surface — not this gate's business

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on RCA-method." % rel)

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
            "Edit/MultiEdit whose old_string matches, so the RCA-method fields can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    missing = []

    # 1. RCA-method name present.
    method_named = has_any(
        "5 whys", "five whys", "causal chain", "causal-chain",
        "causal timeline", "fishbone", "fault tree", "fault-tree",
    )
    if not method_named:
        missing.append("rca-method-named")

    # 2. Primary-vs-contributing-factor distinction present.
    distinction_present = has_any("primary") and has_any("contributing", "secondary")
    if not distinction_present:
        missing.append("primary-contributing-distinction")

    if missing:
        deny(
            "incident-response phase-2 record is missing required element(s): %s. Per "
            "docs/issue-1/proposals/incident-response.md (b)1-3, every phase-2 "
            "incident-response report must name an RCA method (5 Whys / causal chain / "
            "fishbone / fault tree) and textually distinguish the primary cause from "
            "contributing (or secondary) factors." % ", ".join(missing)
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("rca-method-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "incident-response: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
