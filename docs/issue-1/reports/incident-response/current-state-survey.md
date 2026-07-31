# Issue #1 — Phase 1 survey: current-state of incident-response rulebook norms

Subject: issue-1. Research only — no files outside
`docs/issue-1/reports/incident-response/` and `docs/issue-1/proposals/`
modified.

## What currently governs phase-1 and phase-2 output

- `incident-response/hooks/directive.sh` (role-handoff contract v3
  boilerplate + role text): sets `PRODUCES="timeline, blameless
  postmortem, action items w/ owner+deadline"` and
  `WRITE_SCOPE="['docs/issue-<n>/postmortems/**']"`. No methodology is
  specified for HOW the timeline is reconstructed, HOW root cause is
  established, or what counts as a valid action item beyond
  owner+deadline.
- `incident-response/hooks/record-fields.config.sh`: the only machine-
  enforced gate today. `RECORD_FIELDS_REQUIRED="timeline,blameless-
  postmortem,action-items"`, target `.../reports/incident-response.md`.
  This is a **field-presence** gate only — it checks the three headings
  exist, not their internal quality (no check for RCA depth, no check
  that action items carry an owner/deadline pair, no severity gate on
  whether a postmortem was required at all).
- `incident-response/agents/warrant-hunter.md`: references core
  `warrant/` (core issue #63) for the generic hunt-agent; role boundary
  and hand-off text only, no incident-methodology content.
- No proposal-format norm exists anywhere in this repo for phase-1
  documents themselves — issue #2's proposal (`docs/issue-2/proposals/
  implementation/proposal.md`) is the only precedent, and it is
  point-by-point-against-issue-items in shape, not derived from any
  documented methodology norm.
- `docs/specs/approvers.md`: single approver (`JiwonJung94`), single-
  account mode applies (APPROVE comment path).

## Gaps relative to what a rigor floor would require

1. **No RCA method named.** "Blameless postmortem" section exists as a
   required field, but nothing says whether root cause must be reached
   via 5 Whys, fishbone, causal timeline, or fault tree — so any prose
   under that heading currently passes the gate.
2. **No severity-scoped applicability.** The gate requires the same
   three fields for every subject regardless of incident severity;
   industry practice scales postmortem depth (and whether one is
   required at all) by severity.
3. **Action-item quality is unchecked.** "owner+deadline" is named in
   `PRODUCES`, but the gate does not verify per-item owner/deadline
   presence, nor set deadline SLAs tied to severity.
4. **No impact/summary field.** Current required set is
   timeline/blameless-postmortem/action-items only — no impact
   quantification or one-line summary field, both standard in
   comparable postmortem formats.
5. **No phase-1 proposal methodology norm** — nothing prescribes what
   evidence a phase-1 proposal must cite or how it must be structured,
   beyond the generic contract v3 s19 gate (survey before proposal).

This survey feeds `../incident-response/scout-brief.md`'s gap line and the
proposal's rationale directly.
