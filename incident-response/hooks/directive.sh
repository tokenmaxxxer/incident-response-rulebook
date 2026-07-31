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
# CORE_HOOKS_LIB must point at core's checked-out hooks/lib directory
# (core repo, not this one). Not set here because core is not vendored
# into this rulebook's tree — set it in the environment that loads this
# plugin alongside core.
YOU_DECIDE="장애 후 무엇을 배웠고 재발을 무엇으로 막을 것인가"
USE_WHEN="장애 종결 직후"
PRODUCES="timeline, blameless postmortem, action items w/ owner+deadline"
WRITE_SCOPE="['docs/issue-<n>/postmortems/**']"
HAND_OFF="용량 부족이 원인이면 → capacity-planning; 계측 부재가 원인이면 → observability"
. "${CORE_HOOKS_LIB:?}/role-directive.sh"
core_role_directive
