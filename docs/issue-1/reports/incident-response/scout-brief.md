# Issue #1 — scout brief

Mode: parallel WebSearch fan-out, 4 angles (stage 1) + 1 focused
deepening round (stage 2) = 2 stages total, well under the 5-stage /
3min budget; stopped at judge point 2 (saturation — second-round
sources converged with round 1, no new build decision surfaced).

## Category must-bes (converged across NIST, Google SRE, PagerDuty)

- Post-incident review within a bounded window while memory is fresh
  (NIST: ~2 weeks) [nist-lifecycle].
- Postmortem document has 5 canonical sections: summary, impact
  (quantified), timeline, root cause analysis, action items
  [google-sre].
- Every action item = named owner + verifiable verb + specific outcome +
  tracker entry + deadline — "owner+deadline" alone is the weak version
  of this [pagerduty-postmortem].
- Deadlines scale by severity (PagerDuty: Sev-1 fix in 15 days, Sev-2 in
  30) [pagerduty-postmortem].
- RCA is a named method, not free prose: 5 Whys, fishbone/Ishikawa, fault
  tree, or causal timeline — practitioners combine timeline + 5 Whys
  [rca-methods].
- Postmortem requirement/depth scales by severity: SEV1 always, SEV2
  abbreviated, SEV3 brief summary only, no meeting [severity-process].
- Facilitator is someone NOT involved in the incident; drafts timeline
  pre-meeting from logs, publishes after [severity-process].

## Performance axes this role should compete on

1. RCA rigor (named method + depth) vs. free-text "root cause" prose.
2. Action-item enforceability (owner+verb+deadline+tracker, severity-SLA'd)
   vs. unchecked field presence.
3. Blamelessness as a structural constraint (facilitator independence,
   language review), not just a section label.

## Adopt / skip

- **Adopt**: named RCA method requirement (5 Whys and/or causal
  timeline — matches this repo's existing `timeline` field and is the
  combination practitioners actually use); action-item schema
  (owner+verb+outcome+deadline, not just owner+deadline); impact/summary
  as required fields alongside existing three.
- **Skip**: severity-tiered document depth (SEV1/SEV2/SEV3 branching) —
  this rulebook has no existing severity-classification mechanism
  upstream (no `docs/issue-<n>/incidents/severity` input observed), so
  branching gate logic on an undefined input is premature; note as a
  future hand-off point instead of building it now.
- **Skip**: live meeting facilitation logistics (60-90min agenda,
  facilitator independence) — this is a human-process convention outside
  what a directive/gate can mechanically enforce; record it as proposal
  guidance text, not a plugin field.

## Segment fit

This role is a single-agent async rulebook, not a live meeting culture —
practices are being adapted (as written norms an agent-authored postmortem
must satisfy), not copied as live-meeting ritual.

## Gap line

Field-presence already covers: timeline, blameless-postmortem
(loosely), action-items (loosely). Missing against the surveyed
must-bes: named RCA method enforcement, action-item schema
(owner+verb+deadline, not just owner+deadline), impact/summary as a
required field, and a documented (not gated) severity hand-off note.

## Sources

- [nist-lifecycle] https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r3.pdf
- [google-sre] https://sre.google/workbook/postmortem-culture/
- [google-sre] https://sre.google/sre-book/postmortem-culture/
- [pagerduty-postmortem] https://postmortems.pagerduty.com/culture/accountability/
- [pagerduty-postmortem] https://postmortems.pagerduty.com/how_to_write/writing/
- [rca-methods] https://clickhouse.com/resources/engineering/root-cause-analysis
- [severity-process] https://whytrace.com/en/blog/E22_sre-postmortem
- [severity-process] https://www.pagerduty.com/resources/incident-management-response/learn/incident-severity-classification/
