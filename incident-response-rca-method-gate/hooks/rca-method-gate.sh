#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit|Bash) — incident-response phase-2
# record, ADDITIVE to (never a replacement for) core's generic
# field-presence gate.
#
# Target: docs/issue-<n>/reports/incident-response.md — this role's phase-2
# write surface.
#
# Requires, beyond generic field presence:
#   1. An RCA-method name is present (5 Whys / causal chain / fishbone /
#      fault tree), case-insensitive substring match.
#   2. A primary-vs-contributing-factor textual distinction is present:
#      "primary" together with "contributing" or "secondary" within the
#      SAME paragraph or section (not just anywhere in the document) — a
#      lightweight structural check, not semantic.
#
# Per docs/issue-1/proposals/incident-response.md (b)1-3.
#
# Explicitly NOT gated here: blamelessness/tone language — per issue-1 (c),
# that is documented guidance, not machine-checkable, and intentionally out
# of scope for this gate.
#
# Migrated to core's gate-house standard (issue #10 phase 2): trap,
# kill-switch, JSON parse, path normalization, Edit/MultiEdit
# reconstruction, and Bash-write-target scanning are all sourced from
# gate-lib.sh/gate-lib.py via CLAUDE_PLUGIN_ROOT_CORE, never hand-rolled here.
#
# Kill switch: export INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}/hooks/lib/gate-lib.sh" || { echo "rca-method-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

role="${CLAUDE_ROLE:-incident-response}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

gate_kill_switch_active "${INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "rca-method-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "rca-method-gate: empty tool-use payload on stdin; cannot evaluate the RCA-method gate."

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

_root_probe="$_target"
[ "$_root_probe" = "__BASH__" ] && _root_probe=""
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_root_probe"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_root_probe"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (RCA-method check cannot run)."

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

RG_PAYLOAD="$payload" RG_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" RG_BASH_TOKENS="$_bash_tokens" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys, importlib.util

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("RG_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (RCA-method).")

    root = posixpath.normpath(os.environ["RG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/incident-response\.md$')

    def method_named_in(low):
        return any(nd in low for nd in (
            "5 whys", "five whys", "causal chain", "causal-chain",
            "causal timeline", "fishbone", "fault tree", "fault-tree",
        ))

    def distinction_present_in(text):
        # Section/paragraph-scoped check (issue #10 semantic upgrade): both
        # "primary" and "contributing"/"secondary" must appear within the
        # SAME structural unit, not just anywhere in the document. Mirrors
        # action-item-gate.sh's heading-then-section-lines idiom: a
        # "section" is the text from one heading up to (not including) the
        # next heading-or-lower-level heading; a "paragraph" is a
        # blank-line-delimited block. Either scope satisfying the check is
        # enough — this is a shape check, not NLP truth verification.
        blocks = re.split(r'\n\s*\n', text)

        sections = []
        cur = []
        for ln in text.splitlines():
            if re.match(r'^#{1,6}\s+\S', ln):
                if cur:
                    sections.append('\n'.join(cur))
                cur = [ln]
            else:
                cur.append(ln)
        if cur:
            sections.append('\n'.join(cur))

        for scope in blocks + sections:
            s = scope.lower()
            if "primary" in s and ("contributing" in s or "secondary" in s):
                return True
        return False

    def judge(text):
        low = text.lower()
        missing = []
        if not method_named_in(low):
            missing.append("rca-method-named")
        if not distinction_present_in(text):
            missing.append("primary-contributing-distinction")
        return missing

    def deny_missing(rel, missing):
        deny(
            "incident-response phase-2 record (%s) is missing required element(s): %s. Per "
            "docs/issue-1/proposals/incident-response.md (b)1-3, every phase-2 "
            "incident-response report must name an RCA method (5 Whys / causal chain / "
            "fishbone / fault tree) and textually distinguish the primary cause from "
            "contributing (or secondary) factors within the same paragraph or section." % (rel, ", ".join(missing))
        )

    # --- Bash-tool write-target detection -----------------------------
    if tool == "Bash":
        cmd = ti.get("command")
        if not isinstance(cmd, str) or not cmd:
            sys.exit(0)
        candidates = re.findall(r'[A-Za-z0-9_./~$-]+', cmd)
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
                        deny("%s exists but cannot be read; failing closed on RCA-method." % rel)
            current = current_cache[full]
            # Reconstructing Bash-written content is out of scope; only
            # path-scope matching applies here (mirrors action-item-gate.sh).
            if current is not None:
                missing = judge(current)
                if not missing:
                    continue
                deny_missing(rel, missing)
            else:
                deny(
                    "a Bash command targets %s but the gate cannot verify the resulting "
                    "RCA-method fields from a Bash write; reconstructing Bash-written "
                    "content is out of scope, so this write is denied rather than "
                    "guessed at." % rel
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
        sys.exit(0)  # not this gate's write surface — not this gate's business

    full = posixpath.join(root, rel) if rel else root
    current = None
    if os.path.isfile(full):
        try:
            with open(full, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on RCA-method." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the RCA-method fields can be "
            "checked." % (rel, tool)
        )

    missing = judge(new_text)
    if missing:
        deny_missing(rel, missing)

    sys.exit(0)
except SystemExit:
    raise
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("rca-method-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
