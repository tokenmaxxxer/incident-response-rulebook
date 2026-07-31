# Issue #7 — Phase 1 survey: current enforcement state of this plugin

Subject: issue-7. Research only — no files outside
`docs/issue-7/reports/incident-response/` and `docs/issue-7/proposals/`
modified in this phase.

## What exists today

- `incident-response/hooks/directive.sh`: role-directive stub per core
  issue #66 (sources `core/hooks/lib/role-directive.sh`, calls
  `core_role_directive`). Carries `PRODUCES` already expanded by issue-1
  phase 2 to name the five sections and the RCA/action-item schema as
  **text** — but the canon `core_role_directive` signature (per
  `core/hooks/lib/role-directive.sh`) takes `<you_decide> <use_when>
  <produces> <hand_off>` as **positional arguments**; this file currently
  sets same-named shell variables and calls `core_role_directive` with no
  arguments. If core's actual installed lib matches the copy inspected
  here, the call passes four empty strings and the directive prints
  nothing beyond the boilerplate header/footer. This is a pre-existing
  defect, not introduced by this issue; phase 2 must fix the call site
  (pass the values positionally) as a prerequisite for any "directive
  심화" work to have effect at all.
- `incident-response/hooks/record-fields.config.sh`: field-**presence**
  only, delegating to core's shared `record-fields-gate.sh` (core issue
  #66, fired globally — not vendored here). Checks
  `RECORD_FIELDS_REQUIRED="summary,impact,timeline,root-cause-analysis,
  action-items"` against `.../reports/incident-response.md`. Cannot check
  RCA method name, action-item shape (owner+verb+outcome+deadline), or
  blamelessness — the file's own header already documents this
  limitation (issue-1 phase-2 handoff).
- No gate exists over `docs/issue-<n>/proposals/*.md` (phase-1 write
  surface) at all — nothing mechanically enforces that a phase-1
  proposal actually cites a current-state survey and a scout brief, or
  that adopted methodology elements carry sources, even though issue-1's
  own adopted proposal-norm (a) requires exactly this for every future
  phase-1 document this role produces (self-referentially including this
  one).
- No state/order tracking exists: nothing mechanically checks that
  `current-state-survey.md` and `scout-brief.md` exist before
  `proposals/incident-response.md` is written, i.e. the
  survey→scout→adopt order issue-1 (a)(1) named as this role's own
  methodology is enforced only by the scout-directive's session
  convention, not by a gate.
- `incident-response/agents/warrant-hunter.md`: thin core-reference stub
  (issue #2 conversion), no methodology content, no change proposed by
  issue-1 and none identified here either.
- No `tests/` directory exists in this repo at all — no gate-test harness
  of any kind, unlike `implementation-rulebook` (`tests/parse-check.sh`,
  `tests/deny-only-check.sh`, `tests/run-gate-tests.sh`) or
  `pricing-rulebook` (`hooks/tests/stub-check.sh` invocation, gate logic
  covered by its own PR review rather than a committed test file — a
  weaker precedent than implementation-rulebook's).
- `hooks/hooks.json` registers only `directive.sh` (SessionStart) and a
  `PreToolUse` matcher for `Bash` pointing at
  `incident-response-progress-gate.sh` — **a file that does not exist in
  this repo.** The hooks.json entry is dead/broken today; no
  progress-gate currently fires for this role at all.

## Reference machinery surveyed (canon-referenced, not copied, per
`docs/handbooks/canon-scripts.md`)

- `pricing-rulebook/pricing/hooks/methodology-gate.sh` — the closest
  precedent to "implementation-rulebook 수준" for a **content-shape**
  PreToolUse gate: fail-closed trap-at-top, resolves the write target
  under the actual project root (handles both `CLAUDE_PROJECT_DIR` and a
  `git rev-parse` fallback), restricts itself to its own role's write
  surfaces via regex, reconstructs the resulting file content for
  Write/Edit/MultiEdit before scanning it, and denies naming each missing
  required element by name (not just "fields missing").
- `implementation-rulebook/coding/hooks/coding-progress-gate.sh` — the
  state/order-tracking precedent: a `Bash` `PreToolUse` gate matching
  `git commit`, which reads a *different* role's record file (verify.md)
  to decide whether coding's own commit may proceed, and requires
  resolution to be provable via committed text (a `resolved_findings`
  entry naming the finder path + sha) rather than trusted narration. The
  order constraint issue #7 asks for (survey→scout→adopt) is structurally
  simpler — same-role, same-phase, file-existence order — and does not
  need cross-role record parsing; a much smaller gate suffices.
- `core/hooks/lib/role-directive.sh` / `core/hooks/tests/stub-check.sh` —
  constrains how far "directive 심화" can go structurally:
  `directive.sh` must remain source-line + plain-variable-assignment +
  one `core_role_directive` call, nothing else (case statements, control
  flow, or raw heredocs fail the stub check). Facet depth must live
  **inside** the values of the four allowed variables (each as one
  physical source line, using `$'...\n...'` ANSI-C quoting for multi-line
  content so the line still matches stub-check's plain-assignment
  regex), not as new shell logic.

## Gaps this proposal must close

1. Directive text is already long-form (issue-1 phase 2) but not
   phase-specific (no distinct phase-1 vs. phase-2 step/criteria/
   prohibition breakdown) and is currently inert due to the
   argument-passing defect above.
2. No machine gate exists for phase-1 proposal shape (issue-1's own
   adopted norm (a) is unenforced), and the phase-2 record gate only
   checks heading presence, not RCA-method naming or action-item shape
   (issue-1's adopted norm (b), items 1-3).
3. No order/state enforcement for survey→scout→adopt.
4. No gate tests exist in this repo at all.
5. `hooks.json` references a nonexistent progress-gate script — a stale
   pointer that phase 2 must either populate or remove.
