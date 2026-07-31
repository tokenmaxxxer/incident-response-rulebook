# Issue #7 — Phase 2 record: methodology-enforcement plugin set built

Subject: issue-7. Phase 2, executed on approver `APPROVE issue-7/incident-response`
(issue comment, single-account mode, contract v3 s19). Built exactly the
plugin set frozen in `docs/issue-7/proposals/incident-response.md` §2-§7;
no design deviation.

## Summary

Issue-1's adopted phase-1 (proposal discipline, evidence-sourcing) and
phase-2 (RCA method, action-item shape) methodologies previously existed
only as directive text and a heading-presence check. This phase builds
four independent, self-contained plugins — one per methodology — that
mechanically gate the corresponding write surface, plus the shared
`directive.sh` positional-argument fix and a repo-root gate-test harness.

## Impact

Before: `docs/issue-<n>/proposals/incident-response*.md` had no gate at
all; `docs/issue-<n>/reports/incident-response.md` was checked for
heading presence only (not RCA-method naming or action-item shape); the
role directive printed no role-specific text due to a broken function
call; `hooks.json` pointed at a nonexistent progress-gate script; no
`tests/` directory existed in this repo. After: four `PreToolUse` gates
registered (fail-closed, own-write-surface-scoped, kill-switch-able),
`directive.sh`'s call fixed and its `PRODUCES` value expanded with
phase-1/phase-2 facet text, the dead `hooks.json` entry removed, and
`tests/run-gate-tests.sh` exercising all four plugins' own test suites
(20/20 cases passing).

## Timeline

- 2026-07-31 13:11 — Phase-1 proposal (survey→scout→propose order,
  content shape) merged as PR #8, per approver's structural-correction
  comment requiring a plugin-*set* rather than one deepened gate.
- 2026-07-31 (same day) — `APPROVE issue-7/incident-response` posted,
  opening phase 2.
- 2026-07-31 (same day) — four plugins built in parallel (independent
  write-surfaces, frozen contract from the proposal), each with its own
  gate script + test file + `plugin.json` + `hooks.json` + README + kill
  switch; `directive.sh` fix, `marketplace.json` registration, and the
  repo-root test harness done centrally to avoid write collisions on
  shared files; `hooks.json`'s dead progress-gate pointer removed.

## What was done

Built the four-plugin set described below (order-gate, evidence-gate,
rca-method-gate, action-item-gate), fixed `directive.sh`'s
positional-argument call, removed the dead `hooks.json` progress-gate
entry, registered all four plugins in `marketplace.json`, and added
`tests/run-gate-tests.sh` running all 20 of their combined test cases
green.

## Why

Issue #7 asked for the adopted methodology to be enforced mechanically,
not just documented; the approver's phase-1 correction required a
plugin-*set* (one methodology per plugin) over one deepened gate, so
that each methodology stays independently testable, versionable, and
disable-able.

## Upstream basis

`docs/issue-7/proposals/incident-response.md` §2-§7 (approved), grounded
in `docs/issue-7/reports/incident-response/current-state-survey.md` and
`.../scout-brief.md`'s reading of `pricing-rulebook`'s
`methodology-gate.sh` and `implementation-rulebook`'s
`coding-progress-gate.sh`/`state.sh`.

## Root-cause-analysis (5 Whys)

- Why did issue-1's adopted methodology have no enforcement? Because it
  was captured as directive prose and one generic field-presence check,
  with no role-specific content-shape or ordering gate ever built.
- Why was there no content-shape gate? Because the prior maturation
  (issue-1 phase 2) scoped itself to directive text and field presence,
  treating gate-building as a separate, not-yet-scheduled issue.
- Why was `directive.sh`'s role-specific text inert? Because
  `core_role_directive` is called with no positional arguments, so the
  four variables it reads never reach the function — a copy/adapt defect
  from the stub template, not something this issue introduced.
- Why did that defect go unnoticed until this survey? Because the
  directive prints via a `SessionStart` hook whose output is easy to
  skim past, and nothing asserted on its actual printed content.
- **Primary cause**: no phase of this role's prior maturation work
  included building or testing the mechanical gates its own adopted
  proposal norm called for — the norm was written down but never wired
  to a `PreToolUse` hook. **Contributing factor**: the `directive.sh`
  argument-passing defect, which meant even the directive-text half of
  enforcement (the cheaper half) wasn't actually working either.

## Action items

- Jiwon Jung: confirm the four new plugin marketplace entries resolve
  correctly on a real `claude plugin marketplace add` install (this
  session could not exercise a live install) by 2026-08-07.
- Jiwon Jung: decide, once core issue #66's config-discovery interface
  for `record-fields.config.sh` lands, whether `RECORD_FIELDS_REQUIRED`
  needs an explicit fifth field for the new RCA-method/action-item-shape
  checks or stays as pure heading-presence, by 2026-08-15.

## Files changed

- `incident-response/hooks/directive.sh` — fixed the positional-argument
  call defect; `PRODUCES` expanded with phase-1/phase-2 facet text.
- `incident-response/hooks/hooks.json` — removed the dead
  `incident-response-progress-gate.sh` `PreToolUse`/`Bash` entry (no such
  script ever existed in this repo).
- `incident-response-proposal-order-gate/` (new plugin) — survey→scout→
  propose order gate, tests, README.
- `incident-response-proposal-evidence-gate/` (new plugin) — phase-1
  proposal content-shape gate, tests, README.
- `incident-response-rca-method-gate/` (new plugin) — phase-2 RCA-method
  + primary/contributing gate, tests, README.
- `incident-response-action-item-gate/` (new plugin) — phase-2
  action-item owner+verb+outcome+deadline shape gate, tests, README.
- `.claude-plugin/marketplace.json` — four new plugin entries registered.
- `tests/run-gate-tests.sh` (new repo-root harness) — runs all four
  plugins' own test files; 20/20 passing at commit time.

Canon scripts (`core/hooks/lib/role-directive.sh`,
`core/hooks/tests/stub-check.sh`, `pricing-rulebook`'s
`methodology-gate.sh`, `implementation-rulebook`'s
`coding-progress-gate.sh`) were read for shape only and are not vendored
into this repo, per `docs/handbooks/canon-scripts.md`.

loop_state: landed

## Open findings

None.
