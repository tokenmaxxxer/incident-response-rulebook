# incident-response-proposal-order-gate

Owns one methodology: the phase-1 **survey → scout → propose ORDER**
constraint (issue-1 (a)(1)), mechanically enforced rather than left to
convention.

## Write surface

`docs/issue-<n>/proposals/incident-response*.md`

## What it enforces

Before that path may be created or finalized, this gate requires that,
for the same issue number `<n>`:

- `docs/issue-<n>/reports/incident-response/current-state-survey.md` exists on disk, **and**
- `docs/issue-<n>/reports/incident-response/scout-brief.md` exists on disk

— or that an explicit scout-directive-compliant skip record (the literal
words "skip" and "scout" together) is present in the survey file. This is
a file-existence check per the proposal, not full state-machine parsing.
Any write outside the write surface is a no-op (exit 0). Denials are
printed as `incident-response: refused — ...`, naming which of the two
files is missing.

## Kill switch

`INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF` — set to any value other than
`""`/`0`/`false`/`no`/`off` to disable the gate (allow everything).

## Running the tests

```
bash tests/order-gate.test.sh
```

## Directive contribution

This plugin contributes the following fragment into
`incident-response/hooks/directive.sh`'s `PRODUCES` value by the phase-2
integrator — it is not a separate hook in this plugin, and this directory
does not create or touch `directive.sh` (that file stays centralized
under core's stub-check.sh structural cap):

> "Phase-1 order: survey (docs/issue-<n>/reports/incident-response/current-state-survey.md) then scout-brief.md must exist on disk before docs/issue-<n>/proposals/incident-response*.md is written or finalized — enforced mechanically by incident-response-proposal-order-gate, not just convention."
