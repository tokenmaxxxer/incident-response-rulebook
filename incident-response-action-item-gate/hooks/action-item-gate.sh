#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit|Bash) — phase-2 action-item shape check,
# ADDITIVE on top of (never instead of) the core canon's generic
# field-presence gate and the sibling rca-method-gate.sh, both of which
# register separately on the same write surface.
#
# Targets: docs/issue-<n>/reports/incident-response.md — the phase-2
# incident-response record, per docs/issue-1/proposals/incident-response.md
# (b)1-3.
#
# Requires at least one action-item bullet under an "action item(s)"
# heading to carry BOTH an owner-looking token (an @handle, or a
# capitalized-word-sequence immediately preceding a colon/dash at the
# start of the line) AND a deadline-looking token (ISO date or relative-
# date phrase). This is a SHAPE check, not a truth check: a regex cannot
# verify verb+outcome semantic quality, so presence of owner+deadline on
# an action-item line is treated as satisfying the four-slot shape.
#
# Migrated to core's gate-house standard (issue #10 phase 2): trap,
# kill-switch, JSON parse, path normalization, Edit/MultiEdit
# reconstruction, and Bash-write-target scanning are all sourced from
# gate-lib.sh/gate-lib.py via CLAUDE_PLUGIN_ROOT_CORE, never hand-rolled here.
#
# Kill switch: export INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}/hooks/lib/gate-lib.sh" || { echo "action-item-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

role="${CLAUDE_ROLE:-incident-response}"
deny() { echo "incident-response: refused — $1" >&2; exit 2; }

gate_kill_switch_active "${INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "action-item-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "action-item-gate: empty tool-use payload on stdin; cannot evaluate the action-item shape gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
if not isinstance(e,dict): sys.exit(0)
tool=e.get("tool_name")
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    if tool=="Bash":
        cmd=ti.get("command")
        if isinstance(cmd,str) and cmd:
            print("__BASH__"); sys.exit(0)
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

_resolve_root=""
_root_probe="$_target"
[ "$_root_probe" = "__BASH__" ] && _root_probe=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_root_probe"; then
  _resolve_root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$_resolve_root" ]; then
  d="$_root_probe"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  _resolve_root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$_resolve_root" ] && _resolve_root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$_resolve_root" ] && deny "no project root could be determined; failing closed (action-item shape check cannot run)."
root="$_resolve_root"

_bash_tokens=""
if [ "$_target" = "__BASH__" ]; then
  _cmd="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
if isinstance(e,dict):
    ti=e.get("tool_input")
    if isinstance(ti,dict):
        c=ti.get("command")
        if isinstance(c,str): sys.stdout.write(c)
' 2>/dev/null || true)"
  _bash_tokens="$(gate_bash_write_targets "$_cmd")"
fi

PG_PAYLOAD="$payload" PG_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" PG_BASH_TOKENS="$_bash_tokens" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys, importlib.util

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (action-item shape).")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/incident-response\.md$')

    OWNER_RE = re.compile(
        r'@[A-Za-z0-9_.\-]+'
        r'|^\s*[-*]\s*(?!(?:The|This|It|A|An|We|They|Our)\s*[:\-\u2013\u2014])([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)\s*[:\-\u2013\u2014]',
    )
    DEADLINE_RE = re.compile(
        r'\d{4}-\d{2}-\d{2}'
        r'|\bby\s+(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|next\s+\w+|end\s+of\s+(?:day|week|month)|[A-Z][a-z]+\s+\d{1,2}(?:st|nd|rd|th)?|\d{4}-\d{2}-\d{2})'
        r'|\bwithin\s+\d+\s*(?:day|days|hour|hours|week|weeks)\b',
        re.I,
    )

    def shape_ok_in(text):
        lines = text.splitlines()
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
                in_section = True
                section_level = 99

        if not section_lines:
            section_lines = [ln for ln in lines if re.search(r'action\s*items?', ln, re.I)]

        for ln in section_lines:
            if OWNER_RE.search(ln) and DEADLINE_RE.search(ln):
                return True
        return False

    # --- Bash-tool write-target detection -----------------------------
    # Candidate tokens were already produced by the outer shell via
    # gate_bash_write_targets (sourced from gate-lib.sh) and passed
    # through PG_BASH_TOKENS, one per line; no gate_* logic is
    # reimplemented here, only consumed.
    if tool == "Bash":
        raw_tokens = os.environ.get("PG_BASH_TOKENS", "")
        candidates = [t for t in raw_tokens.splitlines() if t]
        current_cache = {}
        for cand in candidates:
            rel = gate_lib.gate_normalize_path(root, cand)
            if rel is None or rel == "":
                continue
            if not RECORD_RE.match(rel):
                continue
            full = posixpath.join(root, rel)
            if full not in current_cache:
                current_cache[full] = None
                if os.path.isfile(full):
                    try:
                        with open(full, encoding="utf-8-sig") as fh:
                            current_cache[full] = fh.read(1 << 20)
                    except OSError:
                        deny("%s exists but cannot be read; failing closed on the action-item shape check." % rel)
            current = current_cache[full]
            # A Bash write only needs to be checked against this gate's
            # own path-scope regex; reconstructing Bash-written content is
            # out of scope. If the file exists, judge its current content
            # (a Bash command about to write to this surface without the
            # file already carrying a valid shape is not this gate's
            # concern to reconstruct — but if content is already present
            # and already lacks shape, or the file does not yet exist, we
            # cannot prove a resulting shape, so deny).
            if current is not None and shape_ok_in(current):
                continue
            deny(
                "a Bash command targets %s but the gate cannot verify the resulting "
                "action-item shape from a Bash write (owner+deadline required per "
                "docs/issue-1/proposals/incident-response.md (b)1-3); reconstructing "
                "Bash-written content is out of scope, so this write is denied rather "
                "than guessed at." % rel
            )
        sys.exit(0)

    def resolve_target():
        if tool not in ("Write", "Edit", "MultiEdit"):
            return None
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            return p
        return None

    path = resolve_target()
    if path is None:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not this gate's write surface

    full = posixpath.join(root, rel) if rel else root
    current = None
    if os.path.isfile(full):
        try:
            with open(full, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on the action-item shape check." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the action-item shape can be "
            "checked." % (rel, tool)
        )

    if not shape_ok_in(new_text):
        deny(
            "per docs/issue-1/proposals/incident-response.md (b)1-3, action items need "
            "owner+verb+outcome+deadline: no action item in %s carries both an "
            "owner-looking token (a capitalized name/handle immediately before a colon or "
            "dash at the start of the line) and a deadline-looking token "
            "(an ISO date or a relative-date phrase like 'by Friday'/'within 3 days'). "
            "This is a shape check, not a truth check." % rel
        )

except SystemExit:
    raise
except Exception as _e:
    sys.stderr.write("incident-response: refused — internal error in action-item-gate (%s); failing closed.\n" % _e)
    sys.exit(2)
PY
