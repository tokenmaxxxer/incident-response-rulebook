# incident-response-rca-method-gate

Methodology owned: the phase-2 RCA-method + primary/contributing-factor
distinction, per docs/issue-1/proposals/incident-response.md (b)1-3.

## Write surface

`docs/issue-<n>/reports/incident-response.md` (the phase-2 incident-response
record). Writes outside this surface are a no-op (exit 0).

## What it checks

This gate is additive to core's generic field-presence gate — it does not
replace it. It only checks two things beyond field presence, on the fully
reconstructed resulting text (Write = `tool_input.content`; Edit =
`old_string` → `new_string` applied to the current on-disk content,
honoring `replace_all`; MultiEdit = edits applied sequentially, each
edit's own `replace_all` honored independently; a `Bash`-tool command
writing to this gate's target path is also checked, against the file's
current on-disk content):

1. **RCA-method name present** — a case-insensitive substring match on any
   of: "5 whys", "five whys", "causal chain", "causal-chain", "causal
   timeline", "fishbone", "fault tree", "fault-tree".
2. **Primary-vs-contributing-factor distinction present** — a structural,
   section/paragraph-scoped check (still not semantic): "primary" and
   "contributing"/"secondary" must both appear within the same
   blank-line-delimited paragraph or the same heading-delimited section,
   not merely anywhere in the document. Two mentions in unrelated,
   cross-section paragraphs no longer satisfy this check.

If either is missing, the write is denied with a message naming which
element(s) are missing, citing "per docs/issue-1/proposals/incident-response.md
(b)1-3". If both are present, the write is allowed.

**Blamelessness/tone language is explicitly not gated.** Per issue-1 (c),
blameless framing is documented guidance, not machine-checkable, and is
intentionally out of scope for this gate — no tone/blame lexical check is
implemented here.

## Migrated to gate-lib.sh (issue #10 phase 2)

This gate now sources `gate-lib.sh`/`gate-lib.py` from `CORE_HOOKS_LIB`
(never vendored) instead of hand-rolling its own versions: the fail-closed
EXIT trap (`gate_trap_fail_closed`), the kill-switch check
(`gate_kill_switch_active`), path normalization (`gate_normalize_path`),
`Write`/`Edit`/`MultiEdit` reconstruction honoring `replace_all`
(`gate_reconstruct_write`), and `Bash`-tool write-target scanning
(`gate_bash_write_targets`). No `gate_*` function is reimplemented locally
in this gate script.

## Kill switch

```
export INCIDENT_RESPONSE_RCA_METHOD_GATE_OFF=1
```

Polarity (fixed by the gate-lib.sh migration): only a recognized
on-spelling (`1`/`true`/`yes`/`on`, case-insensitive) disables the gate.
Empty/unset, a recognized off-spelling (`0`/`false`/`no`/`off`), and any
unrecognized value (e.g. a typo like `banana`) all leave the gate
**active**. Before this migration, any unrecognized value silently
disabled the gate (fail-open) — that behavior is now fixed.

## Running the tests

```
bash tests/rca-method-gate.test.sh
```

## Directive-fragment text

This plugin's directive fragment, contributed into
`incident-response/hooks/directive.sh`'s `PRODUCES` value by the phase-2
integrator, not a separate hook (this plugin does not create or touch
`directive.sh` — that centralized stub file is owned elsewhere):

> Phase-2 RCA: docs/issue-<n>/reports/incident-response.md must name an RCA
> method (5 Whys / causal chain / fishbone / fault tree) and distinguish
> primary cause from contributing factors — enforced by
> incident-response-rca-method-gate, additive to core's generic
> field-presence check; blamelessness tone is documented guidance, not
> gated.
