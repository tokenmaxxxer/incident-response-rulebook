#!/usr/bin/env bash
# SessionStart: incident-response's role directive.
#
# Stub per core issue #66: kill-switch guard, CLAUDE_ROLE guard, and print
# formatting live in core's core_role_directive function
# (core/hooks/lib/role-directive.sh). This file supplies only this role's
# own values; per core/hooks/tests/stub-check.sh's structural check, every
# line here must be the source line, a plain variable assignment, or the
# core_role_directive call — no locally-regrown boilerplate.
#
# CLAUDE_PLUGIN_ROOT_CORE must point at core's checked-out hooks/lib directory
# (core repo, not this one). Not set here because core is not vendored
# into this rulebook's tree — set it in the environment that loads this
# plugin alongside core.
#
# Issue #7 phase 2: core_role_directive takes its four values as
# positional arguments (core/hooks/lib/role-directive.sh); this file
# previously set same-named variables and called the function with no
# arguments, so the directive printed nothing beyond boilerplate
# (docs/issue-7/reports/incident-response/current-state-survey.md gap
# 1). Fixed below by passing the values positionally. PRODUCES is
# expanded, as one $'...\n...' ANSI-C-quoted assignment (stub-check's
# plain-assignment regex still matches), with the phase-1 and phase-2
# facet gates issue-7 added: docs/issue-7/proposals/incident-response.md
# §2-§6 (incident-response-proposal-order-gate,
# incident-response-proposal-evidence-gate,
# incident-response-rca-method-gate, incident-response-action-item-gate).
YOU_DECIDE="장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가"
USE_WHEN="장애 종결 직후"
# BOUNDARY-CASE: severity-tiered document depth (SEV1 full / SEV2 abbreviated / SEV3 summary-only) is deferred — no upstream severity-classification source exists in this repo yet. Not gated; documented limitation only (see docs/issue-1/proposals/incident-response.md (b)5).
PRODUCES=$'summary, impact, timeline, root-cause-analysis (5-Whys/causal-chain), action items (owner+verb+outcome+deadline)\nPHASE 1 (docs/issue-<n>/proposals/incident-response*.md): order — current-state-survey.md and scout-brief.md must exist before the proposal is written or finalized (incident-response-proposal-order-gate); content — the proposal must reference its survey, reference its scout brief (or a stated scout-directive skip reason), carry an explicit adopt/skip list, and tie at least one adopted item back to this role\'s own decision boundary (incident-response-proposal-evidence-gate).\nPHASE 2 (docs/issue-<n>/reports/incident-response.md): RCA — name an RCA method (5 Whys / causal chain / fishbone / fault tree) and distinguish primary cause from contributing factors (incident-response-rca-method-gate); action items — at least one item in owner+verb+outcome+deadline form, independently checkable by a reader who was not present (incident-response-action-item-gate, shape check only). Blamelessness tone is documented guidance, not machine-gated (issue-1 (c)).'
WRITE_SCOPE="['docs/issue-<n>/proposals/incident-response*.md', 'docs/issue-<n>/reports/incident-response.md']"
HAND_OFF="용량 부족이 원인이면 → capacity-planning; 계측 부재가 원인이면 → observability"
. "${CLAUDE_PLUGIN_ROOT_CORE:?core not resolved}/hooks/lib/role-directive.sh" || { echo "directive.sh: cannot source role-directive.sh" >&2; exit 2; }
core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
