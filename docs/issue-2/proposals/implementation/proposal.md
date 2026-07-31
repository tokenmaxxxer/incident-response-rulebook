# Issue #2 — Phase 1 proposal: core-canon reference conversion

Subject: issue-2

This is a proposal only. No execution/refactor has been performed. Phase 2
(actual file changes) is gated on human approval per contract v3 s19 — see
`docs/specs/approvers.md`. This proposal responds point-by-point to the 5
work items in the issue body, referencing the findings in
`docs/issue-2/reports/implementation/survey.md`.

## Work item 1 — remove the warrant-hunter copy, replace with core reference

**File:** `incident-response/agents/warrant-hunter.md`

Proposed conversion: replace the file's body (the "Mandate" and generic
stance-rotation explanation, currently duplicated from
implementation-rulebook) with a short stub that:
- Points to core's `warrant/` plugin (core issue #63) as the actual
  hunt-agent implementation, instead of re-describing rotating-stance
  mechanics locally.
- Preserves, as role-specific configuration/content, only:
  - This role's own decision boundary quoted verbatim: "장애 후 무엇을
    배웠고 재발을 무엇으로 막을 것인가"
  - The hand-off scope: "용량 부족이 원인이면 → capacity-planning; 계측
    부재가 원인이면 → observability"

Example target shape (illustrative, not to be applied in this phase):

```markdown
# incident-response warrant-hunter

Hunt-agent implementation: see core `warrant/` plugin (core issue #63,
size-proportional budget + miss-streak + instrumentation). This file only
supplies role-specific configuration.

## Role boundary (role-specific — preserve)

> 장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가

## Hand-off (role-specific — preserve)

용량 부족이 원인이면 → capacity-planning; 계측 부재가 원인이면 →
observability
```

Whether this becomes a config file consumed by core's plugin, or stays a
markdown stub that a human/agent reads before invoking core's hunter, is an
execution-time decision for phase 2 — flagging both shapes as options
rather than picking one now, since the concrete core `warrant/` plugin
interface was not available to inspect in this repo.

## Work item 2 — remove trailer/record-fields/handbook-trigger gate copies and their hook registrations

**Files:** `incident-response/hooks/trailer-gate.sh`,
`incident-response/hooks/handbook-trigger-gate.sh`,
`incident-response/hooks/record-fields-gate.sh`,
`incident-response/hooks/hooks.json`

Per the survey, these three files are not uniformly role-agnostic:

- `trailer-gate.sh` — fully role-agnostic (its own header comment says so
  explicitly). **Proposal: delete the file entirely**, and remove its
  `PreToolUse` (Bash matcher) entry from `hooks.json`, relying on core
  issue #66's own `core/hooks/` registration with `CLAUDE_ROLE` injection.
- `handbook-trigger-gate.sh` — role-agnostic placeholder scaffolding today,
  but its comments anticipate role-specific hardening (write_scope-based
  heuristics) before being load-bearing. **Proposal: delete the file
  entirely** (it is currently a no-op placeholder with no role-specific
  logic actually implemented yet), remove its `hooks.json` entry, and defer
  any role-specific write_scope heuristic to whatever hook mechanism core
  issue #66 exposes for per-role customization (e.g. a config value core
  reads, analogous to work item 4's `RECORD_FIELDS_TERMINAL_STATES`
  approach). This is flagged for confirmation since the issue groups it
  with the other two as a straight duplicate, but this repo's copy has
  more scaffolding intent baked in than the other two.
- `record-fields-gate.sh` — **not** role-agnostic in this repo; it already
  hardcodes this role's own required fields (`timeline`,
  `blameless-postmortem`, `action-items`) and its own record path
  (`docs/issue-<n>/reports/incident-response.md`). **Proposal: do not
  delete this file.** Instead, convert it from a full standalone
  implementation into a thin role-specific config/invocation of core's
  shared gate logic (see work item 3/4 below for the stub shape), keeping
  only the required-fields list and target-path binding local to this
  role. This is called out explicitly because the issue's own wording
  ("복사본과 그 훅 등록 제거") reads as "delete", but the file's content
  argues for "shrink to config + delegate", consistent with work items 3–4.
  Flagging this discrepancy for the approver to confirm before phase 2.

`hooks.json` changes proposed: drop the `handbook-trigger-gate.sh` and
`trailer-gate.sh` command entries under the `PreToolUse`/Bash matcher
(leaving `incident-response-progress-gate.sh` — noting again, per the
survey, that this file does not currently exist in the tree; its absence
is a pre-existing gap unrelated to this issue and is out of scope here).
Keep the `record-fields-gate.sh` entry under the Write|Edit|MultiEdit|
NotebookEdit matcher, since it remains a real (shrunk) file.

## Work item 3 — convert directive.sh to a stub sourcing the shared function

**File:** `incident-response/hooks/directive.sh`

Proposed conversion: replace the current self-contained kill-switch +
`CLAUDE_ROLE` guard + heredoc-print logic with:
1. `source` (or equivalent) of core's `core/hooks/lib/role-directive.sh`.
2. A call to `core_role_directive` (or whatever its actual signature is —
   not inspectable from this repo; phase 2 must confirm against core's
   real function contract) passing this role's directive text as the
   payload, e.g. the YOU DECIDE/USE_WHEN/PRODUCES/WRITE_SCOPE/HAND-OFF/
   BOUNDARY CASE/RECORD block currently in the heredoc, unchanged.
3. The env-var name for this role's kill switch
   (`INCIDENT_RESPONSE_CYCLE_OFF`) should remain configurable per-role,
   since it is role-namespaced; whether that becomes a parameter to
   `core_role_directive` or stays a local guard before the call is a
   phase-2 detail to confirm against core's actual interface.

Preserve verbatim (role-specific, must survive): the full directive text
block — YOU DECIDE, USE_WHEN, PRODUCES, WRITE_SCOPE, HAND-OFF, BOUNDARY
CASE, and RECORD lines, since these encode this role's actual doctrine
(decision boundary, produces list, write scope, hand-off routing, and
phase-gated record path) and are not present anywhere in core.

## Work item 4 — preserve role-specific real differences explicitly (e.g. terminal loop_states) via a settings mechanism

**Files:** `incident-response/hooks/record-fields-gate.sh` (primarily),
possibly a new role-config file if core's shared gate expects one

The issue's example is `RECORD_FIELDS_TERMINAL_STATES` — this repo's
closest analogue is the `REQUIRED_FIELDS` list and `RECORD_SUFFIX` embedded
in `record-fields-gate.sh`'s Python payload. Proposed conversion:
- Extract `REQUIRED_FIELDS = ["timeline", "blameless-postmortem",
  "action-items"]` and the target path
  `docs/issue-<n>/reports/incident-response.md` into an explicit,
  clearly-named role-specific setting (matching whatever mechanism core's
  shared gate consumes — e.g. an env var, a small JSON/shell config file,
  or a documented variable at the top of a thin per-role wrapper script).
  Since core's actual gate-consumption interface is not present in this
  repo, phase 2 must confirm the exact mechanism against core issue #66's
  landed implementation before picking one.
- Everything else in the current file (the `__fc` trap, kill-switch check,
  `python3` presence check, JSON payload parsing, target-path matching) is
  generic gate-running machinery that should come from core once available,
  rather than being re-implemented per role.

## Work item 5 — record `core/hooks/tests/stub-check.sh` pass in the record

Not applicable to this phase-1 deliverable: `core/hooks/tests/stub-check.sh`
does not exist in this repo (it lives in the core repo, not checked out
here) and running it is an execution-time (phase-2) verification step, not
a phase-1 research/proposal item. This proposal notes it as a required
phase-2 step: once the above conversions land, phase 2's execution session
must run `core/hooks/tests/stub-check.sh` and record the pass/fail result
in `docs/issue-2/reports/implementation.md` (the phase-2 record — not
created or touched by this phase-1 work), per contract v3 s19/s20 phase
gating.

## Files touched by this proposal, if approved and executed (phase 2, not now)

- `incident-response/agents/warrant-hunter.md` — shrink to role-specific
  stub referencing core `warrant/`.
- `incident-response/hooks/trailer-gate.sh` — delete.
- `incident-response/hooks/handbook-trigger-gate.sh` — delete.
- `incident-response/hooks/record-fields-gate.sh` — shrink to role-specific
  config + delegation to shared gate logic.
- `incident-response/hooks/directive.sh` — convert boilerplate to
  `source` + `core_role_directive` call, keep directive text.
- `incident-response/hooks/hooks.json` — drop the two deleted gates'
  registrations.
- `README.md` — update Layout section to match (not scoped to this
  proposal's author but flagged for the executor).
- `docs/issue-2/reports/implementation.md` — phase-2 record, created by the
  phase-2 executor, not by this phase-1 work, documenting the
  `stub-check.sh` pass (work item 5).

Nothing outside `docs/issue-2/reports/implementation/` and
`docs/issue-2/proposals/implementation/` has been modified as part of this
phase-1 deliverable.
