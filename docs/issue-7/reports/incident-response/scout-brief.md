# Issue #7 — scout brief

Mode: direct comparative reading of sibling rulebooks' hook machinery in
this environment's local checkouts (`tokenmaxxxer-core`,
`pricing-rulebook`, `implementation-rulebook`) — not web search. This
deliverable's "field" is this plugin system's own enforcement
architecture, so the comparable exemplars are sibling rulebooks that
already implemented a mechanical methodology gate, not external domain
literature (the domain literature — NIST/Google SRE/PagerDuty — was
already scouted and adopted in issue-1; this brief scouts *how to
enforce* what issue-1 already adopted, which is a different question).
1 stage (direct reads, no fan-out needed — 3 target files, already
enumerated from the current-state survey's gap list), stopped at judge
point 1: the three exemplars converged on one shape and no fourth
exemplar was available in this environment to check against.

## Category must-bes (converged across the two implemented gate exemplars)

- Fail-closed trap-at-top (`trap __fc EXIT` remapping any non-0/non-2
  exit to 2) so an internal script error cannot silently become an
  allow [pricing-methodology-gate, coding-progress-gate].
- Root resolution handles both `CLAUDE_PROJECT_DIR` and a `git
  rev-parse` fallback, and denies (fails closed) if neither resolves
  [pricing-methodology-gate, coding-progress-gate].
- The gate restricts itself to its own role's write surfaces via an
  explicit path regex and exits 0 (no-op) for anything else — it never
  tries to be a general-purpose doc linter [pricing-methodology-gate].
- For Write/Edit/MultiEdit, the gate reconstructs the *resulting* text
  (not just the diff fragment) before scanning, so an Edit that only
  touches one paragraph still gets judged against the whole document
  [pricing-methodology-gate].
- Missing elements are named individually in the denial message, each
  traceable to the adopted-norm document that requires it — never a
  bare "invalid format" [pricing-methodology-gate].
- A kill switch env var exists per gate
  (`<ROLE>_METHODOLOGY_GATE_OFF`), consistent with the kill-switch
  convention core's role-directive stub already uses per role
  [pricing-methodology-gate, core/hooks/lib/role-directive.sh].
- Order/state enforcement is done by reading a *different* record file's
  structured markers (severity/addressed_to/loop_state) and requiring a
  provable resolution (a committed sha reference), never a narrated
  claim [coding-progress-gate].
- `directive.sh` itself is structurally capped to source-line +
  plain-variable-assignment + one library call; all role-specific depth
  must live inside the variable values, never as new control flow
  [core/hooks/tests/stub-check.sh].

## Performance axes this gate should compete on

1. Specificity of denial (names the missing element + the norm it comes
   from) vs. a generic "required fields missing".
2. Fail-closed coverage (unreadable file, unparseable payload, no root)
   vs. gates that silently allow on any of those.
3. Minimal footprint for the actual constraint needed — the
   survey→scout→adopt order constraint here is same-role/same-phase file
   existence, much simpler than coding-progress-gate's cross-role
   finding-resolution state machine; building the latter's full weight
   for this constraint would be over-fitting the exemplar rather than
   matching this role's actual need.

## Adopt / skip

- **Adopt**: fail-closed trap-at-top + root resolution + own-write-surface
  regex + full-resulting-text reconstruction pattern from
  `methodology-gate.sh`, applied to both this role's phase-1 proposal
  surface and phase-2 record surface (two required-element sets, not
  one).
- **Adopt**: order enforcement via file-existence check (survey and
  scout-brief files exist on disk before the proposal file may be
  written/finalized) — a minimal analogue of coding-progress-gate's
  state check, sized to this role's actual constraint (no cross-role
  record parsing needed, since survey→scout→adopt is entirely
  intra-role, intra-phase).
- **Adopt**: fix the `directive.sh` positional-argument defect found in
  the survey as a phase-2 prerequisite — a "directive 심화" that doesn't
  fix this is enforcing nothing.
- **Skip**: coding-progress-gate's full cross-record finding-resolution
  machinery (sha-referenced `resolved_findings` blocks) — no analogous
  cross-role blocking-finding relationship exists for this role's
  phase-1→phase-2 gap; that gap is already the standing human-approval
  gate (contract v3 s19), not something this issue should duplicate as a
  second mechanism.
- **Skip**: building a repo-local copy of core's `stub-check.sh`/
  `record-fields-gate.sh` — canon-referenced only, per
  `docs/handbooks/canon-scripts.md`; this role's new gate is *additive*
  (role-specific content-shape checks) on top of, never instead of,
  core's generic field-presence gate.

## Segment fit

This role is a single-agent async rulebook producing two document types
(proposal, record) under one repo-local approval gate — closer to
pricing-rulebook's shape (one role, one methodology-gate script, two
write surfaces) than to implementation-rulebook's (multiple sibling
plugins, cross-role finding resolution). Adapt pricing's shape as the
primary template; borrow only the file-existence idea from
implementation-rulebook's state pattern, not its full weight.

## Gap line

Already covered (by core's generic gate): field/heading presence for
the five phase-2 record sections. Missing against the surveyed
exemplars: role-specific content-shape checks (RCA method named,
action-item schema, phase-1 proposal-norm compliance), a fail-closed
write-surface-scoped gate script, order/state enforcement for
survey→scout→adopt, a gate-test harness, and a fixed `directive.sh`
call site.

## Sources

- /home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh
- /home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-61-implementation/coding/hooks/coding-progress-gate.sh
- /home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-61-implementation/coding/hooks/state.sh
- /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/lib/role-directive.sh
- /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh
- /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/docs/handbooks/canon-scripts.md
