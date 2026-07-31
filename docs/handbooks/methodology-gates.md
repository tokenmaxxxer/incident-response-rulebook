# Methodology-enforcement plugin set (issue #7)

Four self-contained plugins, each owning one methodology adopted in
issue-1, mechanically gate this role's write surfaces on top of core's
generic field-presence check. See
`docs/issue-7/proposals/incident-response.md` §2-§7 for the design and
`docs/issue-7/reports/incident-response.md` for what was built.

## Plugins

| Plugin | Gates | Write surface | Kill switch |
|---|---|---|---|
| `incident-response-proposal-order-gate` | survey→scout-brief exist before proposal write | `docs/issue-<n>/proposals/incident-response*.md` | `INCIDENT_RESPONSE_PROPOSAL_ORDER_GATE_OFF` |
| `incident-response-proposal-evidence-gate` | survey ref, scout-brief ref, adopt/skip list, decision-boundary rationale | `docs/issue-<n>/proposals/incident-response*.md` | `INCIDENT_RESPONSE_PROPOSAL_EVIDENCE_GATE_OFF` |
| `incident-response-rca-method-gate` | RCA method named, primary/contributing distinction | `docs/issue-<n>/reports/incident-response.md` | `INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF` |
| `incident-response-action-item-gate` | at least one owner+verb+outcome+deadline action item | `docs/issue-<n>/reports/incident-response.md` | `INCIDENT_RESPONSE_ACTION_ITEM_GATE_OFF` |

Each plugin's own `README.md` documents its gate in full; this handbook
is the operational-surface index, not a duplicate of that detail.

## Running the gate tests

```
bash tests/run-gate-tests.sh
```

Runs each plugin's own test file (`tests/<name>-gate.test.sh` inside its
plugin directory) as a real subprocess and reports pass/fail per case;
exits non-zero if any plugin's suite fails.

## Notes

- All four gates are additive to core's generic `record-fields-gate.sh`
  heading-presence check — they never replace it.
- `incident-response/hooks/directive.sh`'s `core_role_directive` call was
  fixed to pass its four values positionally (previously called with no
  arguments, so role-specific directive text never printed).
