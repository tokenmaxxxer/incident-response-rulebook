# Scout brief — issue #10 gate A+ remediation

Mode: 1 stage, batched-sequential (this issue's precondition names one
fixed reference — core's landed gate-house standard — so there is no
independent field to fan out search angles across; sweep was reading the
canon repo's library + handbook + test harness + compliance-check.sh
directly, done sequentially as one deepening pass on the survey's gap #6).
Total: 1 stage, well under the 5-stage/3min budget.

## Must-bes (from the canon, `tokenmaxxxer-core`)

- Every gate must source `gate-lib.sh` and call `gate_trap_fail_closed`,
  `gate_kill_switch_active`, `gate_deny`/`gate_allow` — not hand-roll
  equivalents. (`docs/handbooks/gate-house-standard.md`)
- Kill-switch default MUST be "stay active on any unrecognized value";
  only `1`/`true`/`yes`/`on` (case-insensitive) disable.
- `Edit`/`MultiEdit`/`NotebookEdit` reconstruction MUST go through
  `gate_reconstruct_write`, honoring each edit's own `replace_all`
  independently.
- Path matching MUST go through `gate_normalize_path` (absolute/relative/
  `./`-prefixed all resolve to the same root-relative tail; outside-root
  rejected).
- `Bash`-tool writes MUST be scanned via `gate_bash_write_targets` so a
  shell redirect to the same target a `Write` call would hit is not
  invisible.
- `compliance-check.sh` is the canon detector for exactly two hand-rolled
  patterns (kill-switch case-statement without `gate_kill_switch_active`;
  `.replace(x, y[, 1])` without `gate_reconstruct_write`) — a migrated gate
  must pass it clean.

## Performance axes this canon competes on

1. **Fail-closed completeness** — trap at top before `set -uo pipefail`,
   malformed/empty/non-object JSON denies, internal-error denies. All four
   of this repo's gates already do this independently (each hand-rolls the
   same `__fc` trap and the same JSON try/except-deny shape) — this axis is
   already met structurally, just not via the shared library.
2. **Semantic-check depth** — canon's own six-case harness stops at
   structural JSON/path/reconstruction correctness; it does **not** itself
   define a section/adjacency check for role-specific content gates (that
   is this rulebook's own remediation scope per issue #10 requirement 2,
   not something to import from core).
3. **Test-harness completeness** — the six mandatory case groups
   (`replace_all` Edit, mixed-`replace_all` MultiEdit, malformed JSON,
   unrecognized kill-switch stays active, absolute/`./`-prefixed path,
   Bash-write coverage) are the bar; `run-gate-lib-tests.sh` fails itself
   if any group is unexercised — same self-checking pattern this repo's
   remediation should copy for its own four-gate suite.

## Adopt / skip

- **Adopt**: source `gate-lib.sh` (bash) + `gate-lib.py` (Python) in all
  four gates, replacing the hand-rolled trap, kill-switch case statement,
  path resolution, and `.replace(...)` reconstruction. Adopt the six
  mandatory test-case groups verbatim, adapted to each gate's own write
  surface and payload shape. Adopt `compliance-check.sh` as a CI-style
  post-migration check (invoked, not vendored).
- **Skip**: do not adopt or extend `gate-lib.sh`/`.py` themselves — no
  role-specific semantic logic (owner-token real-name detection,
  section/adjacency scoping for scout-skip and adopt/skip-list checks)
  belongs in core canon; it is unique to this rulebook's four content
  gates and stays local, referencing core only for the structural
  primitives above.

## Gap line (per issue #10's audit, mapped onto the must-bes above)

- MET: fail-closed trap-at-top, malformed-JSON deny, per-gate kill-switch
  presence (shape exists, but with the pre-fix polarity — see MISSING).
- MISSING: `gate_kill_switch_active`-equivalent polarity (all four gates
  currently disable-on-unrecognized-value, the confirmed fail-open bug);
  `gate_reconstruct_write` (`replace_all` ignored in all four);
  `gate_normalize_path`/`gate_bash_write_targets` (hand-rolled, no
  Bash-write coverage); the mandatory six-case test groups (currently 0/6
  present in `action-item-gate.test.sh`/`order-gate.test.sh`, other two
  suites unread but same code shape implies same gap); semantic
  upgrade from substring to section/adjacency/structure (this rulebook's
  own scope, not covered by core canon at all — core's gap line stops at
  structural correctness, so this is the one axis where the fix must be
  designed here rather than adopted).

Sources: `tokenmaxxxer-core/core/hooks/lib/gate-lib.sh`,
`tokenmaxxxer-core/docs/handbooks/gate-house-standard.md`,
`tokenmaxxxer-core/core/hooks/tests/run-gate-lib-tests.sh`,
`tokenmaxxxer-core/core/hooks/tests/compliance-check.sh` (all read
directly from the landed core checkout at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`).
