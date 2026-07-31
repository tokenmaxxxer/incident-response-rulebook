# incident-response-rca-method-gate

Methodology owned: the phase-2 RCA-method + primary/contributing-factor
distinction, per docs/issue-1/proposals/incident-response.md (b)1-3.

## Write surface

`docs/issue-<n>/reports/incident-response.md` (the phase-2 incident-response
record). Writes outside this surface are a no-op (exit 0).

## What it checks

This gate is additive to core's generic field-presence gate — it does not
replace it. It only checks two things beyond field presence, on the fully
reconstructed resulting text (Write = `tool_input.content`; Edit =
`old_string` → `new_string` applied to the current on-disk content;
MultiEdit = edits applied sequentially):

1. **RCA-method name present** — a case-insensitive substring match on any
   of: "5 whys", "five whys", "causal chain", "causal-chain", "causal
   timeline", "fishbone", "fault tree", "fault-tree".
2. **Primary-vs-contributing-factor distinction present** — a lightweight
   lexical check (not semantic): "primary" together with "contributing" or
   "secondary" appearing anywhere in the text.

If either is missing, the write is denied with a message naming which
element(s) are missing, citing "per docs/issue-1/proposals/incident-response.md
(b)1-3". If both are present, the write is allowed.

**Blamelessness/tone language is explicitly not gated.** Per issue-1 (c),
blameless framing is documented guidance, not machine-checkable, and is
intentionally out of scope for this gate — no tone/blame lexical check is
implemented here.

## Kill switch

```
export INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF=1
```

## Running the tests

```
bash tests/rca-method-gate.test.sh
```

## Directive-fragment text

This plugin's directive fragment, contributed into
`incident-response/hooks/directive.sh`'s `PRODUCES` value by the phase-2
integrator, not a separate hook (this plugin does not create or touch
`directive.sh` — that centralized stub file is owned elsewhere):

> Phase-2 RCA: docs/issue-<n>/reports/incident-response.md must name an RCA
> method (5 Whys / causal chain / fishbone / fault tree) and distinguish
> primary cause from contributing factors — enforced by
> incident-response-rca-method-gate, additive to core's generic
> field-presence check; blamelessness tone is documented guidance, not
> gated.
