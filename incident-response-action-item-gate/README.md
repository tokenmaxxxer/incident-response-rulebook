# incident-response-action-item-gate

Methodology owned: the phase-2 action-item **owner+verb+outcome+deadline
shape**, per docs/issue-1/proposals/incident-response.md (b)1-3.

Write surface: `docs/issue-[0-9]+/reports/incident-response.md`. This gate
is additive on top of (never a replacement for) the core canon's generic
field-presence gate and the sibling rca-method-gate — all three register
separately as PreToolUse hooks on the same file.

## The shape check

At least one bullet/line under an "Action Item(s)" heading must carry
**both**:

- an owner-looking token — a capitalized name (e.g. `Jiwon Jung`) or an
  `@handle`, and
- a deadline-looking token — an ISO date (`2026-08-15`) or a
  relative-date phrase (`by Friday`, `within 3 days`, `due ...`).

**This is a shape check, not a truth check.** A regex cannot verify that
the verb+outcome clause is semantically real, complete, or achievable —
only that an owner and a deadline are present alongside it. Presence of
both is treated as satisfying the four-slot shape; it says nothing about
whether the action item is actually a good one.

Outside the write surface above, the gate is a no-op (exit 0). Malformed
or unparseable PreToolUse JSON, or a payload from which no project root
can be resolved, denies (fails closed).

## Migrated to gate-lib.sh (issue #10 phase 2)

This gate now sources `core/hooks/lib/gate-lib.sh` (and `gate-lib.py` via
`GATE_LIB_PY`) instead of hand-rolling its own machinery: the fail-closed
`EXIT` trap, the kill-switch check, JSON parsing, `Edit`/`MultiEdit`
reconstruction (including `replace_all`), root-relative path
normalization, and `Bash`-tool write-target scanning are all sourced from
core, not reimplemented here. `CORE_HOOKS_LIB` must point at core's
checked-out `hooks/lib` directory in the environment that runs this gate.

## Kill switch

```
export INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF=1
```

Only a recognized on-spelling (`1`/`true`/`yes`/`on`, case-insensitive)
disables the gate. Any other value — including an unrecognized/garbage
value such as a typo — leaves the gate **active**; this is the fixed
polarity `gate_kill_switch_active` provides (the pre-migration hand-rolled
check had the opposite, fail-open behavior for unrecognized values).

## Running tests

```
bash tests/action-item-gate.test.sh
```

## Directive-fragment text

This plugin does not own or touch `incident-response/hooks/directive.sh`.
The following fragment is contributed into that centralized stub's
`PRODUCES` value by the phase-2 integrator — it is not a separate hook
from this plugin:

> Phase-2 action items: docs/issue-<n>/reports/incident-response.md must
> contain at least one action item in owner+verb+outcome+deadline form,
> independently checkable by a reader who was not present at the
> incident — enforced by incident-response-action-item-gate (shape check
> only, not a truth check).
