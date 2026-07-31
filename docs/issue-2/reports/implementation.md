# Issue #2 — Phase 2 record: core-canon reference conversion

Subject: issue-2

## what was done

Executed the phase-1-approved core-canon reference conversion for the
`incident-response` rulebook: removed the vendored copies of core-canon
gates (`trailer-gate.sh`, `handbook-trigger-gate.sh`, `record-fields-gate.sh`)
and the warrant-hunter mechanics, converted `directive.sh` to a structural
stub, extracted role-specific record-fields settings to a non-canon-named
config file, updated `hooks.json` and `README.md` to match, and ran
`core/hooks/tests/stub-check.sh` against the result. Full detail below.

## why

Issue #2: core landed a single canon for the warrant-hunt agent (core issue
#63) and the three role-agnostic gates + directive boilerplate (core issue
#66), so this rulebook's own copies are now duplication/drift risk rather
than load-bearing implementation — the issue asks for this rulebook to
reference that canon instead of re-implementing it locally.

## upstream basis

`docs/issue-2/proposals/implementation/proposal.md` (phase-1, approved via
the issue-level `APPROVE issue-2/implementation` comment per contract v3
s19 single-account path) and `docs/issue-2/reports/implementation/survey.md`
(phase-1 current-state survey). One point of the approved proposal was
corrected during execution against ground truth — see item 3 below.

## loop_state

loop_state: landed

Phase-2 execution finished, `stub-check.sh` passes, record written. No open
loop back to phase 1; next step is PR review/merge.

## open findings

- Core's own repo (`core/hooks/lib/role-directive.sh`, and whatever
  discovers `record-fields.config.sh`) is not checked out here and its
  exact interface was not inspectable — see "Known gap" section below.
- `incident-response/hooks/incident-response-progress-gate.sh`, referenced
  in `hooks.json`'s Bash matcher, still does not exist in this tree; this
  is a pre-existing gap from before this issue and remains out of scope.

Phase 2 opened via the issue-level comment `APPROVE issue-2/implementation`
(exact-string match, contract v3 s19 single-account path). Executed the
conversion proposed in `docs/issue-2/proposals/implementation/proposal.md`,
with one correction surfaced by ground-truth verification (item 3 below):
`record-fields-gate.sh` is also a core-canon filename, not a role-specific
file to shrink-and-keep, contrary to the proposal's original flag.

## What changed

1. `incident-response/agents/warrant-hunter.md` — replaced the local
   rotating-stance implementation description with a stub pointing at core's
   `warrant/` plugin (core issue #63). Preserved verbatim: the role's
   decision boundary ("장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가")
   and the hand-off text.
2. `incident-response/hooks/trailer-gate.sh` and
   `incident-response/hooks/handbook-trigger-gate.sh` — deleted. Removed
   their `PreToolUse`/Bash entries from `hooks.json`. Core issue #66's own
   `core/hooks/` registration fires these globally now.
3. `incident-response/hooks/record-fields-gate.sh` — **deleted**, correcting
   the phase-1 proposal's "shrink to config + delegate, keep the filename"
   plan. Running the actual `core/hooks/tests/stub-check.sh` (item 5) showed
   this filename is itself treated as core canon and its presence anywhere
   under a rulebook's `hooks/` tree is the drift signal the check exists to
   catch — regardless of the file's content. The two role-specific settings
   that made this file non-role-agnostic (`REQUIRED_FIELDS` and the record
   target path) were extracted instead into a differently-named file,
   `incident-response/hooks/record-fields.config.sh`
   (`RECORD_FIELDS_REQUIRED`, `RECORD_FIELDS_TARGET_SUFFIX`), so the setting
   survives without recreating the banned filename. Removed the file's
   `PreToolUse`/Write|Edit|MultiEdit|NotebookEdit entry from `hooks.json`
   entirely (no local file left to register).
4. `incident-response/hooks/directive.sh` — converted to the stub shape
   `core/hooks/tests/stub-check.sh` structurally requires: a source of
   `${CORE_HOOKS_LIB}/role-directive.sh`, plain single-line variable
   assignments for this role's values (`YOU_DECIDE`, `USE_WHEN`,
   `PRODUCES`, `WRITE_SCOPE`, `HAND_OFF`), and a bare `core_role_directive`
   call — no locally-regrown kill-switch/guard/print boilerplate. All five
   values preserved verbatim from the original heredoc text.
5. `core/hooks/tests/stub-check.sh` — found on disk in this execution
   environment (core's repo is not vendored into this checkout, but the
   check script was available regardless) and run directly against
   `incident-response/`:

   ```
   $ bash stub-check.sh incident-response/
   stub-check: ok — no vendored 'trailer-gate.sh' under incident-response/
   stub-check: ok — no vendored 'record-fields-gate.sh' under incident-response/
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under incident-response/
   stub-check: ok — no vendored 'parse-check.sh' under incident-response/
   stub-check: ok — incident-response/hooks/directive.sh is a role-directive stub
   ```

   **Result: PASS** (exit 0), all five checks green.
6. `README.md` — Layout section updated to match: drops the deleted files,
   documents the `CORE_HOOKS_LIB` env var both `directive.sh` and
   `record-fields.config.sh`'s consumer depend on, and notes the two
   role-agnostic gates are now core-registered.

## Known gap, unresolved by design

Core's own repo (`core/hooks/lib/role-directive.sh`, and whatever reads
`record-fields.config.sh`) is not checked out in this repo and its actual
function signatures/config-discovery convention were not inspectable.
`directive.sh` and `record-fields.config.sh` are built as real seams
(`CORE_HOOKS_LIB` env var, documented in both files and in `README.md`)
rather than mocked — they fail closed (`CORE_HOOKS_LIB` unset/missing →
`role-directive.sh` sourcing errors) rather than silently no-op. Confirming
the exact `core_role_directive` call signature and
`record-fields.config.sh`'s discovery mechanism against core issue
#66/#63's landed implementation is follow-up work outside this issue's
scope (core repo access, not available here).

## Files touched

- `incident-response/agents/warrant-hunter.md`
- `incident-response/hooks/trailer-gate.sh` (deleted)
- `incident-response/hooks/handbook-trigger-gate.sh` (deleted)
- `incident-response/hooks/record-fields-gate.sh` (deleted)
- `incident-response/hooks/record-fields.config.sh` (new)
- `incident-response/hooks/directive.sh`
- `incident-response/hooks/hooks.json`
- `README.md`
- `docs/issue-2/reports/implementation.md` (this file)
