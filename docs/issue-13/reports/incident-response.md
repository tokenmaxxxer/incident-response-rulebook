# Report — issue #13: gate A+ re-audit remediation (phase 2)

Proposal: docs/issue-13/proposals/incident-response.md
Survey: docs/issue-13/reports/incident-response/survey.md

## What was done

Verified phase-2 gate A+ re-audit remediation for issue #13: ran all four
gate plugins' test suites fresh, ran core's `compliance-check.sh` against
each gate's `hooks/` directory, added one missing-core fail-closed
regression test to `incident-response-action-item-gate`'s suite, and
wrote this delivery record confirming all four re-audit defects plus the
`CORE_HOOKS_LIB` → `CLAUDE_PLUGIN_ROOT_CORE` migration landed correctly.

## Why

Issue #13 requires phase-2 evidence that the five independent workers'
edits (hooks.json matcher fix, action-item-gate owner/deadline fix,
evidence-gate negation fix, README fix, and the source-guard migration)
actually hold together as a whole and pass core's own compliance check —
not just that each edit's author believed it worked in isolation. This
record is that evidence.

## Summary

Phase-2 delivery for issue #13 (post-#10 re-audit remediation). All four
re-audit defects the issue named, plus the `CORE_HOOKS_LIB` →
`CLAUDE_PLUGIN_ROOT_CORE` migration the survey additionally confirmed
(core #75 precondition), are fixed and verified against core's own
compliance tooling.

## What shipped, by issue requirement

### 1. The four re-audit defects + source-guard migration

- **hooks.json Bash-matcher gap**: all four gate plugins'
  `hooks/hooks.json` now list `"matcher": "Write|Edit|MultiEdit|Bash"`
  (confirmed by `grep -n matcher incident-response-*/hooks/hooks.json` —
  all 4 lines show `Bash` appended), closing the gap the proposal's item 1
  described: live, tested `Bash`-branch code in every gate script was
  previously unreachable via the real hook path because the matcher
  omitted `Bash`.
- **`action-item-gate.sh` owner/deadline bypass**: `OWNER_RE`'s
  line-start-before-colon alternative now rejects a stopword set
  (`The`/`This`/`It`/`A`, etc. — proposal item 3), and the bare
  `\bdue\s+(?:by\s+)?\S+` alternative is removed from `DEADLINE_RE`
  entirely (proposal item 4). Regression coverage:
  `stopword-owner-and-bare-due-rejected` in
  `incident-response-action-item-gate/tests/action-item-gate.test.sh`
  (denies `- The due diligence: TBD`), plus the pre-existing
  `mid-sentence-capitalized-word-not-owner` case — both pass (see
  Verification below).
- **`evidence-gate.sh` negation-ignoring fallback**: the remaining two
  disjuncts — `has_any("scout skip", "skipped scouting")` and the
  `bugfix`/`no design decision` pair — are folded into the same
  section/paragraph-scoped, negation-guarded `scout_units` check the
  first disjunct already used (proposal item 5). Regression coverage:
  `negated-scout-skip-not-treated-as-skip` and
  `never-skipped-scouting-not-treated-as-skip` in
  `incident-response-proposal-evidence-gate/tests/evidence-gate.test.sh`
  — both pass.
- **README write_scope/ghost-file/Layout corrections**: root `README.md`
  line 11 now reads `write_scope`: the two real surfaces
  (`docs/issue-<n>/proposals/incident-response*.md`,
  `docs/issue-<n>/reports/incident-response.md`); the ghost
  `record-fields-gate.sh` reference is gone, replaced by the real
  `record-fields.config.sh` (README.md:28); the Layout section
  (README.md, `## Layout`) now lists all four gate plugins alongside the
  role plugin, matching `.claude-plugin/marketplace.json`.
- **`CORE_HOOKS_LIB` → `CLAUDE_PLUGIN_ROOT_CORE` migration**: every gate
  script and `incident-response/hooks/directive.sh` now sources via
  `. "${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}/hooks/lib/<lib>.sh" ||
  { echo "<script>: cannot source <lib>.sh" >&2; exit 2; }`, core #75's
  exact `||`-guarded shape. `grep -rn CORE_HOOKS_LIB --include="*.sh" .`
  across the repo returns zero hits — no stale reference remains in any
  shell source line.

### 2. hooks.json/code matcher parity

Confirmed for all 4 gate plugins by direct re-read (command above):
`incident-response-action-item-gate`, `-proposal-evidence-gate`,
`-proposal-order-gate`, `-rca-method-gate` each declare `"matcher":
"Write|Edit|MultiEdit|Bash"`, matching each script's own header comment
and existing `Bash`-branch code/tests.

### 3. Delivery-gate evidence — full suite, compliance-check, missing-core test

Full suite, all four gates, run fresh 2026-08-01 (this session):

```
incident-response-action-item-gate:        17 passed, 0 failed (9/9 groups, self-check ok)
incident-response-proposal-evidence-gate:   20 passed, 0 failed (self-check ok, all 8 groups)
incident-response-proposal-order-gate:      20 passed, 0 failed
incident-response-rca-method-gate:          16 passed, 0 failed (self-check: 7/7 groups)
```

(action-item-gate's count is 17, not the pre-existing 16, because this
session added the missing-core regression case below — group 9.)

`core/hooks/tests/compliance-check.sh` (referenced from
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`, not vendored), run against
each gate plugin's own `hooks/` directory:

```
compliance-check: ok — incident-response-action-item-gate/hooks/action-item-gate.sh
compliance-check: ok — incident-response-proposal-evidence-gate/hooks/evidence-gate.sh
compliance-check: ok — incident-response-proposal-order-gate/hooks/order-gate.sh
compliance-check: ok — incident-response-rca-method-gate/hooks/rca-method-gate.sh
```

All four `ok` — no "no `||` guard" finding on any gate script, confirming
the `CLAUDE_PLUGIN_ROOT_CORE`-based source-guard migration matches core's
exact expected shape.

**Missing-core regression test** (new, this session): added to
`incident-response-action-item-gate/tests/action-item-gate.test.sh` as
group 9 (`missing-core-unset-fails-closed`), mirroring the assertion
intent of core's own `run-gate-lib-tests.sh` group 7 ("missing-core ->
guarded source must deny, not allow"). The test invokes
`action-item-gate.sh` with `CLAUDE_PLUGIN_ROOT_CORE=` (empty) via `env`
and asserts a non-zero exit (fail-closed), rather than pinning one exit
code — `${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}` trips bash's own
unbound/empty-parameter guard directly (exit 1, before the `||`-guarded
source line's `exit 2` branch is even reached), while core's own test
points `CLAUDE_PLUGIN_ROOT_CORE` at a *nonexistent path* (not
empty/unset), which instead reaches the `|| exit 2` branch. Both are
fail-closed (non-zero); the assertion checks that property directly. Ran
and confirmed: `ok     missing-core-unset-fails-closed exit-1 (non-zero)`,
suite total 17 passed / 0 failed, self-check `all 9 mandatory groups
exercised`.

No code fix was needed in step 1 — none of the four suites regressed
from the five independent workers' edits; all reported green on first
fresh run this session, unmodified.

### 4. README/manifest ghost-role-name and ghost-file audit

Checked and confirmed clean:

- `grep -n "write_scope\|record-fields" README.md` shows the corrected
  `write_scope` field (line 11, two real surfaces) and the corrected
  `record-fields.config.sh` reference (line 28) — no `record-fields-gate.sh`
  ghost string remains anywhere in README.md.
- README.md's `## Layout` section lists all five plugins
  (`incident-response/` role plugin + the four gate plugins), matching
  `.claude-plugin/marketplace.json`'s installed set — the proposal's item
  6 scope, confirmed shipped.
- Per the proposal's explicit skip list, no change was made to
  `.claude-plugin/marketplace.json` or any individual gate plugin's own
  `README.md`/`plugin.json` — survey.md found no staleness or old-role-name
  reference in any of them, and none was introduced by this phase's edits
  (not re-checked beyond the survey's finding, per proposal scope).

## Adopt / skip (unchanged from proposal)

Adopted: core #75's `||`-guarded `CLAUDE_PLUGIN_ROOT_CORE` source shape in
all five sourcing sites; `Bash` in all four gate `hooks.json` matchers;
the owner-stopword and bare-`due` fixes; evidence-gate's negation-aware
scoping for the remaining two disjuncts; the README `write_scope`/ghost-
file/Layout corrections. Skipped (per proposal, unchanged): touching
`.claude-plugin/marketplace.json` or individual gate `README.md`s; full
NLP/semantic action-item or RCA quality verification.

## Verification session notes

This session ran verification-only (no gate-logic, hooks.json, or
README.md edits) except for adding the single missing-core regression
test case described in requirement 3 above, to
`incident-response-action-item-gate/tests/action-item-gate.test.sh`. All
four suites were confirmed green on first fresh run, and all four
`compliance-check.sh ok`, before that addition.

## Action Items

- Jiwon Jung: mirror the missing-core regression pattern (group 9 in
  action-item-gate's suite) into the other three gates' test suites by
  2026-08-15, so all four carry the same coverage rather than only one.
- Jiwon Jung: re-run all four suites + compliance-check.sh again after
  any future core `gate-lib.sh` release, within 3 days of that release.

## loop_state

loop_state: landed

Phase-2 verification complete: full suite green (17/20/20/16, 0 failed
across all four), compliance-check `ok` on all four gates, missing-core
regression test added and passing, README/manifest audit clean. Ready
for PR review.

## Open Findings

- Only `incident-response-action-item-gate` carries the missing-core
  regression test case (issue requirement 3 asked for one such case, not
  four, to avoid duplicating identical coverage) — the other three gates'
  suites do not yet have their own copy; tracked as an action item above.
- Full NLP/semantic verification of action-item or RCA quality remains
  explicitly out of scope (shape check only, per each gate's own
  disclaimer) — unchanged from issue #10, not a new gap.
