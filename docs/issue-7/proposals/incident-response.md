# Issue #7 — Phase 1 proposal: enforce issue-1's adopted methodology mechanically

Subject: issue-7. Proposal only — no plugin/hook/test/marketplace.json
files created or modified in this phase. Phase 2 (all file changes
below) is gated on human approval per contract v3 s19 — see
`docs/specs/approvers.md` (single-account mode: an `APPROVE
issue-7/incident-response` issue comment). Grounded in
`docs/issue-7/reports/incident-response/current-state-survey.md` (this
repo's actual gate/directive/test gaps) and `.../scout-brief.md`
(comparative reading of `pricing-rulebook`'s `methodology-gate.sh` and
`implementation-rulebook`'s `coding-progress-gate.sh`/`state.sh`).
Canon scripts referenced only, never copied, per
`docs/handbooks/canon-scripts.md`.

## Required-change response

An approver reviewing the prior draft of this proposal required a
structural correction (verbatim, binding on this rewrite): rather than
deepening a single gate/directive bolted onto the existing
`incident-response` plugin, the adopted methodologies from issue-1 must
be systematized as a **plugin set** — each adopted methodology as an
independent, self-contained plugin (modeled on core's `freelunch`/
`scout` — a rulebook may carry several plugins, each at
freelunch-level completeness), with the phase-1 proposal norm and the
phase-2 record norm each realized as a **combination** of plugins
rather than one plugin apiece. This rewrite replaces the previous
single-gate-script design entirely with that plugin-set design. §6 is
the required plugin manifest.

## 1. Methodology decomposition

Issue-1's adopted methodology, as surveyed and scouted above, is not
one thing — it is four independently statable methodologies, each with
its own write surface, required shape, and (where applicable) order
constraint:

1. **Phase-1 proposal discipline**: survey → scout → propose, with an
   explicit adopt/skip list and rationale tied to this role's decision
   boundary (issue-1 (a)).
2. **Phase-1 evidence-sourcing discipline**: every adopted methodology
   element must trace to a named source in the scout brief; internal
   precedent may set structure but never substitute for domain/
   comparative evidence on methodology content (issue-1 (a)(3)).
3. **Phase-2 RCA discipline**: a named RCA method (5 Whys and/or
   causal-chain) applied to a reconstructed timeline, with an explicit
   primary-cause vs. contributing-factor distinction (issue-1 (b)1-3).
4. **Phase-2 action-item discipline**: action items in owner+verb+
   outcome+deadline form, independently checkable by a reader who was
   not present at the incident (issue-1 (b)1-3).

Each is proposed below as its own plugin (§2-§5), not as one script
with four `if` branches. `incident-response/hooks/directive.sh` stays a
role-directive stub (source line + plain variable assignments + one
`core_role_directive` call — the structural cap
`core/hooks/tests/stub-check.sh` enforces); each plugin's directive
fragment is content that flows into this role's directive values, not
new control flow in `directive.sh` itself. The pre-existing
argument-passing defect the survey found (`core_role_directive`
currently called with no positional arguments) is a prerequisite fix
shared by all four plugins — expanded directive text has no effect
while that call is broken — and is proposed once, in
`incident-response/hooks/directive.sh` itself, not duplicated per
plugin.

## 2. Plugin: `incident-response-proposal-order-gate`

**Owns**: the survey → scout → propose *order* constraint (methodology
1 above), independent of proposal *content* shape.

- **Directive fragment**: a `USE_WHEN`/`PRODUCES` clause stating the
  required step order for phase-1 documents, contributed as one
  `$'...\n...'` ANSI-C-quoted line into `incident-response/hooks/
  directive.sh`'s existing variable assignments (per the stub-check
  constraint — no new shell logic in `directive.sh`).
- **Gate script**: `hooks/order-gate.sh` — fail-closed trap-at-top,
  `CLAUDE_PROJECT_DIR`-or-`git`-root resolution failing closed if
  neither resolves, own-write-surface regex scoped to
  `docs/issue-<n>/proposals/incident-response*.md` (exits 0, no-op, for
  anything else). Before allowing a Write/Edit/MultiEdit that
  creates/finalizes that path, checks that
  `docs/issue-<n>/reports/incident-response/current-state-survey.md`
  and `.../scout-brief.md` (or a scout-directive-compliant skip record)
  already exist under the same subject directory. Deliberately much
  smaller than `coding-progress-gate.sh`'s cross-role
  finding-resolution state machine (scout-brief's judgment, adopted
  above): this is intra-role, intra-phase file-existence, not
  cross-role record parsing, so a full state-file/loop_state mechanism
  would over-fit the exemplar. Kill switch:
  `INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF=1`.
- **Test file**: `tests/order-gate.test.sh` — synthetic PreToolUse JSON
  payloads: (a) proposal write with no survey/scout-brief on disk →
  deny; (b) proposal write with both present → allow; (c) write
  outside the regex-scoped surface → allow (no-op); (d) malformed
  JSON/unresolvable root → deny (fail-closed).
- **Agent**: none — this is a pure ordering constraint, no judgment
  call for an agent to make.

## 3. Plugin: `incident-response-proposal-evidence-gate`

**Owns**: the proposal *content*-shape constraint (methodologies 1's
adopt/skip list and 2's evidence-sourcing requirement), independent of
ordering.

- **Directive fragment**: a `PRODUCES` clause naming the four required
  proposal elements below, contributed as its own
  `$'...\n...'`-quoted line into `directive.sh`.
- **Gate script**: `hooks/evidence-gate.sh` — same fail-closed/root-
  resolution/own-write-surface-regex/full-resulting-text-reconstruction
  shape as §2's gate (both modeled on
  `pricing-rulebook/pricing/hooks/methodology-gate.sh`'s converged
  shape per the scout brief), scoped to the same
  `docs/issue-<n>/proposals/incident-response*.md` surface but checking
  *content*, not file-existence order: (i) a reference to a
  current-state survey document, (ii) a reference to a scout brief (or
  an explicit stated skip-record per the scout-directive's two skip
  conditions), (iii) an explicit adopt/skip list, (iv) rationale
  language tying at least one adopted item back to this role's decision
  boundary text (not just "the field/industry does X"). Each missing
  element named individually in the denial with its source norm cited.
  Kill switch: `INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF=1`.
- **Test file**: `tests/evidence-gate.test.sh` — proposal missing each
  of the four required elements in turn → deny, each naming the correct
  missing element; proposal with all four present → allow; write
  outside the regex-scoped surface → allow (no-op); malformed
  JSON/unresolvable root → deny.
- **Agent**: none, same reasoning as §2 — this is a mechanical
  presence/reference check, not a judgment task.

**Composition note**: §2 and §3 together realize the full phase-1
proposal norm — §2 answers "was this written in the right order," §3
answers "does it say the right things." Neither alone is issue-1 (a)'s
adopted norm; both register as separate `PreToolUse` matchers on the
same write surface, additive to each other and to core's generic
`record-fields-gate.sh`.

## 4. Plugin: `incident-response-rca-method-gate`

**Owns**: methodology 3 — the phase-2 RCA-method-with-primary/
contributing-distinction requirement, independent of action-item shape.

- **Directive fragment**: a `PRODUCES` clause naming the required RCA
  method vocabulary and the primary/contributing distinction,
  contributed as its own `$'...\n...'`-quoted line into `directive.sh`.
- **Gate script**: `hooks/rca-method-gate.sh` — same converged
  fail-closed/root-resolution/regex-scoped/full-reconstruction shape,
  scoped to `docs/issue-<n>/reports/incident-response.md`, additive to
  core's existing five-heading presence check
  (`record-fields.config.sh`/`record-fields-gate.sh`). Checks (i) an
  RCA-method name is present (5 whys / causal chain / causal-timeline —
  fishbone/fault-tree accepted too since the scout brief named them as
  field alternatives even though issue-1 adopted only the first two),
  (ii) a primary-vs-contributing-factor distinction in the RCA text
  (e.g. explicit "primary"/"contributing" labels — a lightweight
  lexical check, not a semantic one). Explicitly NOT gated (per issue-1
  (c)'s own reasoning, carried forward unchanged, not re-litigated
  here): blamelessness tone/language — "a 'root cause' heading
  containing free prose with no traceable why-chain" is denied, but
  tone/blame language is not (issue-1 (b)4, textual guidance only,
  not machine-checkable). Kill switch:
  `INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF=1`.
- **Test file**: `tests/rca-method-gate.test.sh` — record missing
  RCA-method name → deny; record missing primary/contributing
  distinction → deny; record with both present → allow; write outside
  the regex-scoped surface → allow (no-op); malformed JSON/unresolvable
  root → deny.
- **Agent**: none. `warrant-hunter.md` stays a thin core-reference
  stub — issue-1 (d)3 already reasoned that RCA-method and
  action-item-schema requirements belong in the directive/gate, not the
  hunt-agent config, and nothing in this issue's scope changes that
  boundary.

## 5. Plugin: `incident-response-action-item-gate`

**Owns**: methodology 4 — the phase-2 action-item owner+verb+outcome+
deadline shape requirement, independent of RCA method.

- **Directive fragment**: a `PRODUCES` clause naming the required
  four-slot action-item shape, contributed as its own
  `$'...\n...'`-quoted line into `directive.sh`.
- **Gate script**: `hooks/action-item-gate.sh` — same converged shape,
  scoped to the same `docs/issue-<n>/reports/incident-response.md`
  surface, additive to core's five-heading presence check and to §4's
  gate (both register as separate `PreToolUse` matchers on the same
  file). Checks at least one action item matches an owner+verb+
  outcome+deadline shape (regex-detectable: owner token, a
  deadline-shaped date/relative-date token, and a verb+outcome clause —
  a shape check, not a truth check: it cannot verify the outcome is
  actually specific, only that the four slots are populated). Kill
  switch: `INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF=1`.
- **Test file**: `tests/action-item-gate.test.sh` — record with no
  action item matching the four-slot shape → deny; record with at
  least one matching → allow; write outside the regex-scoped surface →
  allow (no-op); malformed JSON/unresolvable root → deny.
- **Agent**: none, same reasoning as §4.

**Composition note**: §4 and §5 together realize the full phase-2
record norm — §4 answers "was a real RCA method applied," §5 answers
"are the action items enforceable." Neither alone is issue-1 (b)1-3's
adopted norm; both register as separate `PreToolUse` matchers on the
same write surface, additive to each other and to core's generic
`record-fields-gate.sh`. Severity-tiered depth (issue-1 (b)5) stays a
documented hand-off gap, not a gate condition in either plugin, until an
upstream severity-classification source exists.

## 6. Plugin manifest (required)

| Plugin | Methodology owned | Components | Composes with |
|---|---|---|---|
| `incident-response-proposal-order-gate` | Phase-1 survey→scout→propose order (issue-1 (a)(1)) | directive fragment; `hooks/order-gate.sh`; `tests/order-gate.test.sh` | + `incident-response-proposal-evidence-gate` = full phase-1 proposal norm |
| `incident-response-proposal-evidence-gate` | Phase-1 evidence-sourcing + adopt/skip content (issue-1 (a)(2)-(3)) | directive fragment; `hooks/evidence-gate.sh`; `tests/evidence-gate.test.sh` | + `incident-response-proposal-order-gate` = full phase-1 proposal norm |
| `incident-response-rca-method-gate` | Phase-2 RCA method + primary/contributing distinction (issue-1 (b)1-3) | directive fragment; `hooks/rca-method-gate.sh`; `tests/rca-method-gate.test.sh` | + `incident-response-action-item-gate` = full phase-2 record norm |
| `incident-response-action-item-gate` | Phase-2 action-item owner+verb+outcome+deadline shape (issue-1 (b)1-3) | directive fragment; `hooks/action-item-gate.sh`; `tests/action-item-gate.test.sh` | + `incident-response-rca-method-gate` = full phase-2 record norm |

Shared, cross-plugin prerequisite (not itself a new plugin): the
`directive.sh` positional-argument fix in `incident-response/hooks/
directive.sh` — without it, none of the four plugins' directive
fragments have any user-visible effect, since `core_role_directive` is
currently called with no arguments (survey gap 1).

Existing `incident-response` plugin: unchanged in shape — still owns
`directive.sh` (stub, argument-passing fix applied), `record-fields.
config.sh` (core's generic field-presence delegation, untouched), and
`warrant-hunter.md` (unchanged stub). The four new plugins above are
additive registrations alongside it, not a merge into it — each is
independently versionable, independently testable, and independently
disable-able via its own kill switch, matching `freelunch`/`scout`'s
model of several focused plugins per rulebook rather than one
do-everything plugin.

`.claude-plugin/marketplace.json` registration plan (described only,
not executed in this phase): add four new plugin entries —
`incident-response-proposal-order-gate`,
`incident-response-proposal-evidence-gate`,
`incident-response-rca-method-gate`, and
`incident-response-action-item-gate` — each with its own `name`,
`source` (its own subdirectory, sibling to the existing
`incident-response/` plugin directory), and `description` naming the
single methodology it owns, alongside the existing `incident-response`
marketplace entry (left as-is apart from the `directive.sh` fix
described above, which is a file-content change inside that same
existing entry, not a new registration).

## 7. Gate tests — repo-wide harness

New repo-root `tests/` directory (this repo currently has none — survey
gap 4), mirroring `implementation-rulebook/tests/run-gate-tests.sh`'s
harness shape: a single runner that invokes each plugin's own test file
(§2-§5) in turn, piping synthetic PreToolUse JSON payloads into each
gate script and asserting exit code 0 (allow) or 2 (deny) per case. The
per-plugin test files are each plugin's own component (self-contained,
independently runnable); the repo-root runner is thin orchestration
over them, not a fifth place where test logic lives.

## Files touched, if approved and executed (phase 2, not now)

- `incident-response/hooks/directive.sh` — fix the positional-argument
  call defect (shared prerequisite for all four plugins).
- `incident-response-proposal-order-gate/hooks/order-gate.sh` (new
  plugin directory) — §2 gate logic.
- `incident-response-proposal-order-gate/tests/order-gate.test.sh` (new)
  — §2 tests.
- `incident-response-proposal-evidence-gate/hooks/evidence-gate.sh`
  (new plugin directory) — §3 gate logic.
- `incident-response-proposal-evidence-gate/tests/evidence-gate.test.sh`
  (new) — §3 tests.
- `incident-response-rca-method-gate/hooks/rca-method-gate.sh` (new
  plugin directory) — §4 gate logic.
- `incident-response-rca-method-gate/tests/rca-method-gate.test.sh`
  (new) — §4 tests.
- `incident-response-action-item-gate/hooks/action-item-gate.sh` (new
  plugin directory) — §5 gate logic.
- `incident-response-action-item-gate/tests/action-item-gate.test.sh`
  (new) — §5 tests.
- Each new plugin's `hooks/hooks.json` — registers its own gate script
  as a `PreToolUse` matcher for `Write|Edit|MultiEdit` on its owned
  write surface, additive to (never replacing) core's generic
  `record-fields-gate.sh` field-presence check; also resolves the
  existing dead `incident-response-progress-gate.sh` reference in the
  existing `incident-response/hooks/hooks.json` (survey gap 5) — either
  populate it with one of the new gates or remove the stale entry,
  decided in phase 2 once the plugin split above is finalized.
- `.claude-plugin/marketplace.json` — four new plugin entries per §6.
- `tests/run-gate-tests.sh` (new repo-root harness) — §7 orchestration
  over each plugin's own test file.
- `docs/issue-7/reports/incident-response.md` — phase-2 record,
  created by the phase-2 executor once the plugin changes land,
  documenting what was actually built against this proposal.

Nothing outside `docs/issue-7/reports/incident-response/` and
`docs/issue-7/proposals/` has been modified as part of this phase-1
deliverable.
