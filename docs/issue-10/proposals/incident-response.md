# Proposal — issue #10: gate A+ remediation (current grade B-)

Current-state survey: docs/issue-10/reports/incident-response/current-state-survey.md
Scout brief: docs/issue-10/reports/incident-response/scout-brief.md

This is a phase-1 proposal only — design and adopt/skip decisions. No
gate/test/README code changes ship in this PR; phase 2 opens only after
an approvers.md account posts `APPROVE issue-10/incident-response` (or a
two-account PR review Approve).

## 1. Scope: the four defect classes named in the issue

Confirmed by the survey against direct code reads of all four gates
(`incident-response-action-item-gate`, `-proposal-evidence-gate`,
`-proposal-order-gate`, `-rca-method-gate`):

- (a) owner check matches any capitalized word, not an actual owner token
  (`action-item-gate.sh:193`).
- (b) `and False` dead code in the action-item shape loop
  (`action-item-gate.sh:204`).
- (c) scout-skip / adopt-skip / RCA-distinction heuristics are bare
  substring or word co-occurrence checks with no adjacency, section, or
  polarity awareness (`order-gate.sh:125-132`, `evidence-gate.sh:166-195`,
  `rca-method-gate.sh:172-182`).
- (d) `WRITE_SCOPE` in `incident-response/hooks/directive.sh:32` names
  `docs/issue-<n>/postmortems/**`, a path no gate, hook, or test in this
  repo reads or writes — a ghost path; the real write surfaces are
  `docs/issue-<n>/proposals/incident-response*.md` and
  `docs/issue-<n>/reports/incident-response.md`.

Plus, from the precondition (core issue #72 landed) and confirmed present
in all four gates today: hand-rolled fail-closed trap, hand-rolled
kill-switch polarity (pre-fix, fail-open-on-unrecognized-value),
hand-rolled `Edit`/`MultiEdit` reconstruction (`replace_all` ignored),
hand-rolled path normalization, and no `Bash`-write coverage.

## 2. Adopt core's gate-house standard by reference (issue #10 requirement 1)

All four gates migrate to source `core/hooks/lib/gate-lib.sh` and load
`gate-lib.py`, per `docs/handbooks/gate-house-standard.md`'s migration
checklist:

- Replace each gate's hand-rolled `__fc` trap
  (`trap 'rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then ...; fi' EXIT`)
  with `gate_trap_fail_closed`, called before `set -uo pipefail`.
- Replace each gate's
  `case "${..._OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac` with
  `gate_kill_switch_active "${..._OFF:-}" || { trap - EXIT; exit 0; }`.
  This is a genuine behavior change, not just a refactor: today, any
  unrecognized value (a typo, e.g. `INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF=1x`)
  falls into the `*` branch and silently disables the gate; after
  migration, only a recognized on-spelling disables it, everything else
  (including unrecognized garbage) stays active.
- Replace each gate's own `current.replace(o, n, 1)` /
  `MultiEdit` loop with `gate_lib.gate_reconstruct_write(tool, tool_input,
  current_content)`, so `replace_all: true` on `Edit` and mixed
  `replace_all` across `MultiEdit` edits reconstruct correctly, and
  `NotebookEdit` becomes reconstructable (none of the four gates handle
  `NotebookEdit` today, despite `action-item-gate.sh` and `order-gate.sh`
  both reading `notebook_path` as an alternate target key at line ~42 —
  the target-detection code already half-expects `NotebookEdit`, but the
  reconstruction code never handled it).
- Replace each gate's `_plausible`/`_under`/`resolve` path helpers with
  `gate_lib.gate_normalize_path(root, path)`.
- Add `gate_bash_write_targets` scanning to each gate's `PreToolUse`
  matcher set (hooks.json) and dispatch logic, so a `Bash`-tool file write
  to the same target a `Write`/`Edit` call would hit is not invisible —
  applying each gate's own path-scope regex to every candidate token
  `gate_bash_write_targets` yields from `tool_input.command`.
- Run `core/hooks/tests/compliance-check.sh` against this repo's `hooks/`
  directories as an explicit phase-2 acceptance step (not vendored;
  invoked the way the handbook's migration checklist specifies) and record
  its clean output as evidence in the phase-2 record.

No re-implementation of any `gate_*` function: this proposal explicitly
adopts by reference (`. "${CORE_HOOKS_LIB:?}/gate-lib.sh"`, mirroring the
existing `directive.sh` pattern that already sources
`role-directive.sh` from `CORE_HOOKS_LIB`), never a vendored copy.

## 3. Semantic-check upgrade: substring → section/adjacency/structure (requirement 2)

Core's canon stops at structural correctness (JSON/path/reconstruction);
it does not define role-specific semantic checks. This rulebook's four
content checks upgrade as follows — each replaces a same-file, same-line
bare `in`/`has_any` substring test with a scoped, structural one:

- **`action-item-gate.sh` owner check** — replace `OWNER_RE`'s bare
  `\b[A-Z][a-z]+(?:\s[A-Z][a-z]+)?\b` alternative (matches any capitalized
  word) with a structural test: an owner token is either an `@handle`, OR
  a capitalized-word-sequence that appears **immediately before a colon or
  dash separator at the start of the action-item line**
  (`^\s*[-*]\s*([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)\s*[:\-–—]`), matching the
  README's own documented example shape (`Jiwon Jung: patch the retry loop
  by 2026-08-15`). A capitalized word appearing mid-sentence (e.g.
  "Investigate alerting gap") no longer qualifies as an owner. Also delete
  the dead `and False` branch (item 1(b)) rather than repair it — its
  intended behavior (excluding lines outside a real heading section) is
  already handled by the `section_lines` construction above it; the dead
  branch adds nothing once removed.
- **`order-gate.sh` scout-skip heuristic** — replace bare
  `("skip" in content) and ("scout" in content)` with a **section-scoped**
  check: locate a heading matching `scout` (case-insensitive, same heading
  regex shape `action-item-gate.sh` already uses for "action items") and
  require an explicit skip marker within that section OR within one
  sentence of a "scout" mention — e.g. a regex requiring `skip` and
  `scout` within a bounded token window (~15 tokens) of each other AND not
  preceded within that window by a negation token (`not`, `didn't`,
  `never`, `n't`). This directly kills the false-positive case the survey
  confirmed ("we did NOT skip the scout step").
- **`evidence-gate.sh` adopt/skip list (element iii)** — replace bare
  `has_any("adopt") and has_any("skip")` with a structural check: locate a
  heading or bare label line matching `adopt`, and require that the
  section under it contains at least one bulleted/lined item tagged
  `adopt` and at least one tagged `skip` (reusing the same
  heading-then-section-lines extraction `action-item-gate.sh` already
  implements, so this is a shared helper opportunity — see §5). Same
  section-scoping applies to element (ii)'s `scout_skip_stated` check,
  mirroring the order-gate fix so both gates enforce the same scoped
  definition of a stated skip.
- **`evidence-gate.sh` element (iv)** and **`rca-method-gate.sh`'s
  primary/contributing distinction** — upgrade from "both words present
  anywhere" to "both words present within the same paragraph/section" —
  same bounded-window-or-section-scoping technique, applied consistently
  so all four gates share one semantic-scoping idiom rather than four
  independently-invented ones.

This upgrade is deliberately NOT full NLP/semantic understanding (still a
shape check, not a truth check, per each gate's existing documented
disclaimer) — it raises the bar from "these words exist somewhere in the
document" to "these words exist in the same structural unit, in a
non-negated relationship," which closes the specific false-positive/
false-negative classes the audit found without claiming to verify meaning.

## 4. README / write-scope fix (requirement 4)

- `incident-response/hooks/directive.sh:32`: change `WRITE_SCOPE` from
  `['docs/issue-<n>/postmortems/**']` to the two real write surfaces:
  `['docs/issue-<n>/proposals/incident-response*.md',
  'docs/issue-<n>/reports/incident-response.md']`, matching what
  `PRODUCES` on the same file already documents accurately.
- Each of the four gate READMEs already documents its own write surface
  correctly (confirmed against each gate's own `SURFACE_RE`/`RECORD_RE`)
  — no ghost-file references found in the four gate READMEs themselves;
  only the centralized `directive.sh` `WRITE_SCOPE` was stale. Each README
  gets one addition: a "Migrated to gate-lib.sh" note once phase 2 lands,
  replacing the current kill-switch section's description of the
  hand-rolled polarity with the corrected one.

## 5. Mandatory test cases (requirement 3)

Each of the four gates' test suites (`action-item-gate.test.sh`,
`evidence-gate.test.sh`, `order-gate.test.sh`, `rca-method-gate.test.sh`)
adds, adapted to its own write surface and payload shape, the same six
case groups `core/hooks/tests/run-gate-lib-tests.sh` makes mandatory for
`gate-lib.sh` itself, applied end-to-end through each gate script (not
just against the library):

1. `Edit` with `replace_all: true` against a multiply-occurring
   `old_string` on that gate's write surface — asserts the reconstructed
   text is judged, not just the first occurrence.
2. `MultiEdit` with mixed `replace_all: true`/`false` edits in one call.
3. Malformed JSON on stdin (truncated, non-object, empty) — already
   partially covered (`action-item-gate.test.sh` has one malformed-JSON
   case); extend to the other three suites.
4. Kill-switch set to an unrecognized value (e.g. `banana`) — must assert
   the gate stays **active** (deny), not disabled — this is the regression
   test for the fail-open bug this migration fixes.
5. Absolute `file_path` matching the same scope a relative-path fixture
   already matches, plus a `./`-prefixed variant.
6. A `Bash`-tool file write reaching the same target a `Write`-tool call
   would hit on that gate's surface — asserts equivalent deny/allow.

Plus, per gate, one regression case per §3 semantic fix: a negated
scout-mention case for `order-gate.sh`/`evidence-gate.sh` (must NOT be
treated as a skip record), a mid-sentence-capitalized-word case for
`action-item-gate.sh` (must NOT be treated as an owner), and a
cross-section "primary" and "contributing" appearing in unrelated
paragraphs for `rca-method-gate.sh` (must NOT pass).

Following `run-gate-lib-tests.sh`'s self-checking pattern, each suite
tracks which of the six-plus-semantic groups it exercised and fails
itself if any is missing, so "all green" cannot silently mean "some
groups skipped."

Delivery gate for phase 2: full suite green (all four `*.test.sh` files),
plus `compliance-check.sh` run clean against this repo's `hooks/`
directories, both captured as evidence in the phase-2 record.

## Adopt / skip summary

- **Adopt**: `gate-lib.sh`/`gate-lib.py` by reference (trap, kill-switch,
  reconstruction, path-normalize, bash-write-scan) in all four gates;
  `compliance-check.sh` as an invoked (not vendored) acceptance check;
  the six-case mandatory test-group pattern from
  `run-gate-lib-tests.sh`, adapted per gate.
- **Skip**: re-implementing any `gate_*` function locally (forbidden by
  the canon's reference-not-copy rule and by `stub-check.sh`'s
  `canon-manifest.txt` check); full NLP/semantic verification of
  action-item or RCA quality (explicitly out of scope, unchanged from each
  gate's existing "shape check, not a truth check" disclaimer); adding a
  fifth gate for blamelessness/tone (explicitly out of scope per issue-1
  (c), unchanged).

## Rationale back to this role's decision boundary

This role's decision boundary is 장애 후 무엇을 배웠고 재발을 무엇으로
막을 것인가 (issue-1). The A+ remediation matters to that boundary
specifically because a gate that can be silently bypassed by an
unrecognized kill-switch value, or that accepts a fabricated owner/
skip-record via substring co-occurrence, is a gate that stops actually
enforcing "what did we learn, what prevents recurrence" — the defects the
issue's audit found are not cosmetic; they are exactly the failure modes
that let a phase-1/phase-2 record pass review without the shape the
methodology requires. Adopting the core canon (rather than re-deriving it)
keeps this role's four gates aligned with the same fail-closed guarantees
every other rulebook gate now shares, so a future core-level fix (e.g. a
further gate-lib.sh bugfix) propagates here automatically instead of
silently diverging again.
