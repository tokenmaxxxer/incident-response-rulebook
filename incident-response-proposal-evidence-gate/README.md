# incident-response-proposal-evidence-gate

Methodology owned: the phase-1 incident-response proposal CONTENT-shape
constraint from `docs/issue-7/proposals/incident-response.md` §3 (approved),
implementing `docs/issue-1/proposals/methodology-norms.md` (a)(2)-(3) for
this role.

## Write surface

`docs/issue-<n>/proposals/incident-response*.md` (PreToolUse on
Write|Edit|MultiEdit). Writes outside this surface are a no-op (exit 0).

## Required elements

Every write to the write surface must, in the resulting full text, contain
all four of:

1. A reference to the current-state survey.
2. A reference to the scout brief, or an explicit stated scout-directive
   skip reason (e.g. a bugfix carrying no design decision).
3. An explicit adopt/skip list.
4. Rationale tying at least one adopted item back to this role's own
   decision boundary (issue-1 / 장애 후 무엇을 배웠고 재발을 무엇으로
   막을 것인가).

Missing elements are denied by name, each naming the source norm it comes
from. All four present → allow.

## Kill switch

`export INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF=1`

## Running tests directly

```
bash tests/evidence-gate.test.sh
```

## Directive-fragment text

This plugin does not own or touch `incident-response/hooks/directive.sh`.
The following text is contributed into that file's `PRODUCES` value by the
phase-2 integrator, not a separate hook:

> Phase-1 content: every docs/issue-<n>/proposals/incident-response*.md must
> reference its current-state survey, reference its scout brief (or a stated
> scout-directive skip reason), carry an explicit adopt/skip list, and tie at
> least one adopted item back to this role's own decision boundary —
> enforced by incident-response-proposal-evidence-gate.
