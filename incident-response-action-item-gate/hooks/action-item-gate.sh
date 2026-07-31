#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — phase-2 action-item shape check,
# ADDITIVE on top of (never instead of) the core canon's generic
# field-presence gate and the sibling rca-method-gate.sh, both of which
# register separately on the same write surface.
#
# Targets: docs/issue-<n>/reports/incident-response.md — the phase-2
# incident-response record, per docs/issue-1/proposals/incident-response.md
# (b)1-3.
#
# Requires at least one action-item bullet under an "action item(s)"
# heading to carry BOTH an owner-looking token (capitalized name or
# @handle) AND a deadline-looking token (ISO date or relative-date
# phrase). This is a SHAPE check, not a truth check: a regex cannot
# verify verb+outcome semantic quality, so presence of owner+deadline on
# an action-item line is treated as satisfying the four-slot shape.
#
# Kill switch: export INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-incident-response}"
deny() { echo "incident-response: refused — $1" >&2; exit 2; }

case "${INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "action-item-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "action-item-gate: empty tool-use payload on stdin; cannot evaluate the action-item shape gate."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (action-item shape check cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge the action-item shape on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on the action-item shape check.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (action-item shape).")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
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
        sys.exit(0)  # not this gate's write surface

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on the action-item shape check." % rel)

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
            "Edit/MultiEdit whose old_string matches, so the action-item shape can be "
            "checked." % (rel, tool)
        )

    # Locate an "action item(s)" section (case-insensitive heading match)
    # and pull its bulleted/lined content up to the next heading of equal
    # or higher level, or end of document.
    lines = new_text.splitlines()
    heading_re = re.compile(r'^(#{1,6})\s*.*action\s*items?\b', re.I)
    section_lines = []
    in_section = False
    section_level = None
    for ln in lines:
        m = re.match(r'^(#{1,6})\s+(.*)$', ln)
        if m:
            level = len(m.group(1))
            if heading_re.match(ln):
                in_section = True
                section_level = level
                continue
            if in_section and level <= (section_level or 1):
                in_section = False
                continue
        if in_section:
            section_lines.append(ln)
        elif re.match(r'^\s*action\s*items?\s*:?\s*$', ln, re.I):
            # bare non-markdown "Action Items" label line
            in_section = True
            section_level = 99

    if not section_lines:
        # Fall back: also allow inline "action item:" bullets anywhere,
        # so a document without a dedicated heading isn't automatically
        # denied for structural reasons this gate doesn't police.
        section_lines = [ln for ln in lines if re.search(r'action\s*items?', ln, re.I)]

    OWNER_RE = re.compile(r'@[A-Za-z0-9_.\-]+|\b[A-Z][a-z]+(?:\s[A-Z][a-z]+)?\b')
    DEADLINE_RE = re.compile(
        r'\d{4}-\d{2}-\d{2}'
        r'|\bby\s+(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|next\s+\w+|end\s+of\s+(?:day|week|month)|[A-Z][a-z]+\s+\d{1,2}(?:st|nd|rd|th)?|\d{4}-\d{2}-\d{2})'
        r'|\bwithin\s+\d+\s*(?:day|days|hour|hours|week|weeks)\b'
        r'|\bdue\s+(?:by\s+)?\S+',
        re.I,
    )

    shape_ok = False
    for ln in section_lines:
        if not re.search(r'action\s*items?', ln, re.I) and section_level != None and False:
            pass
        if OWNER_RE.search(ln) and DEADLINE_RE.search(ln):
            shape_ok = True
            break

    if not shape_ok:
        deny(
            "per docs/issue-1/proposals/incident-response.md (b)1-3, action items need "
            "owner+verb+outcome+deadline: no action item in %s carries both an "
            "owner-looking token (a capitalized name/handle) and a deadline-looking token "
            "(an ISO date or a relative-date phrase like 'by Friday'/'within 3 days'). "
            "This is a shape check, not a truth check." % rel
        )

except SystemExit:
    raise
except Exception as _e:
    sys.stderr.write("incident-response: refused — internal error in action-item-gate (%s); failing closed.\n" % _e)
    sys.exit(2)
PY
