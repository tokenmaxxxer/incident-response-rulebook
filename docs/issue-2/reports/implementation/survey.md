# Issue #2 — Phase 1 survey: current-state of embedded core-canon copies

Subject: issue-2

Scope of this survey: the `incident-response-rulebook` tree as seeded by
"Seed rulebook skeleton for role incident-response" (commit d137f06). This is
research only — no files outside `docs/issue-2/reports/implementation/` and
`docs/issue-2/proposals/implementation/` were modified.

## Repo inventory

```
incident-response/.claude-plugin/plugin.json
incident-response/agents/warrant-hunter.md
incident-response/hooks/directive.sh
incident-response/hooks/handbook-trigger-gate.sh
incident-response/hooks/hooks.json
incident-response/hooks/record-fields-gate.sh
incident-response/hooks/trailer-gate.sh
docs/specs/approvers.md
README.md
```

No `core/` directory exists in this repo (core canon — `core/warrant/`,
`core/hooks/`, `core/hooks/lib/role-directive.sh` — lives in a separate,
presumably shared/submodule repo not checked out here; `.gitmodules` exists
at the top level but was not inspected further since editing it is out of
phase-1 scope).

## File-by-file findings

### 1. `incident-response/agents/warrant-hunter.md` — embedded warrant-hunter copy

Full duplicated copy of the implementation-rulebook's warrant-hunter agent,
explicitly labeled "adapted from implementation-rulebook's
`agents/warrant-hunter.md`". Contains:
- Generic rotating-stance hunt mandate boilerplate (composition-regression /
  silent-failure / design-error stances) — this part is NOT role-specific;
  it is the same generic hunt-agent shape core issue #63 now centralizes in
  `core/warrant/`.
- Role-specific content: the mandate line quoting this role's own decision
  boundary ("장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가") and the
  hand-off scope ("용량 부족이 원인이면 → capacity-planning; 계측 부재가
  원인이면 → observability"). This role-specific pointer is worth preserving,
  but the generic hunt machinery should not be re-implemented here.

**Verdict: duplicated core content — remove the generic agent copy, replace
with a reference to core's `warrant/` plugin.**

### 2. `incident-response/hooks/hooks.json` — gate + directive registration

Registers, via `${CLAUDE_PLUGIN_ROOT}/hooks/...`:
- `SessionStart` → `directive.sh` (role-specific, keep, see #3)
- `PreToolUse` (Write|Edit|MultiEdit|NotebookEdit) → `record-fields-gate.sh`
  (role-specific required-field check, keep, see #4)
- `PreToolUse` (Bash) → `handbook-trigger-gate.sh`, `trailer-gate.sh`,
  `incident-response-progress-gate.sh`

`handbook-trigger-gate.sh` and `trailer-gate.sh` are role-agnostic gates
(see #5, #6) that core issue #66 now registers directly from `core/hooks/`
with `CLAUDE_ROLE` injection — this rulebook's own registration of them is a
duplicate. Note also that `incident-response-progress-gate.sh` is
**referenced but does not exist** in this tree (not in the seeded file
list) — pre-existing gap, out of this issue's scope to create, but flagging
it since work item 2 touches this same file.

**Verdict: hooks.json needs its registration of the 3 role-agnostic gates
(trailer/record-fields/handbook-trigger — note: record-fields-gate.sh here
is actually role-specific per the file itself, see #4 below; only
handbook-trigger-gate.sh and trailer-gate.sh are the role-agnostic ones per
the issue body) removed once core's own registration takes over.** See
proposal for the precise diff — the issue text groups
"trailer/record-fields/handbook-trigger" as the 3 role-agnostic gates, but
the content of `record-fields-gate.sh` in this repo is already
role-specialized (required fields for this role's own record). This
discrepancy is called out explicitly in the proposal for confirmation.

### 3. `incident-response/hooks/directive.sh` — SessionStart directive

Bespoke `bash` script implementing: env-var kill switch, `CLAUDE_ROLE` guard,
then a heredoc printing this role's full directive block (YOU DECIDE /
USE_WHEN / PRODUCES / WRITE_SCOPE / HAND-OFF / BOUNDARY CASE / RECORD).

The kill-switch and `CLAUDE_ROLE`-guard boilerplate at the top (the
`trap`/`case`/`[ "${CLAUDE_ROLE:-}" = ... ]` lines) is generic plumbing that
core issue #66 now centralizes as `core_role_directive` in
`core/hooks/lib/role-directive.sh`. The heredoc body (YOU DECIDE through
RECORD) is 100% role-specific content for `incident-response` and must be
preserved verbatim.

**Verdict: genuinely mixed file — replace the boilerplate with a
`source .../role-directive.sh` + a call to `core_role_directive`, keep the
role-specific directive text as the function's payload/argument.**

### 4. `incident-response/hooks/record-fields-gate.sh` — required-field gate

This gate is explicitly commented as role-specific ("adapted per issue-167
from roles/incident-response.json's `produces`, NOT copied from
implementation's ... set"). Its Python payload hardcodes
`REQUIRED_FIELDS = ["timeline", "blameless-postmortem", "action-items"]` and
the target path suffix `/reports/incident-response.md`. This matches the
issue's work item 4: "역할별 실차이가 있으면(예: 종료 loop_state 집합)
`RECORD_FIELDS_TERMINAL_STATES` 설정으로 명시적 보존" — i.e. the intent is
for the shared/core gate machinery to take the generic check logic, with
per-role required-field lists (and here, an analogous
"terminal states"/required-fields setting) supplied as role-specific
configuration rather than a hand-rolled duplicate script.

**Verdict: role-specific values must be preserved, but the shell/Python
gate-running scaffolding (`__fc` trap, kill-switch, python3-presence check,
JSON parsing loop) duplicates what should be shared core gate logic; keep
only this role's required-fields list + target path as config, source the
rest from core.**

### 5. `incident-response/hooks/handbook-trigger-gate.sh` — role-agnostic gate copy

Comment header says "path heuristics ... are a placeholder", but the file's
own comment also says "harden per this role's actual write_scope ... before
treating as load-bearing; this role does have a write_scope, so the
heuristic below matters" — i.e. it already anticipates being specialized
per role. The verdict-producing body is currently a no-op placeholder
(`exit 0 # placeholder verdict`). Per the issue, core issue #66 lands this
gate directly in `core/hooks/` with `CLAUDE_ROLE` injection, so this local
copy is a duplicate to remove.

**Verdict: role-agnostic gate copy — remove file + hooks.json registration,
rely on core's own registration.**

### 6. `incident-response/hooks/trailer-gate.sh` — role-agnostic gate copy

Comment explicitly states: "Adapted from implementation-rulebook's
trailer-gate.sh, role name substituted only (this file's logic is
role-agnostic)." This is the clearest, most explicit case of a
role-agnostic duplicate in the tree.

**Verdict: remove file + hooks.json registration, rely on core's own
registration.**

### 7. `incident-response/.claude-plugin/plugin.json` — plugin manifest

Purely role-specific metadata (name, description quoting this role's own
decision boundary and hand-off, author). No embedded core content. No
change needed.

### 8. `README.md` and `docs/specs/approvers.md`

`README.md`'s Layout section documents each hooks file, including the three
being removed/stubbed and the warrant-hunter agent — will need updating to
reflect the post-conversion layout (out of scope to edit now, but flagged
for the phase-2 executor).

`docs/specs/approvers.md` exists (checked per instruction, for context
only): currently an empty allowlist template with only an HTML comment
explaining its purpose (one GitHub login per line; approvers gate phase 2
per contract v3 s19). Not edited.

## Summary: what is genuinely role-specific and must survive the conversion

1. `incident-response/.claude-plugin/plugin.json` — as-is, no change.
2. The **directive text** in `directive.sh` (YOU DECIDE / USE_WHEN /
   PRODUCES / WRITE_SCOPE / HAND-OFF / BOUNDARY CASE / RECORD block) — the
   role's own doctrine content, not the surrounding boilerplate.
3. The **required-fields list and record path** in `record-fields-gate.sh`
   (`timeline`, `blameless-postmortem`, `action-items`,
   `docs/issue-<n>/reports/incident-response.md`) — not the surrounding
   shell/Python scaffolding.
4. The role's hand-off routing text ("용량 부족이 원인이면 →
   capacity-planning; 계측 부재가 원인이면 → observability") — currently
   repeated in `plugin.json`, `directive.sh`, `README.md`, and
   `warrant-hunter.md`; should remain wherever it is genuinely role-specific
   doctrine (plugin.json, directive.sh, README), not as justification to
   keep the warrant-hunter agent's generic hunt machinery.

## What is duplicated core content, to be replaced with a reference

1. `agents/warrant-hunter.md`'s generic rotating-stance hunt-agent mandate
   and mechanics (core issue #63's `core/warrant/` plugin).
2. `hooks/trailer-gate.sh` in full (core issue #66's `core/hooks/`
   registration).
3. `hooks/handbook-trigger-gate.sh` in full (core issue #66's `core/hooks/`
   registration).
4. The kill-switch/`CLAUDE_ROLE`-guard boilerplate in `directive.sh` (core
   issue #66's `core/hooks/lib/role-directive.sh` `core_role_directive`).
5. The gate-running scaffolding in `record-fields-gate.sh` (payload read,
   JSON parse, python3-presence check, `__fc` trap) to the extent core
   supplies a shared, parameterizable version of this same gate.
6. Corresponding entries in `hooks.json` for the two gates being fully
   removed (#2, #3 above).

No `core/hooks/tests/stub-check.sh` was found in this repo (it lives in the
core repo per the issue text); running it is a phase-2 execution step, not
part of this phase-1 survey.
