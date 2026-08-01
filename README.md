# incident-response-rulebook

Rulebook for the `incident-response` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-4 promotion and
generated as skeleton scaffolding by issue-167.

- **decides**: 장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가
- **use_when**: 장애 종결 직후
- **produces**: summary, impact, timeline, root-cause-analysis (5-Whys/causal-chain), action items (owner+verb+outcome+deadline)
- **note**: severity-tiered document depth (SEV1 full / SEV2 abbreviated / SEV3 summary-only) is deferred — see `docs/issue-1/proposals/incident-response.md`
- **write_scope**: ['docs/issue-<n>/proposals/incident-response*.md', 'docs/issue-<n>/reports/incident-response.md']
- **hand-off**: 용량 부족이 원인이면 → capacity-planning; 계측 부재가 원인이면 → observability

## Install

```
claude plugin marketplace add tokenmaxxxer/incident-response-rulebook
claude plugin install incident-response
```

## Layout

- `incident-response/.claude-plugin/plugin.json` — plugin manifest
- `incident-response/hooks/hooks.json` — SessionStart + PreToolUse wiring
- `incident-response/hooks/directive.sh` — SessionStart role directive; stub
  that sources core's `core_role_directive` (core issue #66) and supplies
  only this role's directive text
- `incident-response/hooks/record-fields.config.sh` — this role's required-field
  set + record path, delegated to core's shared record-fields gate (core
  issue #66)
- `incident-response/agents/warrant-hunter.md` — role-specific config
  (decision boundary, hand-off) for core's `warrant/` hunt-agent plugin
  (core issue #63)
- `incident-response-action-item-gate/` — PreToolUse gate enforcing owner+deadline shape on action items in the phase-2 record
- `incident-response-proposal-evidence-gate/` — PreToolUse gate enforcing current-state-survey reference, scout-brief/skip-reason, and adopt/skip list on proposals
- `incident-response-proposal-order-gate/` — PreToolUse gate enforcing phase-1/phase-2 ordering
- `incident-response-rca-method-gate/` — PreToolUse gate enforcing root-cause-analysis method shape on the phase-2 record
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

The role-agnostic commit-trailer gate and the s21 handbook-trigger gate no
longer have copies in this repo — they are registered directly by core
issue #66's `core/hooks/` (`CLAUDE_ROLE`-injected). `directive.sh` and
`record-fields.config.sh` require `CLAUDE_PLUGIN_ROOT_CORE` to point at core's checked
out `hooks/lib` directory to run; they fail closed if it is unset.

This is scaffolding, not a finished rulebook: fill in doctrine detail,
handoff enforcement, and any role-specific progress gate before treating
it as load-bearing.
