files:
- incident-response-action-item-gate/hooks/hooks.json, action-item-gate.sh
- incident-response-proposal-evidence-gate/hooks/hooks.json, evidence-gate.sh
- incident-response-proposal-order-gate/hooks/hooks.json
- incident-response-rca-method-gate/hooks/hooks.json
- incident-response/hooks/directive.sh
- incident-response-*/hooks/*.sh (source-guard line, all 5 gate-lib consumers)
- README.md (root)
- incident-response-*/tests/*.test.sh (CORE_HOOKS_LIB → CLAUDE_PLUGIN_ROOT_CORE)

## Current-state survey reference

`docs/issue-13/reports/incident-response/survey.md` (this PR). Confirms
preconditions core #75 (`tokenmaxxxer-core@52bdc15`) and on-the-record
#182 (PR #185) both landed, and locates all four issue-listed defects
plus one additional confirmed defect (`CORE_HOOKS_LIB` vs. the now-landed
`CLAUDE_PLUGIN_ROOT_CORE`) directly implicated by the issue's "공통 항목은
core #75의 확정 가드/규칙을 참조 적용" instruction.

## Scout brief

Skipped — see survey.md's "Scout: skip record". This is a remediation
against an already-approved, already-landed external reference
implementation (core #75), not an open design choice; no field to
scout.

## Adopt / skip

- **Adopt**: core #75's exact `||`-guarded source line shape
  (`. "${CLAUDE_PLUGIN_ROOT_CORE:-<fallback>}/hooks/lib/gate-lib.sh" ||
  { echo ... >&2; exit 2; }`) in place of every `${CORE_HOOKS_LIB:?}`
  source line in this rulebook — because the issue's own precondition
  section names core #75 as the pattern to apply by reference, and
  survey.md confirms `CORE_HOOKS_LIB` is never set by on-the-record's
  spawn path while `CLAUDE_PLUGIN_ROOT_CORE` now is (PR #185).
- **Adopt**: `Bash` added to all four gate plugins' `hooks.json`
  matchers, because survey.md confirms live, tested `Bash`-branch code in
  all four gate scripts is currently unreachable in production — the gap
  is a one-line matcher fix, not a code gap.
- **Adopt**: a stopword/short-token exclusion on `action-item-gate.sh`'s
  `OWNER_RE` line-start alternative, and removal of the bare
  `\bdue\s+\S+` alternative from `DEADLINE_RE`, because survey.md traces
  both to concrete false-accept lines ("The:", "due diligence") the
  re-audit named verbatim.
- **Adopt**: closing `evidence-gate.sh`'s `has_any("scout skip",
  "skipped scouting")` / `(has_any("bugfix") and has_any("no design
  decision"))` disjuncts to the same section/paragraph-scoped,
  negation-aware unit the first disjunct already uses, because survey.md
  shows those two disjuncts are whole-document substring checks with no
  negation guard — the exact "부정 무시 fallback" the issue names.
- **Adopt**: correcting root `README.md`'s `write_scope` header field and
  Layout section (drop the ghost `record-fields-gate.sh` line, add the
  four gate plugins, fix the file name to `record-fields.config.sh`),
  because survey.md confirms both are stale against the shipped tree and
  `.claude-plugin/marketplace.json` (which survey.md confirms is already
  accurate).
- **Skip**: touching `.claude-plugin/marketplace.json` or any individual
  plugin's own `README.md`/`plugin.json` — survey.md found no staleness
  or old-role-name reference in any of them; a fix with no confirmed
  defect is scope creep this issue's four numbered requirements do not
  ask for.
- **Skip**: full NLP/semantic verification of action-item or RCA
  quality — out of scope per every gate's own existing disclaimer,
  unchanged since issue #10; the re-audit's defect list does not reopen
  this boundary.
- **Skip**: building the `compliance-check.sh` "does core-canon detect
  this" run and the missing-core regression test case in this phase —
  that is the issue's requirement 3 (phase-2 delivery-gate evidence), not
  a phase-1 design decision.

## Rationale

This role's own decision boundary is 장애 후 무엇을 배웠고 재발을 무엇으로
막을 것인가 (`docs/issue-1/proposals/incident-response.md`): the gates
under proposal exist specifically so a phase-2 incident-response record
cannot ship without the shape the role's postmortem discipline requires
(owner+deadline on action items, a real primary/contributing RCA
distinction, a real adopt/skip list). Every defect in survey.md is a way
that discipline currently fails silently — a `Bash`-tool write bypasses
the check entirely (defect 1), an action item can carry a fake
owner/deadline pair that reads as compliant (defect 2), a proposal can
claim to have not skipped scouting via a sentence that literally negates
that claim (defect 3), and an operator reading the README gets a false
picture of what surface is protected at all (defect 4) — so leaving any
of these unfixed keeps the exact "게이트가 광고하는 통제가 실제로 걸리지
않는다" gap this role exists to close for OTHER teams' incidents, in its
own tooling. The `CORE_HOOKS_LIB`/`CLAUDE_PLUGIN_ROOT_CORE` mismatch is
the same shape one level down: core #75 was landed specifically to close
the fail-open-on-missing-core defect class, and on-the-record #182 was
landed specifically so a role session's env carries the variable that
guard depends on — a rulebook still reading a different variable name
inherits neither fix, silently.

## What will be done (phase 2, scoped here for review)

1. **hooks.json matcher parity** (4 files): change
   `"matcher": "Write|Edit|MultiEdit"` → `"matcher":
   "Write|Edit|MultiEdit|Bash"` in each of the four gate plugins'
   `hooks/hooks.json`, matching each script's own header comment (already
   documents `Write|Edit|MultiEdit|Bash`) and existing Bash-branch code
   and tests.
2. **Source-guard migration to core #75's shape** (5 files —
   `directive.sh` + 4 gate scripts): replace every
   `. "${CORE_HOOKS_LIB:?}/<lib>"` line with core's confirmed form,
   `. "${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}/hooks/lib/<lib>" ||
   { echo "<script>: cannot source <lib>" >&2; exit 2; }`, placed BEFORE
   any other statement so a failed source still exits 2 (fail-closed) even
   though `gate_trap_fail_closed` has not yet been installed — mirroring
   core's own gate scripts (`approval-gate.sh` etc., all source-then-trap
   in that exact order with the `||` carrying the fail-closed exit
   itself). No fallback-path guessing added: if `CLAUDE_PLUGIN_ROOT_CORE`
   is unset, this rulebook fails closed rather than inventing a relative
   path into its own clone (the exact fallback shape core #75's own doc
   comment warns resolves to the wrong tree in real deploys). Test
   fixtures and their `CORE_HOOKS_LIB` sandbox-fallback env var
   (`incident-response-*/tests/*.test.sh`) are renamed to
   `CLAUDE_PLUGIN_ROOT_CORE` to match.
3. **Owner-check tightening** (`action-item-gate.sh`, both the outer
   comment/doc and the embedded Python `OWNER_RE`): add a stopword guard
   (reject common non-name capitalized words — "The", "This", "It", "A"
   at minimum) on the line-start-before-colon alternative, requiring the
   captured token not be in that stopword set before it counts as an
   owner-looking token.
4. **Deadline-check tightening** (same file, `DEADLINE_RE`): drop the
   bare `\bdue\s+(?:by\s+)?\S+` alternative entirely — every other
   alternative already covers real deadline shapes (ISO date, `by
   <weekday/date>`, `within N <unit>`); the bare-`due` alternative is the
   only one with no date/relative-date anchor and is the one producing
   the "due diligence" false-accept.
5. **Evidence-gate negation-aware scoping for the remaining two
   disjuncts** (`evidence-gate.sh`, element (ii)): fold
   `has_any("scout skip", "skipped scouting")` and the `bugfix`/`no
   design decision` disjunct into the same `scout_units`
   section/paragraph-scoped, negation-guarded check the first disjunct
   already uses, rather than leaving them as whole-document,
   negation-blind substring checks.
6. **README correction** (root `README.md` only): fix the `write_scope`
   header field to the two real surfaces (matching `directive.sh`'s
   already-corrected `WRITE_SCOPE`), fix the ghost
   `record-fields-gate.sh` reference to the real
   `record-fields.config.sh`, and add the four gate plugins to the
   Layout section so the README's picture of "what installs" matches
   `.claude-plugin/marketplace.json`.
7. Regression test per defect, added to each affected gate's own test
   suite (not a new suite): a `Bash`-tool write reaching each gate
   through `hooks.json` is out of this repo's test harness's reach (it
   only invokes the script directly, matching existing suites), so this
   item is a repo-level acceptance note, not a new unit test — verified
   instead by re-reading the shipped `hooks.json` against each script's
   own doc comment.

## Out of scope

- The `compliance-check.sh` run and the missing-core deny test case
  (issue requirement 3) — phase-2 delivery-gate evidence, produced and
  recorded after this proposal's Approve, not designed here beyond
  "apply core #75's mandated test cases," which the precondition
  landing already specifies.
- Any change to `.claude-plugin/marketplace.json` or the four gate
  plugins' own `README.md`/`plugin.json` — no defect found in survey.md.
- `rca-method-gate.sh` and `order-gate.sh`'s own semantic checks beyond
  the matcher/source-guard fixes — survey.md found no equivalent
  owner/deadline-shaped false-accept in either.
- Full NLP/semantic action-item or RCA quality verification — standing
  out-of-scope boundary since issue #10, unchanged.
- `core_plugin_dirs()`/`spawn_cmd()` themselves — on-the-record repo,
  already landed and out of this repo's authority.

## How you'll know it worked

- Each of the four gate plugins' `hooks.json` lists `Bash` in its
  `PreToolUse` matcher; a `Bash`-tool write to each gate's write surface
  denies through the real hook path (not just via direct script
  invocation), verified in phase 2's regression pass.
- Every `. "${CORE_HOOKS_LIB:?}..."` line in this rulebook is replaced by
  the `CLAUDE_PLUGIN_ROOT_CORE`-based, `||`-guarded form; `grep -rn
  CORE_HOOKS_LIB` across the tree returns no source-line hits (test
  fixture env var renames may remain as an intentional sandbox
  convenience, documented as such).
- `core/hooks/tests/compliance-check.sh` (invoked, not vendored) run
  against each of the four gate plugins' `hooks/` directories reports
  `ok` for all four, with no "no `||` guard" finding.
- `- The due diligence: TBD` no longer satisfies `action-item-gate.sh`'s
  owner+deadline shape check (regression test added).
- A proposal containing "we never skipped scouting for this change" (with
  no real scout-brief reference and no explicit stated skip inside the
  scout-scoped unit) is denied by `evidence-gate.sh`'s element (ii)
  check (regression test added).
- Root `README.md`'s `write_scope` field reads the two real surfaces, the
  `record-fields-gate.sh` ghost reference is gone, and all five plugins
  (role + 4 gates) are listed in Layout.
