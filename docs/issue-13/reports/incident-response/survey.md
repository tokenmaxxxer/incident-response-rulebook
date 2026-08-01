# Current-state survey — issue #13 (gate A+ final closeout, re-audit grade B-)

## Scout: skip record

Skipped. This deliverable adopts an already-approved, already-landed
external canon (core issue #75's gate-lib source guard, core's
compliance-check.sh detection rule, and on-the-record issue #182's
CLAUDE_PLUGIN_ROOT_CORE injection) verbatim — the issue text itself names
the reference implementation to apply. There is no open design decision
to scout a field for; the remedy shape is fixed by the precondition
landings, confirmed below.

## Preconditions (confirmed landed)

- core #75 (`tokenmaxxxer-core` @ `52bdc15`): `gate-lib.sh`'s usage
  contract now requires `. "${CLAUDE_PLUGIN_ROOT_CORE:-<fallback>}/hooks/lib/gate-lib.sh" || { echo ... >&2; exit 2; }`
  — an `||`-guarded source, fail-closed if core is unreachable. All 7 core
  gates use this exact form. `compliance-check.sh` gained a detection rule
  (line 58) that fails any `*-gate.sh` sourcing `gate-lib.sh"$` with no
  `||` guard on the same line. `gate_bash_write_targets` was ported to
  `gate-lib.py` with sh/py parity tests.
- on-the-record #182 (PR #185, merged 2026-08-01): `spawn_cmd()` now
  injects `CLAUDE_PLUGIN_ROOT_CORE` from the already-resolved `core_plugins`
  entry named `core` — the same path handed to `--plugin-dir` — into the
  role session's env. If no `core` entry is present, no injection happens
  and a warning prints (no silent fallback).

Both confirmed via `git log`/`gh pr diff` against the live repos, not
assumed from the issue text.

## Defect 1 — hooks.json Bash matcher missing (all 4 gate plugins)

All four gate plugins' `hooks/hooks.json` declare
`"matcher": "Write|Edit|MultiEdit"` with no `Bash`:

- `incident-response-action-item-gate/hooks/hooks.json`
- `incident-response-proposal-evidence-gate/hooks/hooks.json`
- `incident-response-proposal-order-gate/hooks/hooks.json`
- `incident-response-rca-method-gate/hooks/hooks.json`

Yet all four gate scripts carry a live `if tool == "Bash": ...` /
`if [ "$_tool_name" = "Bash" ]` branch (confirmed at
`action-item-gate.sh:171`, `evidence-gate.sh:58,109`, `order-gate.sh:224`,
`rca-method-gate.sh:88,180`), each header-commented
`# PreToolUse gate (Write|Edit|MultiEdit|Bash)`, and each gate's own test
suite exercises the Bash branch directly by invoking the script — the
suite never goes through `hooks.json`, so a green suite does not catch
this. `docs/issue-10/reports/incident-response.md` claims (§"What
shipped") `gate_bash_write_targets` scanning was "added to all four
gates" and reports the suites green — true of the code, false of
production reachability: Claude Code only invokes a `PreToolUse` hook
whose `matcher` matches the tool name, so every advertised/tested Bash
branch is dead code in the shipped product. A `Bash` command writing
directly to any of the four write surfaces (e.g. `printf ... >
docs/issue-N/reports/incident-response.md`) reaches no gate at all.

## Defect 2 — owner-check bypass ('The:' / 'due diligence')

`action-item-gate.sh` (both plugin script and its RECORD_RE-scoped Python
judge, `:123-133`):

```python
OWNER_RE = re.compile(
    r'@[A-Za-z0-9_.\-]+'
    r'|^\s*[-*]\s*([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)\s*[:\-–—]',
)
DEADLINE_RE = re.compile(
    r'\d{4}-\d{2}-\d{2}'
    r'|\bby\s+(?:...)'
    r'|\bwithin\s+\d+\s*(?:day|days|hour|hours|week|weeks)\b'
    r'|\bdue\s+(?:by\s+)?\S+',
    re.I,
)
```

- `OWNER_RE`'s second alternative accepts ANY capitalized word
  immediately before a colon/dash at the start of a bullet line as an
  "owner-looking token" — no stopword/pronoun exclusion. A line like
  `- The: fix should happen soon` satisfies it (`The` matches
  `[A-Z][a-z]+` immediately before `:`), even though "The" is not an
  owner.
- `DEADLINE_RE`'s last alternative, `\bdue\s+(?:by\s+)?\S+`, matches the
  bare word "due" followed by any non-space token — so the unrelated
  phrase "due diligence" (as in "complete our due diligence review")
  satisfies the deadline check with no date/relative-date semantics at
  all.
- Because `shape_ok_in()` only requires `OWNER_RE.search(ln) and
  DEADLINE_RE.search(ln)` on the SAME line, a bullet like `- The due
  diligence: TBD` passes both checks and the gate accepts it as a
  properly-shaped action item, despite carrying neither a real owner nor
  a real deadline. `docs/issue-10/reports/incident-response.md` (a)
  claims this owner check was already fixed ("no longer qualifies as an
  owner" for "a mid-sentence capitalized word") — true for mid-sentence
  words, but the line-start-before-colon shape it left in place has no
  stopword guard, so this specific bypass survived that fix.
- `rca-method-gate.sh` and `order-gate.sh` were checked for an equivalent
  bare-capitalized-word or bare-keyword pattern; neither carries an
  owner/deadline-shaped check (out of scope for those gates), so this
  defect is confined to `action-item-gate.sh`.

## Defect 3 — evidence-gate negation-ignoring fallback

`evidence-gate.sh`'s Python judge, element (ii) scout-skip detection
(`:250-259`):

```python
scout_referenced = has_any("scout-brief", "scout brief")
scout_section = section_for(r'scout')
scout_units = ["\n".join(scout_section)] if scout_section else []
scout_units += [p for p in paragraphs() if re.search(r'\bscout\b', p, re.I)]
scout_skip_stated = any(
    re.search(r'\bskip', u, re.I) and not re.search(r'\b(not|never|n\'t|didn\'t)\b[^.\n]*\bskip', u, re.I)
    for u in scout_units
) or has_any("scout skip", "skipped scouting") or (
    has_any("bugfix") and has_any("no design decision")
)
```

The first disjunct (the `any(...)` over `scout_units`) IS
negation-aware, matching `docs/issue-10/reports/incident-response.md`
(c)'s claim ("we did NOT skip the scout step" no longer counts) for that
one path. But `scout_skip_stated` is a 3-way `or`, and the second and
third disjuncts bypass the negation guard entirely:
`has_any("scout skip", "skipped scouting")` is a bare whole-document
substring check (defined at `:200-201` as `any(nd in low for nd in
needles)`) with no section/paragraph scoping and no negation check at
all. A proposal document containing the sentence "We never skipped
scouting for this change" contains the literal substring "skipped
scouting", so `has_any("scout skip", "skipped scouting")` returns `True`
regardless of the negating "never" three words earlier — the gate
accepts a document that explicitly says scouting was NOT skipped (and
which, per the surrounding sentence, presumably also didn't do a
real scout pass with a brief) as satisfying the "explicit stated skip"
element. The negation-ignoring fallback the re-audit flagged is this
second/third disjunct, not the first.

## Defect 4 — README write_scope / ghost content

Root `README.md`'s header block still states:

```
- **write_scope**: ['docs/issue-<n>/postmortems/**']
```

`docs/issue-10/reports/incident-response.md` (d) claims `WRITE_SCOPE` was
corrected from this exact ghost path to the two real write surfaces
(`docs/issue-<n>/proposals/incident-response*.md`,
`docs/issue-<n>/reports/incident-response.md`) — true only inside
`incident-response/hooks/directive.sh` (confirmed: its `WRITE_SCOPE`
constant now holds the corrected surfaces). The root README's own
human-facing header line was never touched and still advertises the old
`postmortems/**` scope nobody's write surface has ever pointed at.

Separately, the README's "## Layout" section:

- Lists `incident-response/hooks/record-fields-gate.sh` as a file — the
  actual file at that path is `record-fields.config.sh` (confirmed via
  `ls incident-response/hooks/`). The referenced `record-fields-gate.sh`
  does not exist anywhere in the tree — a ghost file reference.
- Never mentions any of the four gate plugins
  (`incident-response-action-item-gate`,
  `incident-response-proposal-evidence-gate`,
  `incident-response-proposal-order-gate`,
  `incident-response-rca-method-gate`) that have existed since issue #7
  phase 2 and are correctly listed in `.claude-plugin/marketplace.json`
  (confirmed current, no staleness there) — the README's own picture of
  "what this rulebook installs" is missing 4/5 of the shipped plugins.

No stale pre-43-taxonomy role name was found in any `plugin.json`,
`marketplace.json`, or gate `README.md` (all checked; each plugin's own
`README.md` documents its own gate accurately, matching #10's claim that
"no ghost-file references were found in the four gate READMEs
themselves" — confirmed still true). The ghost content is confined to
the root `README.md`.

## Additional confirmed defect — CORE_HOOKS_LIB vs. the now-landed CLAUDE_PLUGIN_ROOT_CORE (in scope: "공통 항목은 core #75의 확정 가드 참조 적용")

Not named verbatim in the issue's defect list, but directly inside its
"apply core #75's finalized guard by reference" instruction, and newly
exposed by on-the-record #182 landing during this same re-audit cycle:

- `directive.sh` and all four gate scripts source core's library via
  `. "${CORE_HOOKS_LIB:?}/gate-lib.sh"` / `.../role-directive.sh` — a
  DIFFERENT environment variable name than `CLAUDE_PLUGIN_ROOT_CORE`,
  which is the variable on-the-record's `spawn_cmd()` (confirmed, PR #185)
  now actually injects into every spawned role session. `CORE_HOOKS_LIB`
  is set by nothing in the spawn path — confirmed via
  `grep -rn CORE_HOOKS_LIB` across this tree: it only appears in this
  rulebook's own scripts/tests/READMEs/docs, never in `spawn.py` or any
  core file. In production this rulebook's gates always fail closed one
  step later than intended (they DO fail closed today, because `:?`
  aborts the script) — but only by accident, and not in the form core #75
  standardized.
- The `:?` form (`"${CORE_HOOKS_LIB:?}"`) also does not match core #75's
  confirmed guard shape. `gate_trap_fail_closed` is installed on the LINE
  AFTER the source line in every one of this rulebook's gates
  (`action-item-gate.sh:25-26`, `evidence-gate.sh:34-35`,
  `order-gate.sh`, `rca-method-gate.sh:29-30`, `directive.sh:34`) — so if
  `CORE_HOOKS_LIB` is unset, the `:?` expansion error fires and the shell
  exits BEFORE the fail-closed EXIT trap is installed, at whatever exit
  status bash gives an unset-parameter error under `set -uo pipefail`
  context (not guaranteed to be 2). Per core #75's own doc comment
  (`gate-lib.sh:10-16`) and `compliance-check.sh`'s detection rule
  (`:52-59`), an unguarded source with no `||` on the same line is the
  exact issue-75-confirmed fail-open shape: Claude Code treats any hook
  exit other than 0/2 as non-blocking, so a missing/misnamed core
  variable can silently disable every gate in this rulebook rather than
  denying.
- `core/hooks/tests/compliance-check.sh` was not run against this
  rulebook's own gates during this survey pass (that is phase-2 work),
  but its detection rule at `:52-59` (`grep -q 'gate-lib\.sh"$' "$f" &&
  ! grep -qE 'gate-lib\.sh"[[:space:]]*\|\|' "$f"`) will flag every one of
  this rulebook's four gate scripts once run, because none of their
  source lines carry an `||` guard on the same line.

## Scope confirmation against the issue's four requirements

1. All defects above are traceable to a concrete file/line; core #75's
   finalized guard shape and `compliance-check.sh` rule are the reference
   to apply for the source-guard/variable-name defect.
2. Defect 1 is exactly matcher/code coverage parity.
3. Full green suite + missing-core test case + compliance-check pass is
   phase-2 work; not attempted here (phase 1 only).
4. Defect 4 covers the README ghost content; manifest was checked and is
   already clean.
