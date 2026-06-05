# Review priority

**Stage:** A SEED-convention repo (see the `seed` repo's `SEED.md`). The
authoritative artifact is the **prose spec** — `SEED.md` + `README.md`. Any
`ref/` code is a single-operator *reference realization* of that prose, not a
product or distribution target. Pre-PMF, one operator. Not at scale.

**Authoritative checklists:** `ref/skills/seed-audit/audit-base.md` +
`audit-malicious.md` in `plow-pbc/seed` — the contrast pairs below are the
PR-relevant distillation; edit there first, re-distill here.

**Cultural emphasis:** SIMPLIFY at all costs — subtractive remedies (delete,
collapse, inline) outrank additive ones at every severity. The prose spec is
the contract; `ref/` is one realization of it. Apply the universal
Broken-Glass posture from `standards.md` § Broken-Glass Test. The structural
gate is falsifiable: `ref/verify.sh` must stay green (it implements the three
SEED structural Verify prompts).

**Repo-specific contrast pairs (beyond the universal set in `standards.md`):**

| SEED-convention DON'T (suppress / flag-as-shape) | SEED-convention DO (real finding) |
|---|---|
| Flag `ref/` code for missing abstractions, scale-hardening, extra flags, or defensive edge cases. `ref/` is a single-operator reference impl, not a product. | Flag a `ref/` change that breaks `ref/verify.sh` or makes a prose `## Verify` prompt no longer pass. |
| Treat prose-only edits (Objects/Actions wording) as low-value churn. | Flag **prose↔ref drift**: `install.sh` diverging from `## Dependencies`, or `verify.sh` behavior diverging from the `## Verify` prompts — the canonical SEED regression. |
| Suggest "approve all" / batched shell to speed an install script. | Flag any `ref/` install/verify shell that **batches or auto-approves** — violates `tier-2` per-block confirm (`^act-trust`). |
| — | Flag any **literal secret** in `SEED.md`/`README.md`, or a probe that surfaces secret values (`env`/`printenv`, `cat` of credential files, `git remote -v`, `docker compose config`) — `^act-author-secrets` / `^act-author-probes`. Presence/name-only probes are the conforming form. |
| — | Flag a clone URL (in spec text or `ref/` shell) carrying **userinfo / query / fragment** — `^act-install-clone-url` argv-leakage rule. |
| — | Flag **grammar violations**: a non-conforming H2; out-of-order H2s; a `# Purpose` body that is anything other than the single `README#Purpose` wikilink; a sub-SEED re-declaring `## Normative Language`; shell smuggled into `## Objects` / `## Actions`; or state-mutating instructions added to `## Verify` (authoring-read-only). |
| Demand prose for a heavy install path. | Flag a heavy install (material disk / runtime / paid API) that does not surface cost to the user as `tier-3`. |
| — | If the PR touches the **feedback protocol**, flag any payload that adds PII or a free-form body, or that fires outside clone-mode + root-only + the one-time consent banner (`^act-feedback`). |
