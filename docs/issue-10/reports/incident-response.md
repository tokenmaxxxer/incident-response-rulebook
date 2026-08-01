# Report — issue #10: gate A+ remediation (phase 2)

Proposal: docs/issue-10/proposals/incident-response.md
Approved by APPROVE issue-10/incident-response (single-account mode,
JiwonJung94, listed in docs/specs/approvers.md).

## What was done

All four A+ remediation items from the issue landed on this branch: (1)
migrated all four gates to source core's `gate-lib.sh`/`gate-lib.py` by
reference and fixed every audit defect the issue named; (2) upgraded the
four gates' semantic checks from bare substring/word-co-occurrence to
section/adjacency/structure-scoped checks; (3) added the six core-mandated
test-case groups plus a semantic regression case to each gate's own test
suite, self-checked, full suite green; (4) fixed the stale `WRITE_SCOPE`
ghost path in `directive.sh` and added a gate-lib migration note to each
gate README.

Why: closes the issue's B- audit findings (fail-open kill-switch, dead
code, meaningless owner/semantic checks, ghost write-scope) to A+ by
adopting the shared core standard instead of re-deriving fixes locally.

Upstream basis: the approved proposal
(docs/issue-10/proposals/incident-response.md), built on core issue #72's
landed `gate-lib.sh`/`gate-lib.py`/`compliance-check.sh`
(docs/handbooks/gate-house-standard.md).

## Summary

Phase-2 delivery for issue #10 (gate A+ remediation). All four incident-
response gates migrated to core's shared `gate-lib.sh`/`gate-lib.py`,
their semantic checks upgraded from substring matching to
section/adjacency-scoped structural checks, mandatory test coverage added
and green, and the stale `WRITE_SCOPE` ghost path corrected.

## Impact

Before this work, all four gates were independently vulnerable to: a
kill-switch typo silently disabling enforcement (fail-open), `Edit`
`replace_all`/mixed-`MultiEdit` writes bypassing content judgment, and
semantic checks passable by mere word co-occurrence regardless of
polarity or section (e.g. "we did NOT skip the scout step" counted as a
skip record). No incident occurred from these gaps in this repo; this is
a preventive remediation closing findings from the 2026-08-01 code audit
named in the issue.

## Timeline

- 2026-08-01: issue #10 filed with the audit findings (grade B-).
- 2026-08-01: phase-1 survey + proposal drafted, PR #11 opened and merged.
- 2026-08-01: APPROVE issue-10/incident-response posted by JiwonJung94.
- 2026-08-01: phase-2 remediation implemented (this record), full suite
  green, compliance-check.sh clean.

## Root-cause-analysis (5 Whys)

1. Why did the gates have fail-open kill switches and meaningless
   semantic checks? Because each gate independently hand-rolled its own
   trap/kill-switch/path/reconstruct logic instead of sharing one
   library.
2. Why was there no shared library at the time these gates were written?
   Because core's gate-house standard (issue #72) had not yet landed.
3. Why did the semantic checks stay at bare substring level? Because no
   structural/section-scoping idiom existed yet in this rulebook, and
   each gate's author independently picked the cheapest check that
   passed its own test fixtures.
4. Why did `action-item-gate.sh` carry dead code (`and False`)? An
   earlier edit left a disabled branch in place instead of removing it
   once `section_lines` extraction superseded it.
5. Why did `directive.sh`'s `WRITE_SCOPE` point at a path no gate reads?
   It was set once during initial scaffolding and never updated when the
   real write surfaces (`proposals/`, `reports/incident-response.md`)
   were finalized.

Primary cause: absence of a shared gate library and shared semantic-
scoping idiom at authoring time, so each gate independently reinvented
(and under-invented) the same shapes. Contributing factors: leftover dead
code from an earlier refactor, and a stale scaffolding value never
revisited.

## What shipped

All four gates (`incident-response-action-item-gate`,
`-proposal-evidence-gate`, `-proposal-order-gate`, `-rca-method-gate`)
migrated to source core's `gate-lib.sh`/`gate-lib.py` by reference
(`. "${CORE_HOOKS_LIB:?}/gate-lib.sh"`, mirroring `directive.sh`'s existing
pattern — no vendored copy in any gate script):

- `gate_trap_fail_closed` replaces each gate's hand-rolled `__fc` trap,
  called before `set -uo pipefail`.
- `gate_kill_switch_active` replaces each gate's hand-rolled
  `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac`. Behavior change:
  an unrecognized kill-switch value (e.g. a typo) now leaves the gate
  ACTIVE instead of silently disabling it — closes the fail-open bug the
  issue's audit found.
- `gate_lib.gate_parse_json_or_deny` / `gate_lib.gate_normalize_path` /
  `gate_lib.gate_reconstruct_write` (Python, loaded via `GATE_LIB_PY`)
  replace each gate's hand-rolled JSON-parse / path-resolve /
  `current.replace(o, n, 1)` logic. `replace_all: true` on `Edit` and
  mixed `replace_all` across `MultiEdit` now reconstruct correctly
  (`order-gate.sh` never reconstructed write content and correctly does
  not call `gate_reconstruct_write` — documented in its README as
  intentional).
- `gate_bash_write_targets` scanning added to all four gates: a
  `Bash`-tool file write reaching a gate's write surface is now judged
  the same as an equivalent `Write` call (path-scope matching only;
  content reconstruction for `Bash` writes stays out of scope, matching
  each gate's existing file_path/notebook_path-only content judgment).

Audit defects from the issue, all fixed:

- (a) `action-item-gate.sh` owner check: `OWNER_RE` now requires the
  capitalized-word form to sit immediately before a colon/dash at the
  start of the action-item line; a mid-sentence capitalized word no
  longer qualifies as an owner.
- (b) the dead `and False` branch in `action-item-gate.sh`'s shape loop
  is deleted (not repaired — `section_lines` already does the real job).
- (c) semantic checks upgraded from bare substring/word-co-occurrence to
  section/adjacency/structure-scoped checks in all four gates:
  `order-gate.sh`'s scout-skip heuristic (section-scoped or bounded
  ~15-token window, negation-aware — "we did NOT skip the scout step" no
  longer counts), `evidence-gate.sh`'s adopt/skip list and scout-skip-
  stated elements (heading/section-scoped adopt-tagged + skip-tagged
  items), `evidence-gate.sh`'s decision-boundary rationale element
  (co-occurrence within the same section/paragraph), and
  `rca-method-gate.sh`'s primary/contributing distinction (same
  paragraph/section, not anywhere-in-document).
- (d) `incident-response/hooks/directive.sh`'s `WRITE_SCOPE` corrected
  from the ghost `docs/issue-<n>/postmortems/**` to the two real write
  surfaces: `docs/issue-<n>/proposals/incident-response*.md` and
  `docs/issue-<n>/reports/incident-response.md`.

## Mandatory test cases (requirement 3)

Each gate's own test suite adds the six core-mandated groups (`Edit`
`replace_all`, mixed-`replace_all` `MultiEdit`, malformed JSON x3,
kill-switch-unrecognized-value-stays-active, absolute + `./`-relative
path, `Bash`-tool write parity) plus its own semantic-fix regression
case, each with a self-check counter that fails the suite if any required
group didn't run.

## Delivery-gate evidence

Full suite, all four gates, run 2026-08-01:

```
incident-response-action-item-gate:        15 passed, 0 failed (7/7 groups)
incident-response-proposal-evidence-gate:   19 passed, 0 failed (8/8 groups)
incident-response-proposal-order-gate:      20 passed, 0 failed (7/7 groups)
incident-response-rca-method-gate:          16 passed, 0 failed
```

`compliance-check.sh` (core canon, invoked not vendored, per
`docs/handbooks/gate-house-standard.md`'s migration checklist), run
against each gate's own `hooks/` directory:

```
compliance-check: ok — incident-response-action-item-gate/hooks/action-item-gate.sh
compliance-check: ok — incident-response-proposal-evidence-gate/hooks/evidence-gate.sh
compliance-check: ok — incident-response-proposal-order-gate/hooks/order-gate.sh
compliance-check: ok — incident-response-rca-method-gate/hooks/rca-method-gate.sh
```

All clean — no gate reads a `*_OFF` kill switch without calling
`gate_kill_switch_active`, and no gate reconstructs `Edit`/`MultiEdit`
content via its own `.replace(...)` call instead of
`gate_lib.gate_reconstruct_write`.

## README fixes (requirement 4)

Each of the four gate READMEs now documents the gate-lib.sh migration and
the corrected kill-switch polarity (unrecognized value stays ACTIVE; only
a recognized on-spelling `1`/`true`/`yes`/`on` disables). No ghost-file
references were found in the four gate READMEs themselves (survey
confirmed); only `directive.sh`'s centralized `WRITE_SCOPE` was stale,
fixed above.

## Adopt / skip (unchanged from proposal)

Adopted: `gate-lib.sh`/`gate-lib.py` by reference in all four gates;
`compliance-check.sh` as an invoked acceptance check; the six-case
mandatory test pattern per gate. Skipped: re-implementing any `gate_*`
function locally; full NLP/semantic verification of action-item or RCA
quality; a fifth gate for blamelessness/tone.

## Action Items

- Jiwon Jung: re-run this repo's four gate suites within 3 days of any future core gate-lib.sh release.
- Jiwon Jung: replace the sandbox CORE_HOOKS_LIB fallback in all four test files with the confirmed CI path by 2026-08-15.

## loop_state

loop_state: landed

Phase-2 delivery complete, full suite green, compliance-check clean,
ready for PR review.

## Open Findings

- `CORE_HOOKS_LIB`'s real value in CI/production (a sibling core
  checkout path) was not confirmed during this session; test files use a
  sandbox-local fallback path documented inline, matching the
  uncertainty `directive.sh` already flagged for the same variable.
- Full NLP/semantic verification of action-item or RCA quality remains
  explicitly out of scope (shape check only, per each gate's own
  disclaimer) — unchanged from before this remediation, not a new gap.
