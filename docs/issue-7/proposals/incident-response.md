# Issue #7 — Phase 1 proposal: enforce issue-1's adopted methodology mechanically

Subject: issue-7. Proposal only — no plugin/hook/test files modified in
this phase. Phase 2 (all file changes below) is gated on human approval
per contract v3 s19 — see `docs/specs/approvers.md` (single-account
mode: an `APPROVE issue-7/incident-response` issue comment). Grounded in
`docs/issue-7/reports/incident-response/current-state-survey.md` (this
repo's actual gate/directive/test gaps) and `.../scout-brief.md`
(comparative reading of `pricing-rulebook`'s `methodology-gate.sh` and
`implementation-rulebook`'s `coding-progress-gate.sh`/`state.sh`).
Canon scripts referenced only, never copied, per
`docs/handbooks/canon-scripts.md`.

## 1. Directive 심화 (phase-specific, facet-level)

`incident-response/hooks/directive.sh` stays a role-directive stub
(source line + plain variable assignments + one `core_role_directive`
call — the structural cap `core/hooks/tests/stub-check.sh` enforces).
Depth moves into the four variable values, each kept as one physical
source line via `$'...\n...'` ANSI-C quoting so multi-line content still
satisfies stub-check's plain-assignment regex. Fix the argument-passing
defect the survey found (`core_role_directive` currently called with no
arguments) as a prerequisite — expanded text has no effect while that
call is broken.

Per-phase breakdown, each with steps / judgment criteria / prohibitions:

- **Phase 1 facet** (folded into `USE_WHEN`/a new phase-1 segment of
  `PRODUCES`): steps = current-state survey → scout brief → proposal
  with explicit adopt/skip + rationale tied to this role's decision
  boundary (issue-1 (a)). Judgment criterion = every adopted methodology
  element traces to a named source in the scout brief; internal
  precedent may set structure but never substitute for domain/comparative
  evidence on methodology content (issue-1 (a)(3)). Prohibition =
  proposing a gate/record-shape change with no antecedent survey+scout
  pair on disk (this is also mechanically gated — see §2).
- **Phase 2 facet** (folded into `PRODUCES`): steps = timeline
  reconstruction → named RCA method applied to that timeline (5 Whys
  and/or causal-chain, distinguishing primary cause from contributing
  factors) → action items in owner+verb+outcome+deadline form. Judgment
  criterion = an action item is enforceable only if its outcome is
  independently checkable by a reader who was not present at the
  incident. Prohibition = a "root cause" heading containing free prose
  with no traceable why-chain; an action item naming an individual as
  the cause (blamelessness — issue-1 (b)4, textual guidance, not
  gated, per issue-1 (c)'s reasoning that tone is not machine-checkable).
- Boundary-case line (already present, keep and reference explicitly):
  severity-tiered depth stays a documented hand-off gap, not a gate
  condition, until an upstream severity-classification source exists
  (issue-1 (b)5).

## 2. Methodology gate — `incident-response/hooks/incident-response-methodology-gate.sh` (new)

Modeled on `pricing-rulebook/pricing/hooks/methodology-gate.sh`'s shape
(canon-referenced structure, not copied text — role-specific content
throughout): fail-closed trap-at-top, `CLAUDE_PROJECT_DIR`-or-`git`
root resolution failing closed if neither resolves, own-write-surface
regex scoping (exits 0, no-op, for anything outside it), full
resulting-text reconstruction for Write/Edit/MultiEdit before scanning,
each missing element named individually in the denial with its source
norm cited, and a kill switch
(`INCIDENT_RESPONSE_METHODOLOGY_GATE_OFF=1`). Registered in
`hooks/hooks.json` as an additional `PreToolUse` matcher for
`Write|Edit|MultiEdit`, additive to (never replacing) core's generic
`record-fields-gate.sh` field-presence check.

Two write surfaces, two required-element sets (both traced to issue-1's
adopted norms):

- `docs/issue-<n>/proposals/incident-response*.md` (phase-1 proposal,
  issue-1 (a)(2)): requires (i) a reference to a current-state survey
  document, (ii) a reference to a scout brief (or an explicit stated
  skip-record per the scout-directive's two skip conditions), (iii) an
  explicit adopt/skip list, (iv) rationale language tying at least one
  adopted item back to this role's decision boundary text (not just
  "the field/industry does X").
- `docs/issue-<n>/reports/incident-response.md` (phase-2 record, issue-1
  (b)1-3): requires, beyond core's existing five-heading presence check,
  (i) an RCA-method name (5 whys / causal chain / causal-timeline —
  fishbone/fault-tree accepted too since the scout brief named them as
  field alternatives even though issue-1 adopted only the first two),
  (ii) a primary-vs-contributing-factor distinction in the RCA text
  (e.g. explicit "primary" / "contributing" labels — a lightweight
  lexical check, not a semantic one), (iii) at least one action item
  matching an owner+verb+outcome+deadline shape (regex-detectable:
  owner token, a deadline-shaped date/relative-date token, and a verb+
  outcome clause; this is a shape check, not a truth check — it cannot
  verify the outcome is actually specific, only that the four slots are
  populated).

Explicitly NOT gated (per issue-1 (c)'s own reasoning, carried forward
unchanged, not re-litigated here): blamelessness tone/language, and
severity-tiered depth (no upstream signal exists yet).

## 3. Order/state tracking — survey → scout → propose

A small addition to the same gate script (§2), not a separate mechanism:
before allowing a Write/Edit that creates or finalizes
`docs/issue-<n>/proposals/incident-response*.md`, check that
`docs/issue-<n>/reports/incident-response/current-state-survey.md` and
`.../scout-brief.md` (or a scout-directive-compliant skip record) already
exist under the same subject directory. This is deliberately much
smaller than `coding-progress-gate.sh`'s cross-role finding-resolution
state machine (scout-brief's judgment, adopted in §"Skip"): the
constraint here is intra-role, intra-phase file existence, not
cross-role record parsing, so a full state-file/loop_state mechanism
would be over-fitting the exemplar.

## 4. Gate tests

New repo-root `tests/` directory (this repo currently has none — survey
gap 4), mirroring `implementation-rulebook/tests/run-gate-tests.sh`'s
harness shape: synthetic PreToolUse JSON payloads piped into the gate
script, asserting exit code 0 (allow) or 2 (deny) per case. Minimum case
set: (a) phase-1 proposal missing each of the four required elements in
turn → deny, each naming the correct missing element; (b) phase-1
proposal with all four present → allow; (c) phase-1 proposal write
attempted with no survey/scout-brief on disk → deny (order gate); (d)
phase-2 record missing RCA-method name / primary-contributing
distinction / action-item shape, each in turn → deny; (e) phase-2
record with all elements present → allow; (f) a write outside both
regex-scoped surfaces → allow (no-op, not this gate's business); (g)
malformed JSON payload / unresolvable root → deny (fail-closed).

## 5. Agents / checklist

No new agent proposed. `warrant-hunter.md` stays a thin core-reference
stub — issue-1 (d)3 already reasoned that RCA-method and action-item-
schema requirements belong in the directive/gate, not the hunt-agent
config, and nothing in this issue's scope changes that boundary. The
"repeated procedure" issue #7 asks to route to agents/checklist when one
exists is, here, the RCA method itself (5 Whys / causal-chain) — that
procedure is already named as directive text (§1) and mechanically
required as a gate element (§2); a separate checklist file would
duplicate rather than add enforcement, so none is proposed.

## Files touched, if approved and executed (phase 2, not now)

- `incident-response/hooks/directive.sh` — fix the positional-argument
  call defect; expand the four variable values with phase-specific
  facet detail per §1.
- `incident-response/hooks/incident-response-methodology-gate.sh` (new)
  — §2/§3 gate logic.
- `incident-response/hooks/hooks.json` — register the new gate as a
  `PreToolUse` matcher for `Write|Edit|MultiEdit`; also resolve the
  existing dead `incident-response-progress-gate.sh` reference (survey
  gap 5) — either populate it with the same gate or remove the stale
  entry, decided in phase 2 once the gate's final filename is fixed.
- `tests/` (new directory) — gate-test harness per §4.
- `docs/issue-7/reports/incident-response.md` — phase-2 record, created
  by the phase-2 executor once the directive/gate changes land,
  documenting what was actually built against this proposal.

Nothing outside `docs/issue-7/reports/incident-response/` and
`docs/issue-7/proposals/` has been modified as part of this phase-1
deliverable.
