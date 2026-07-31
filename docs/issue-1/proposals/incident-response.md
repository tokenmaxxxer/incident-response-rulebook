# Issue #1 — Phase 1 proposal: incident-response methodology & artifact norms

Subject: issue-1. Proposal only — no plugin/hook files modified in this
phase. Phase 2 (directive/gate changes) is gated on human approval per
contract v3 s19 — see `docs/specs/approvers.md`. Grounded in
`docs/issue-1/reports/incident-response/current-state-survey.md` (this
repo's current gate/directive gaps) and `.../scout-brief.md` (domain
survey: NIST SP 800-61, Google SRE postmortem culture, PagerDuty
postmortem docs, RCA-method literature).

## (a) Proposal-norm — methodology and required sections for phase-1 documents

Adopt, for every future issue this role phase-1s:

1. **Methodology**: survey-then-scout-then-propose, in that order (the
   order already enforced by the scout-directive and used to produce this
   document) — current-state survey first (names this repo's actual
   write surfaces and gaps), then a domain sweep aimed at those gaps,
   then adoption decisions justified against both.
2. **Required sections**: (i) current-state survey — what this repo's
   directive/gate/agent already require and where they fall short; (ii)
   scout brief — domain must-bes with sources; (iii) proposal body with
   an explicit adopt/skip list and, for each adopted item, why it is a
   near-necessary consequence of this role's decision boundary ("장애 후
   무엇을 배웠고 재발을 무엇으로 막을 것인가"), not merely "the industry
   does X"; (iv) a plugin-reflection plan naming exact files, fields, and
   gate conditions to change in phase 2.
3. **Evidence form**: every adopted methodology element must trace to a
   named source in the scout brief; internal repo precedent (issue #2's
   proposal shape) may set document structure but not substitute for
   domain evidence on methodology content.

## (b) Artifact-norm — methodology and required components for phase-2 deliverables

Adopt the following for the phase-2 postmortem record
(`docs/issue-<n>/reports/incident-response.md`):

1. **Required sections, expanded from today's three to five**: summary
   (1-3 sentences: what/when/impact), impact (quantified: what broke, for
   whom, how long, and any SLO/error-budget effect if the subject has
   one), timeline (chronological, detection → mitigation → recovery),
   root cause analysis (see methodology below), action items (see schema
   below).
2. **RCA methodology**: root cause analysis must proceed from the
   timeline via a named technique — 5 Whys and/or causal-timeline
   analysis (the combination the scouted literature converges on) — and
   must distinguish a primary root cause from contributing factors. Free
   prose with no traceable "why" chain does not satisfy this.
3. **Action-item schema**: each action item must state owner (a person or
   team, not "TBD"), a verifiable verb + specific outcome (not "improve
   monitoring" but "add alert on X exceeding Y"), and a deadline. This
   replaces the current bare "owner+deadline" phrasing with an
   enforceable shape.
4. **Blamelessness constraint**: action items and root-cause text must
   describe system/process conditions, not name individuals as the
   cause — carried forward from this role's existing framing, made
   explicit here since it is otherwise only implicit in "blameless
   postmortem" as a section label.
5. **Explicitly out of scope for phase 2 (adopt-later, not adopt-now)**:
   severity-tiered document depth (SEV1 full / SEV2 abbreviated / SEV3
   summary-only) — this repo has no upstream severity-classification
   input yet, so gating on it now would be gating on an undefined
   signal. Record this as a documented hand-off gap, not a gate
   condition, until an upstream severity source exists.

## (c) Rationale for each adoption — why this is not arbitrary

- **Named RCA method (5 Whys / causal timeline), not free-text "root
  cause"**: the role's decision boundary is explicitly "무엇을 배웠고
  재발을 무엇으로 막을 것인가" — a lesson only counts as learned if the
  causal chain from symptom to root cause is traceable and falsifiable;
  un-derived prose under a "root cause" heading cannot support a
  falsifiable prevention action, so it fails the role's own boundary
  before it fails any external standard. The scout brief shows this is
  also the field's converged practice (NIST, RCA literature), which
  confirms rather than originates the requirement.
- **Action-item schema (owner+verb+outcome+deadline vs. owner+deadline)**:
  the role's `PRODUCES` already commits to "action items w/
  owner+deadline" — but an owner and a date attached to a vague verb
  ("improve X") is not independently checkable by anyone reading the
  record later, which defeats the record's purpose as a verifiable
  artifact per contract v3 s19/s20's phase-2-record-waits-for-approval
  discipline (the record must be checkable, not just present). Tightening
  the schema is the minimal change that makes the already-committed
  requirement actually enforceable.
- **Summary + impact as required sections (new, not currently gated)**:
  without a quantified impact statement, "what did this cost" — the
  first fact any reader of a postmortem needs to judge whether the
  response and prevention effort are proportionate — is absent. This is
  the one place the current gate is missing content the role's own stated
  purpose (learning from an incident) structurally requires: you cannot
  judge whether a prevention measure is proportionate without knowing
  what was lost.
- **Severity-tiering deferred, not adopted**: adopting a gate that
  branches on severity when no severity input exists in this repo would
  be building enforcement against an undefined signal — worse than no
  gate, since it would either silently no-op or block on an always-false
  condition. This is a scope decision grounded in this repo's actual
  current state (per the survey), not a rejection of the practice.
- **Blamelessness as explicit text, not new field**: already implicit in
  the existing `blameless-postmortem` field name; making the constraint
  textual guidance rather than a new gated field avoids inventing a
  mechanically-uncheckable gate (language tone is not machine-verifiable
  by a shell/regex gate) for something better enforced as documented
  norm + human review at PR merge time.

## (d) Plugin reflection plan — phase 2 targets

Naming the exact files and mechanisms phase 2 (post-approval) must
change; no changes made in this phase.

1. **`incident-response/hooks/directive.sh`**: extend `PRODUCES` from
   `"timeline, blameless postmortem, action items w/ owner+deadline"` to
   name the five sections and the action-item schema explicitly, e.g.
   `"summary, impact, timeline, root-cause-analysis (5-Whys/causal-chain),
   action items (owner+verb+outcome+deadline)"`. Exact string TBD in
   phase 2 to stay within whatever line-length/format convention core's
   `role-directive.sh` expects.
2. **`incident-response/hooks/record-fields.config.sh`**: change
   `RECORD_FIELDS_REQUIRED` from `"timeline,blameless-postmortem,action-
   items"` to `"summary,impact,timeline,root-cause-analysis,action-
   items"`. This is a field-presence change only — the shared gate (core
   issue #66) checks heading presence; it cannot mechanically verify RCA
   depth or action-item schema. Phase 2 must confirm whether core's
   shared gate supports any content-shape check beyond heading presence;
   if not, RCA-method and action-item-schema enforcement stay
   human/reviewer-checked at PR-merge time, not machine-gated — flag this
   explicitly in the phase-2 record rather than silently overclaiming
   gate coverage.
3. **`incident-response/agents/warrant-hunter.md`**: no change proposed —
   already a thin core-reference stub per issue #2's conversion; RCA-
   method and action-item-schema requirements belong in the directive/
   gate, not the hunt-agent config.
4. **README.md**: phase 2 executor updates the Layout/decides-block to
   reflect the expanded `produces` line, once directive.sh's text is
   finalized.
5. **Severity hand-off note**: add one line to `directive.sh`'s
   HAND-OFF or a new BOUNDARY-CASE line documenting that severity-tiered
   depth is deferred pending an upstream severity-classification source —
   not a gate, a documented limitation.

## Files touched by this proposal, if approved and executed (phase 2, not now)

- `incident-response/hooks/directive.sh` — expand `PRODUCES`, add
  boundary-case/hand-off note on deferred severity-tiering.
- `incident-response/hooks/record-fields.config.sh` — expand
  `RECORD_FIELDS_REQUIRED` to 5 fields.
- `README.md` — sync decides-block to match.
- `docs/issue-1/reports/incident-response.md` — phase-2 record, created by
  the phase-2 executor once directive/gate changes land, documenting the
  five-section postmortem produced under the new norm.

Nothing outside `docs/issue-1/reports/incident-response/` and
`docs/issue-1/proposals/` has been modified as part of this phase-1
deliverable.
