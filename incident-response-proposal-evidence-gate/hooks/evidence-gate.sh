#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit|Bash) — incident-response phase-1
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
# Issue #10 phase 2: migrated to source core's gate-house standard
# (CLAUDE_PLUGIN_ROOT_CORE/gate-lib.sh, gate-lib.py) instead of hand-rolling the
# fail-closed trap, kill-switch polarity, path normalization, and
# Edit/MultiEdit reconstruction. Elements (ii) and (iii) upgraded from
# bare substring/co-occurrence checks to section/paragraph-scoped
# extraction. A Bash-tool command that writes to this gate's surface is
# now also detected (path-scope only — content reconstruction for
# Bash writes is out of scope).
#
# CLAUDE_PLUGIN_ROOT_CORE must point at core's checked-out hooks/lib directory
# (core repo, not this one). Not set here because core is not vendored
# into this rulebook's tree — set it in the environment that loads this
# plugin alongside core.
#
# Kill switch: export INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF=1
#   (unrecognized values stay ACTIVE; only a recognized on-spelling
#   1/true/yes/on disables the gate — see gate_kill_switch_active)
. "${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}/hooks/lib/gate-lib.sh" || { echo "evidence-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

role="${CLAUDE_ROLE:-incident-response}"
deny() { echo "incident-response: refused — $1" >&2; exit 2; }

gate_kill_switch_active "${INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "evidence-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "evidence-gate: empty tool-use payload on stdin; cannot evaluate the evidence gate."

_tool_name="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
if isinstance(e,dict):
    v=e.get("tool_name")
    if isinstance(v,str): print(v)
' 2>/dev/null || true)"

_target=""
if [ "$_tool_name" = "Bash" ]; then
  _command="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("command")
    if isinstance(v,str) and v: print(v)
' 2>/dev/null || true)"
else
  _target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("file_path")
    if isinstance(v,str) and v: print(v)
' 2>/dev/null || true)"
fi

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
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && { [ "$_tool_name" = "Bash" ] || _under "$CLAUDE_PROJECT_DIR" "$_target"; }; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (evidence check cannot run)."

# Bash-tool write-target detection: scan tool_input.command for path-shaped
# tokens via gate_bash_write_targets and check each against this gate's
# write-surface pattern (path-scope only; content reconstruction for a
# Bash-tool write is out of scope per the issue-10 migration spec).
if [ "$_tool_name" = "Bash" ]; then
  [ -n "${_command:-}" ] || exit 0
  while IFS= read -r _tok; do
    [ -n "$_tok" ] || continue
    if EG_ROOT="$root" EG_TOK="$_tok" python3 -c '
import os, posixpath, re, sys, importlib.util
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
root = posixpath.normpath(os.environ["EG_ROOT"].replace("\\", "/"))
SURFACE_RE = re.compile(r"^docs/issue-[0-9]+/proposals/incident-response.*\.md$", re.I)
n = gate_lib.gate_normalize_path(root, os.environ["EG_TOK"])
sys.exit(0 if (n and SURFACE_RE.match(n)) else 1)
'; then
      deny "a Bash command appears to write to this gate's content-shape write surface " \
"(token: $_tok); the gate cannot inspect a Bash-tool write's resulting content, so it " \
"denies rather than silently letting it bypass the evidence-shape check. Use " \
"Write/Edit/MultiEdit for this file instead."
    fi
  done <<EOF
$(gate_bash_write_targets "$_command")
EOF
  exit 0
fi

EG_PAYLOAD="$payload" EG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys, importlib.util

    def deny(m):
        sys.stderr.write("incident-response: refused — %s\n" % m); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("EG_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (evidence gate).")

    root = posixpath.normpath(os.environ["EG_ROOT"].replace("\\", "/"))
    SURFACE_RE = re.compile(r'^docs/issue-[0-9]+/proposals/incident-response.*\.md$', re.I)

    if tool not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    path = ti.get("file_path")
    if not (isinstance(path, str) and path):
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)
    if not SURFACE_RE.match(rel):
        sys.exit(0)  # not this gate's own write surface

    # gate_normalize_path is pure string algebra (no realpath); still
    # realpath the absolute candidate to read the file off disk.
    def resolve_real(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    r = resolve_real(path)
    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on the evidence gate." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the evidence-shape elements can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    # Section-scoped extraction: locate a heading (or bare label line)
    # matching a keyword, and pull its content up to the next
    # equal-or-higher-level heading or end of document. Mirrors
    # action-item-gate.sh's heading_re/section_lines construction so all
    # gates in this rulebook share one section-scoping idiom.
    def section_for(keyword_re):
        lines = new_text.splitlines()
        heading_re = re.compile(r'^(#{1,6})\s*.*(?:' + keyword_re + r')', re.I)
        out = []
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
                out.append(ln)
        return out

    # Paragraph-scoped fallback: blank-line-delimited blocks, used when a
    # document states its adopt/skip list or scout-skip reason inline
    # without a dedicated heading (e.g. a short proposal). Both a heading
    # section and a paragraph are "structural units" in the sense the
    # issue-10 semantic-upgrade requires: words must co-occur in the SAME
    # unit, not merely anywhere in the document.
    def paragraphs():
        return re.split(r'\n\s*\n', new_text)

    missing = []

    # (i) current-state survey reference
    if not has_any("current-state-survey", "current-state survey", "current state survey"):
        missing.append(
            "(i) no reference to the current-state survey (per docs/issue-1/proposals/"
            "methodology-norms.md (a)(2))"
        )

    # (ii) scout brief reference, or an explicit stated skip — scoped to a
    # scout-labeled heading section or a paragraph mentioning scout, not
    # bare "skip" + "scout" co-occurrence anywhere in the whole document.
    scout_referenced = has_any("scout-brief", "scout brief")
    scout_section = section_for(r'scout')
    scout_units = ["\n".join(scout_section)] if scout_section else []
    scout_units += [p for p in paragraphs() if re.search(r'\bscout\b', p, re.I)]
    NEG_RE = re.compile(r'\b(not|never|n\'t|didn\'t)\b[^.\n]*\bskip', re.I)

    def _unit_skip_stated(u):
        if NEG_RE.search(u):
            return False
        if re.search(r'\bskip', u, re.I):
            return True
        if re.search(r'scout skip|skipped scouting', u, re.I):
            return True
        if re.search(r'\bbugfix\b', u, re.I) and re.search(r'no design decision', u, re.I):
            return True
        return False

    scout_skip_stated = any(_unit_skip_stated(u) for u in scout_units)
    if not (scout_referenced or scout_skip_stated):
        missing.append(
            "(ii) no reference to the scout brief and no explicit stated scout-directive "
            "skip reason within a scout-related section (per docs/issue-1/proposals/"
            "methodology-norms.md (a)(2))"
        )

    # (iii) explicit adopt/skip list — section/paragraph-scoped: an
    # adopt-tagged item and a skip-tagged item must appear within the SAME
    # heading section or paragraph, not merely anywhere in the document.
    TAG_ADOPT = re.compile(r'(?:^|\n)\s*[-*]?\s*adopt\b\s*[:\-\u2013\u2014]', re.I)
    TAG_SKIP = re.compile(r'(?:^|\n)\s*[-*]?\s*skip\b\s*[:\-\u2013\u2014]', re.I)
    adopt_section = section_for(r'adopt')
    units = (["\n".join(adopt_section)] if adopt_section else []) + paragraphs()
    adopt_skip_list_ok = any(TAG_ADOPT.search(u) and TAG_SKIP.search(u) for u in units)
    if not adopt_skip_list_ok:
        missing.append(
            "(iii) no explicit adopt/skip list — an adopt-tagged item and a skip-tagged "
            "item must appear in the same section/paragraph (per docs/issue-1/proposals/"
            "methodology-norms.md (a)(3))"
        )

    # (iv) rationale tying an adopted item back to this role's own decision
    # boundary — same section/paragraph scoping: the decision-boundary
    # reference must co-occur with an adopt-tagged item in the same unit.
    boundary_markers = ("issue-1", "decision boundary", "장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가")
    rationale_ok = any(
        TAG_ADOPT.search(u) and any(m in u.lower() for m in boundary_markers)
        for u in units
    )
    if not rationale_ok:
        missing.append(
            "(iv) no rationale tying an adopted item back to this role's own decision "
            "boundary within the same section/paragraph as the adopt item (per docs/"
            "issue-1/proposals/methodology-norms.md (a)(3))"
        )

    if missing:
        deny(
            "proposal write to %s is missing required element(s): %s" % (rel, "; ".join(missing))
        )

    sys.exit(0)
except SystemExit:
    raise
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
