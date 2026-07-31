#!/usr/bin/env bash
# Role-specific settings for core's shared record-fields gate (core issue
# #66 — the gate itself, formerly this rulebook's own record-fields-gate.sh,
# is now core canon and fires globally; a local copy of that filename is
# drift, not configuration, per core/hooks/tests/stub-check.sh).
#
# Adapted per issue-167 from roles/incident-response.json's `produces`
# (NOT copied from implementation's what-was-done/why/upstream-basis/
# open-findings set).
#
# How core's global gate discovers/loads this file is unconfirmed — core's
# hooks/ tree is not vendored into this repo, so its actual config-discovery
# convention could not be inspected. This is a phase-2 assumption, flagged
# for confirmation once core issue #66 lands its config interface.
RECORD_FIELDS_REQUIRED="timeline,blameless-postmortem,action-items"
RECORD_FIELDS_TARGET_SUFFIX="/reports/incident-response.md"
