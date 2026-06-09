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
gate is falsifiable: `verify/hydrate-and-verify.sh` must stay green — a blind
agent hydrates `SEED.md` and runs its `## Verify` journeys, printing
`FINAL_VERIFY=<n>/27` (it implements this repo's `## Verify` prompts). This
repo has no `ref/` payload; the prose spec IS the realization.

**Repo-specific contrast pairs (beyond the universal set in `standards.md`):**

| SEED-convention DON'T (suppress / flag-as-shape) | SEED-convention DO (real finding) |
|---|---|
| Flag `ref/` code for missing abstractions, scale-hardening, extra flags, or defensive edge cases. `ref/` is a single-operator reference impl, not a product. (This repo has no `ref/` payload.) | Flag a change that breaks `verify/hydrate-and-verify.sh` (drops `FINAL_VERIFY=<n>/27`) or makes a prose `## Verify` journey no longer pass. |
| Treat prose-only edits (Objects/Actions wording) as low-value churn. | Flag **prose↔harness drift**: `SEED.md` `## 15.`/`## 16.` journeys diverging from what `verify/hydrate-and-verify.sh` actually drives (the `<n>/27` count, the §16 journey set) — the canonical regression here. |
| — | Flag any **literal secret** in `SEED.md`/`README.md`, or a probe that surfaces secret values (`env`/`printenv`, `cat` of credential files, `git remote -v`, `docker compose config`) — `^act-author-secrets` / `^act-author-probes`. Presence/name-only probes are the conforming form. |
| — | Flag a clone URL (in spec text or `ref/` shell) carrying **userinfo / query / fragment** — `^act-install-clone-url` argv-leakage rule. |
| — | Flag **grammar violations** against *this repo's* accepted product-seed contract (`SEED.md` H1 `# SEED: almanac`, numbered H2s `## 1. … ## 19.` plus `## Step 0`): a renamed/renumbered section that breaks the seed's own cross-references; shell smuggled into a spec-prose section that is meant to be declarative; or state-mutating instructions added to `## 15. Verify` / `## 16. Verification journeys` (authoring-read-only). (The canonical `# Purpose` H1 / ordered-canonical-H2 / `## Normative Language` checks do NOT apply — this repo has not adopted that grammar.) |
| Demand prose for a heavy install path. | Flag a heavy install (material disk / runtime / paid API) that does not surface cost to the user as `tier-3`. |
| — | If the PR touches the **feedback protocol**, flag any payload that adds PII or a free-form body, or that fires outside clone-mode + root-only + the one-time consent banner (`^act-feedback`). |
