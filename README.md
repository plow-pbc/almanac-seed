# Almanac — standalone product seed

**Almanac** is Plow's internal design-review surface: a Figma-style commenting tool where
reviewers drop pin-anchored comments directly on iframed HTML artifacts (projects → options →
versions), with threaded replies, emoji reactions, resolve, live presence, and a header-gated
API for AI reviewers.

This repo is **one file that matters**: [`almanac.seed.md`](almanac.seed.md) — a
self-contained, one-shot **SEED**: a complete product specification (the *recipe*) with **no
implementation code**. Hand it to a coding agent; the agent "hydrates" it — building the whole
Next.js 14 app from scratch until every acceptance journey in the seed's `§16` passes.

## Use it

**Recommended:** paste `almanac.seed.md` into your Claude Code session (host or container) and say:

> *Hydrate this seed: build the app it specifies, then run its `## Steps` and `## Verify` until all 27 §16 journeys pass.*

The seed's own `## Steps` install everything (Node check, `npm install`, `npx playwright
install --with-deps chromium`, an auto-generated `.env.local`, an example corpus, build) and
its `## Verify` runs all 27 `§16` acceptance journeys against the build's **own** `localhost:3210`
— **no Google, no external/production instance**. Local sign-in is the seed's own env-gated
`GET /api/test-login` (`ALMANAC_TEST_LOGIN=1`).

## Self-contained & proven

A blind, zero-context agent in a **bare `node:20-slim`** container — no pre-baked tools, no
original Almanac, no minted auth, no `mypeople` — followed the seed and reached **27/27**,
independently re-verified. Visual fidelity (`J23–J27`) is asserted by **computed-style/DOM
against the absolute values in `§9`**, never by diffing another running app.

## Automated verify harness

[`verify/hydrate-and-verify.sh`](verify/hydrate-and-verify.sh) runs the whole stranger flow in
a throwaway `node:20-slim` container (needs Docker + a `claude` CLI with auth): it hands the
seed to a fresh blind agent, which builds the app and runs the seed's `## Verify`, then prints
`FINAL_VERIFY=<n>/27`. See the script header for usage.

## Provenance

Extracted from `plow-pbc/mypeople` (`seeds/almanac.seed.md`) — now its own home. The seed has
**zero** coupling to mypeople.
