# Current-state survey — issue #10 (gate A+ remediation, current grade B-)

Scope: the four incident-response methodology gates
(`incident-response-action-item-gate`, `incident-response-proposal-evidence-gate`,
`incident-response-proposal-order-gate`, `incident-response-rca-method-gate`)
plus `incident-response/hooks/directive.sh` and
`incident-response/hooks/record-fields.config.sh`.

## Defects confirmed by direct read (matches issue #10's audit)

1. **Owner check is a meaningless capitalized-word match.**
   `action-item-gate.sh:193` — `OWNER_RE = re.compile(r'@[A-Za-z0-9_.\-]+|\b[A-Z][a-z]+(?:\s[A-Z][a-z]+)?\b')`.
   The bare-word alternative matches ANY capitalized word — "Fix", "Action",
   "Investigate" — not just names. Combined with `DEADLINE_RE`, a line like
   "Investigate alerting gap by Friday" already passes with no real owner
   named. `tests/action-item-gate.test.sh`'s own `GOOD_SHAPE` fixture line 2
   ("Investigate alerting gap (owner TBD)") would independently satisfy
   `OWNER_RE` on "Investigate" alone, showing the check does not require an
   actual owner token.

2. **Dead code in the shape loop.** `action-item-gate.sh:204`:
   `if not re.search(r'action\s*items?', ln, re.I) and section_level != None and False: pass`
   — the trailing `and False` makes the whole condition always false; the
   `if` body (`pass`) is unreachable, and the surrounding intent (skip lines
   that don't mention "action item" when outside a real heading section) is
   never applied. Confirmed dead code, not just naming noise.

3. **`order-gate.sh`'s scout-skip heuristic is a bare co-occurrence check.**
   Lines 125-132: `skip_recorded = ("skip" in content) and ("scout" in content)`
   over the whole survey file, case-folded, with no adjacency or negation
   awareness. A survey stating "we did NOT skip the scout step" or "scouting
   was not skipped; see scout-brief.md" trips this exactly the same as a
   genuine skip record — the literal words appear together regardless of
   polarity. `evidence-gate.sh:174-176` has the same shape:
   `scout_skip_stated = has_any("scout skip", "skipped scouting") or (has_any("bugfix") and has_any("no design decision"))`
   — two independent substring hits anywhere in the document, no requirement
   that they appear in the same sentence/section or relate to each other.

4. **`evidence-gate.sh`'s four required elements are pure substring
   presence**, not section/structure checks: `(iii)` is satisfied by the
   words "adopt" and "skip" appearing anywhere in the whole document
   (`has_any("adopt") and has_any("skip")`), which a document could satisfy
   incidentally (e.g. "we did not adopt this pattern; skip it" mentioned in
   unrelated prose) without ever presenting an actual adopt/skip list.
   `(iv)` similarly only requires the literal string "issue-1" or
   "decision boundary" to appear anywhere, not that it ties to an adopted
   item.

5. **`README`/`WRITE_SCOPE` mismatch confirmed.**
   `incident-response/hooks/directive.sh:32`:
   `WRITE_SCOPE="['docs/issue-<n>/postmortems/**']"`. No gate, hook, or test
   in this repo reads or writes under `docs/issue-<n>/postmortems/`. All
   four gates' actual write surfaces are
   `docs/issue-<n>/proposals/incident-response*.md` (order-gate,
   evidence-gate) and `docs/issue-<n>/reports/incident-response.md`
   (rca-method-gate, action-item-gate) — confirmed by each gate's own
   `SURFACE_RE`/`RECORD_RE` regex and its own README. `WRITE_SCOPE` is
   stale/ghost and does not reflect the real gated paths.

6. **No gate in this repo sources `core/hooks/lib/gate-lib.sh`.** All four
   gates hand-roll:
   - the fail-closed EXIT trap (`__fc`, duplicated verbatim across all four
     files) — functionally equivalent to `gate_trap_fail_closed`, but not
     sourced from it, so any future canon fix (e.g. issue-72's own bugfix
     history) will not propagate here.
   - the kill-switch check via
     `case "${..._OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac`
     in all four gates (`action-item-gate.sh:26-29`,
     `evidence-gate.sh:25-28`, `order-gate.sh:17-20`,
     `rca-method-gate.sh:29-32`) — this is **exactly** the pre-issue-72 core
     bug the gate-house standard handbook documents as fail-open: any
     unrecognized value (including a typo) falls into the `*` branch and
     disables the gate. `gate_kill_switch_active` fixes this by inverting
     the default to "stay active unless a recognized on-spelling is seen."
     This repo's four gates still carry the pre-fix behavior.
   - `Edit`/`MultiEdit` reconstruction via `current.replace(o, n, 1)`,
     ignoring each edit's own `replace_all` flag
     (`action-item-gate.sh:136-137,147-149`, same shape in the other three
     gates) — this is the second bug class the gate-house standard's
     `gate_reconstruct_write` fixes. A `replace_all: true` `Edit` against a
     multiply-occurring `old_string`, or a `MultiEdit` mixing
     `replace_all: true`/`false` edits, is reconstructed wrong by all four
     gates today (only the first occurrence is ever replaced).
   - path normalization/root-resolution (`_plausible`/`_under`/`resolve`)
     hand-rolled per gate instead of `gate_normalize_path`.
   - none of the four gates route file-write detection through
     `gate_bash_write_targets`, so a `Bash`-tool file write to the same
     target a `Write` call would hit is invisible to all four gates.

## Existing test coverage (baseline, before remediation)

`action-item-gate.test.sh` and `order-gate.test.sh` cover: shape
deny/allow, foreign-path no-op, malformed JSON → deny. Neither covers
`Edit`/`MultiEdit`/`replace_all`, kill-switch-unrecognized-value, or
absolute-path fixtures. None of the four test suites include a
`Bash`-tool-write case. This is the gap the issue's requirement 3
("Edit/MultiEdit/replace_all/malformed-JSON/킬스위치/절대경로 케이스 의무
추가") targets directly.

## Precondition status

Core issue #72 (gate-house standard) is landed: `core/hooks/lib/gate-lib.sh`
and `docs/handbooks/gate-house-standard.md` exist at
`tokenmaxxxer-core` and document `gate_trap_fail_closed`,
`gate_kill_switch_active`, `gate_deny`/`gate_allow`,
`gate_parse_json_or_deny`, `gate_normalize_path`, `gate_reconstruct_write`,
`gate_bash_write_targets`, plus the six-case mandatory test harness
(`run-gate-lib-tests.sh`) and `compliance-check.sh`. Precondition satisfied
— this proposal adopts that library by reference rather than
re-implementing any of it.
