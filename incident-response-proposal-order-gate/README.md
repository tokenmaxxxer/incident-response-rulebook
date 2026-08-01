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

— or that an explicit, non-negated scout-skip record is present in the
survey file: either a skip marker (`skip`/`skipped`/`skipping`) inside a
heading-delimited "scout" section, or the words "skip" and "scout" within
a bounded ~15-token window of each other with no negation token (`not`,
`never`, or an `n't`-suffixed word) in that window. This is a
file-existence check per the proposal, not full state-machine parsing, and
the skip-record check is section/adjacency-scoped rather than a bare
whole-document substring co-occurrence, so a survey stating "we did NOT
skip the scout step" is no longer misread as a valid skip record. Any
write outside the write surface is a no-op (exit 0). Denials are printed
as `incident-response: refused — ...`, naming which of the two files is
missing. `Bash`-tool commands that write to a path on this gate's write
surface are covered the same way `Write`/`Edit`/`MultiEdit` calls are.

## Migrated to gate-lib.sh (issue #10 phase 2)

This gate sources `core/hooks/lib/gate-lib.sh` (via `CORE_HOOKS_LIB`)
instead of hand-rolling its own fail-closed trap, kill-switch check,
path-normalization, and Bash-write-target scan:

- `gate_trap_fail_closed` — the fail-closed `EXIT` trap.
- `gate_kill_switch_active` — the kill-switch check (see corrected
  polarity below).
- `gate_lib.gate_normalize_path` (Python, loaded via `GATE_LIB_PY`) —
  root-relative path normalization for both absolute and relative
  (including `./`-prefixed) `file_path` values.
- `gate_bash_write_targets` — extracts candidate write-target tokens from
  a `Bash` tool's `command` string, each checked against this gate's own
  write-surface pattern.

This gate does **not** use `gate_reconstruct_write`: it is a
file-existence/skip-record check and never reconstructs a write's
resulting content, so `gate_reconstruct_write` has no application here.

## Kill switch

`INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF` — the gate stays **active**
(denies when the survey/scout-brief precondition is unmet) for any value
other than a recognized on-spelling. Only `1`/`true`/`yes`/`on`
(case-insensitive) disables the gate (allows everything). An unrecognized
value (a typo, e.g. `1x`, or garbage like `banana`) no longer disables the
gate — this is the corrected polarity from `gate_kill_switch_active`;
previously (pre-issue-10) any unrecognized value fell through to
disabling the gate, which was the fail-open bug this migration fixes.

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
