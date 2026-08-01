# incident-response-proposal-evidence-gate

Methodology owned: the phase-1 incident-response proposal CONTENT-shape
constraint from `docs/issue-7/proposals/incident-response.md` §3 (approved),
implementing `docs/issue-1/proposals/methodology-norms.md` (a)(2)-(3) for
this role.

## Write surface

`docs/issue-<n>/proposals/incident-response*.md` (PreToolUse on
Write|Edit|MultiEdit|Bash). Writes outside this surface are a no-op
(exit 0). A `Bash`-tool command whose command text writes to this
surface (detected via `gate_bash_write_targets`) is denied conservatively
— the gate cannot inspect a shell command's resulting content, so it
refuses rather than silently letting it bypass the checks below.

## Required elements

Every write to the write surface must, in the resulting full text, contain
all four of:

1. A reference to the current-state survey.
2. A reference to the scout brief, or an explicit stated scout-directive
   skip reason within a scout-related section/paragraph (e.g. a bugfix
   carrying no design decision).
3. An explicit adopt/skip list: an adopt-tagged item and a skip-tagged
   item must appear in the same heading section or paragraph, not merely
   anywhere in the document.
4. Rationale tying at least one adopted item back to this role's own
   decision boundary (issue-1 / 장애 후 무엇을 배웠고 재발을 무엇으로
   막을 것인가), scoped to the same section/paragraph as that adopted
   item.

Missing elements are denied by name, each naming the source norm it comes
from. All four present → allow. This is a shape check, not a truth check:
elements (ii)-(iv) require the relevant words to co-occur in the same
structural unit (heading section or blank-line-delimited paragraph), not
just presence anywhere in the document — this closes the false-positive
class where an unrelated section merely happens to contain both words.

## Migrated to gate-lib.sh (issue #10 phase 2)

This gate now sources core's gate-house standard
(`CORE_HOOKS_LIB/gate-lib.sh` and `gate-lib.py`) instead of hand-rolling
its own fail-closed trap, kill-switch check, path normalization, and
`Edit`/`MultiEdit` reconstruction: `gate_trap_fail_closed`,
`gate_kill_switch_active`, `gate_normalize_path`,
`gate_reconstruct_write`, and `gate_bash_write_targets` are all sourced
by reference, never vendored. `Edit` with `replace_all: true` and
`MultiEdit` with mixed `replace_all` flags are now reconstructed
correctly (previously only the first occurrence was ever replaced).

## Kill switch

`export INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF=1`

Unrecognized values (e.g. a typo) stay ACTIVE — only a recognized
on-spelling (`1`/`true`/`yes`/`on`, case-insensitive) disables the gate.
This is a fixed polarity from before the migration: previously any
unrecognized value fell into a catch-all branch that silently disabled
the gate.

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
