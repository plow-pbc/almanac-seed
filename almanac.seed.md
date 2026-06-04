# SEED: almanac

> A self-contained product-spec "seed" for **Almanac** — a Next.js 14 design-review app (Google/@plow.co auth, anchored comment pins on iframed artifacts, presence, agent-reviewer API).
> **To build:** hand this file to a coding agent — it builds the app and self-runs the §16 acceptance journeys.
> **Proven in a VANILLA environment — a stranger installs AND verifies it from scratch.** A blind, zero-context agent in a bare `node:20-slim` container (no pre-baked Playwright/tools, no mypeople, no Vercel layer, no original Almanac, no minted auth) followed the seed's own `## Steps` and `## Verify`: it installed everything itself (npm install, `npx playwright install --with-deps chromium`, auto-generated secrets via `openssl`, example corpus, build, `next start`) and ran the full acceptance suite — **27/27 §16 journeys PASS**, against only its own `localhost:3210` build (zero reference/production instance). The visual journeys (J23–J27) assert computed-style/DOM against the **absolute values in §9**. Two deploy-env assumptions were closed so a bare `next start` works without Vercel: security headers are applied in **`next.config.js`/middleware** (`X-Frame-Options: DENY` + CSP `frame-ancestors 'none'` everywhere **except** `/seed/` and `/seed-kv/`, which stay frameable), and `/seed`·`/seed-kv` return **401** (not a 307→/login) when unauthenticated. Dev sign-in is the seed's own `GET /api/test-login` (no Google). Functional + visual fidelity all self-verify.

> seed-format: 1

> **You're an AI agent reading this seed.** Your job: build the **Almanac** web app — a
> Figma-style design-review surface for Plow's "seed" HTML explorations — from this
> specification alone, until every acceptance journey in **§16** passes. This file is the
> product; the running Next.js app is just the proof. It contains **NO implementation
> code** on purpose: you have reasoning, you pick the file layout and the React/route
> wiring. What this seed pins down — the data model (§4), the KV key schema (§5), the route
> map (§6), the API contracts (§7), the exact constants, regexes, limits, colors, fonts and
> emoji (§9, §13) — is **fixed**. Treat those as load-bearing; everything else you may build
> the idiomatic way.
>
> **Definition of done.** A signed-in `@plow.co` reviewer can open a project, drill into an
> option and a version, see the rendered HTML artifact in an iframe, drop pin-comments on
> it, reply, react, resolve, see who else is viewing live, and an AI agent can read the same
> surface and write comments back through a header-gated API — all behaviors in §16
> observable and green. Run `## Verify` (§15-adjacent) and the §16 journeys; the seed is
> proven only when they pass.

---

## Step 0 — Prerequisites & one-time setup (DO THIS FIRST)

> **Front-load every human touch.** Hydrating the app (`## 13.5 Steps`) is fully automated, and
> the public deploy (`## 13.6`) is CLI/API **except two unavoidable browser actions** — a Vercel
> device-login and creating the Upstash store. **Clear both of those, plus the passphrase, NOW,
> before you build anything.** Do this section first and the entire hydrate → build → deploy run
> straight through with **zero mid-flow surprises** (no "stop, go approve a login", no "stop, go
> click Connect in a dashboard" surfacing one at a time later).

### 0.0 What you'll need (prerequisites — confirm all before building)

- **A free Vercel account** — Hobby/personal **or** a Team. (Login is a one-time **device-flow you
  approve in your own browser**, §0.2. Personal and Team differ in one CLI flag — see §0.3.)
- **Upstash for Redis** — the KV/persistence backend, **provisioned through the Vercel dashboard**
  (Marketplace). Almanac is a Redis-style KV app — **no SQL, no schema, no migration**; the keyspace
  is created on first write.
- **An access passphrase you pick now** — the production, **Google-free** login (§6,
  `ALMANAC_ACCESS_PASSWORD`). Anyone with it can sign in, so make it strong; this is what you hand
  reviewers.
- **A host with Node ≥ 18.17 and the Vercel CLI** (install in §0.1 — mind the bare-host `EACCES`).
- **(Optional) Google OAuth creds** — only if you also want domain-gated SSO; **not required**, the
  passphrase covers a public deploy.

### 0.1 Install the Vercel CLI (mind the bare-host `EACCES`)

`## 13.6` assumes a `vercel` binary; a bare/non-root host has none. `npm i -g vercel` then fails with
**`EACCES`** on the global prefix. Clear it up front with a **user-writable prefix** (no sudo):

```bash
mkdir -p ~/.npm-global && npm config set prefix ~/.npm-global
export PATH="$HOME/.npm-global/bin:$PATH"   # add this to your shell rc so it persists
npm i -g vercel
vercel --version                            # confirm it's on PATH
```

(Alternatives: `sudo npm i -g vercel`, or skip the global install and use `npx vercel …` everywhere.)

### 0.2 🧑 Vercel login — device flow (approve in YOUR browser) — **HUMAN STEP #1**

```bash
vercel login
```

It prints a device URL like `https://vercel.com/oauth/device?user_code=XXXX-XXXX` and **waits**.
**You** open that URL in your browser, pick your **scope** (personal account or your Team), and click
**Confirm** — one click. The CLI then proceeds authenticated; the token is cached at
`~/Library/Application Support/com.vercel.cli/auth.json` (macOS) or
`~/.local/share/com.vercel.cli/auth.json` (Linux).

### 0.3 Create the Vercel project (personal-vs-Team **scope gotcha**)

You'll `vercel link` from the hydrated app dir; create the project now or at deploy. The scope flag
differs by account type:

- **Team account:** `vercel link --yes --project <your-almanac> --scope <your-team>`
- **Personal account:** **OMIT `--scope`.** Vercel **rejects** `--scope <username>` with
  *"You cannot set your Personal Account as the scope"*. Use just
  `vercel link --yes --project <your-almanac>`.

> Likewise, the REST/API calls in `## 13.6` take `?teamId=<team>` **only on a Team** — on a personal
> account **omit `?teamId=` entirely** and use your username as the scope. If you create a bare
> project via API, also set `framework: "nextjs"` (§13.6 step 5) or the deploy fails with
> *"No Output Directory named 'public' found."*

### 0.4 🧑 Provision + connect Upstash Redis (Vercel dashboard) — **HUMAN STEP #2**

In the Vercel dashboard, do the **exact clicks**:

1. Your project → **Storage** → **Create Database** → **"Upstash for Redis"** (Marketplace) →
   **Connect**.
2. **Connect Project** → select **`<your-almanac>`** → **All Environments** → **Connect**.

This **auto-injects** `KV_REST_API_URL` + `KV_REST_API_TOKEN` (+ `KV_URL`, `REDIS_URL`,
`KV_REST_API_READ_ONLY_TOKEN`) into the project across all environments — confirm later with
`vercel env ls`. No SQL/schema; the keyspace appears on first write. (A no-browser CLI/API path for
*just the connect* exists in §13.6 step 3, but **store creation itself is this dashboard step**.)

### 0.5 Pick the passphrase + set prod secrets (up front)

Choose your passphrase now, then set the production env so the deploy is clean:

```bash
printf '%s' "$(openssl rand -base64 32)" | vercel env add NEXTAUTH_SECRET production
printf '%s' "<your-chosen-passphrase>"   | vercel env add ALMANAC_ACCESS_PASSWORD production
```

- **Do NOT set `ALMANAC_TEST_LOGIN`** — leaving it unset keeps the dev sign-in bypass **404'd** in
  prod (the passphrase is the only public login).
- `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` + `ALLOWED_DOMAIN` **only** if you also want Google SSO.
- **One value can't be known yet:** `NEXTAUTH_URL` — it's your deploy URL, which Vercel only prints
  after the first `vercel deploy --prod`. Set it **right after** the first deploy (§13.6 step 8) and
  redeploy once. That single post-deploy step is **expected**, not a surprise.

### 0.6 Deployment Protection will need turning OFF (know it now)

New Vercel projects default to **Vercel Authentication** (`ssoProtection`), which 401s the **entire**
URL — even `/login` — to outside visitors. You'll disable it during deploy (§13.6 step 7:
dashboard **Settings → Deployment Protection → Vercel Authentication → Disabled**, or
`PATCH /v9/projects/<prj>` `{"ssoProtection":null}`). Flagged here so it's not a surprise — your app's
own passphrase is the real gate.

### ✅ 0.7 Gate-cleared checklist (every human touch done → rest is automated)

- [ ] Vercel CLI installed and on `PATH` (`vercel --version`)
- [ ] `vercel login` approved in browser (🧑 #1)
- [ ] Project created with the **correct scope** (omit `--scope` on personal)
- [ ] Upstash store **created + connected → All Environments** (🧑 #2); `KV_REST_API_*` present
- [ ] Passphrase chosen → `ALMANAC_ACCESS_PASSWORD` + `NEXTAUTH_SECRET` set (production)
- [ ] `ALMANAC_TEST_LOGIN` left **unset**
- [ ] Aware `NEXTAUTH_URL` is set once post-first-deploy, and Deployment Protection gets disabled

With every box checked, run `## 13.5 Steps` (hydrate/build) then `## 13.6 Deploy` — they execute
**CLI/API-only, no further human interruptions**, ending at a live public URL you log into with your
passphrase.

---

## 1. Purpose & context

**Almanac** (codebase package name `seeds-feedback`; product/brand name shown to users:
**"Plow • Almanac"**) is Plow's **internal design-review room**. Plow's product process
generates lots of self-contained HTML "seed" explorations (landing pages, catalog layouts,
feature mocks — each a single `.html` file). Almanac is where the team **critiques** them:
it renders each artifact in an iframe and lets reviewers leave **pin-anchored comments**
directly on the design, exactly like commenting in Figma, plus threaded replies, emoji
reactions, resolve/unresolve, live presence ("who's looking right now"), and a side
activity panel.

It is **internal and gated**: only `@plow.co` Google accounts get in (`robots: noindex`).
A second, **header-gated API** lets **AI review agents** (not humans) read an artifact and
its thread and write comments back programmatically — so an automated design critic can
participate in the same review surface as the humans.

The product evolved through a **data-model refactor** from a 2-level shape
(Project → Version) to a **3-level shape (Project → Option → Version)**. The seed targets
the **3-level model** as canonical, but the read paths must keep **legacy 2-level fallbacks**
alive (see §4, §5, §10) because a deploy can run ahead of the migration script.

Character traits the rebuild must preserve:
- **Figma-style commenting** over an iframe'd static artifact — pins live *inside* the seed
  document, numbered, avatar-glyphed, clustered when they overlap.
- **Optimistic everywhere** — every mutation updates the UI immediately and rolls back on
  failure.
- **Plow brand** — chalk background, volt-lime accent, Instrument-Serif headings, film-grain
  overlay (see §9).
- **Two front doors** — a human (Google-auth, session-cookie) surface and an agent
  (two-header) surface, writing into the **same** comment store.

---

## 2. Technical approach (stack, prerequisites, constraints)

- **Framework**: **Next.js 14 App Router** (React 18, TypeScript, `strict`). Server
  Components for pages; `"use client"` for interactive components. Route handlers under
  `src/app/api/**`. Path alias `@/* → src/*`.
- **Runtime**: dev + prod server on **port 3210** (`next dev -p 3210` / `next start -p 3210`).
- **Auth**: **NextAuth v4**, JWT session strategy, with **two providers**: **Google** OAuth (optional SSO; domain-gated) and a **Credentials "passphrase"** provider (the production, Google-free login, gated by `ALMANAC_ACCESS_PASSWORD` — see §6). Plus a dev-only `test-login` route. Edge
  **middleware** is the first gate.
- **Persistence**: **Vercel KV** (`@vercel/kv`, a Redis-compatible store) for ALL mutable
  state (comments, replies, reactions, viewers, resolves, project/option/version metadata,
  display-name overrides, status, anchor caches). **Dev fallback**: when KV env vars are
  absent, fall back to an **in-memory `Map`** implementing the same `get/set/del/llen/rpush/
  lrange/lrem/hincrby/hgetall/hset/sismember/sadd/srem` surface, so `next dev` works with no
  KV provisioned (warn once on stderr; never use the memory store in production).
- **Seed corpus on disk**: HTML artifacts live under `cookoff-seeds/<projectDir>/<file>.html`
  at the **repo root** (`SEEDS_ROOT = <cwd>/cookoff-seeds`). These are **auto-discovered**
  (§4). The repo ships a corpus; the seed treats `cookoff-seeds/` as an input.
- **HTML parsing** (agent surface only): **cheerio** for server-side selector/text anchor
  resolution and candidate-anchor extraction. No headless browser in the function bundle
  (Vercel Functions ship no browser binary) — bounding boxes are therefore `null`.
- **No other heavyweight deps**: no CSS framework, no emoji-picker library (a curated
  in-house set, §9), no state library beyond React.
- **Security headers — apply PORTABLY, not via the deploy layer.** Set
  `X-Frame-Options: DENY`, `Content-Security-Policy: frame-ancestors 'none'`, and HSTS on
  **all paths EXCEPT** `/seed/` and `/seed-kv/` (those two must stay frameable — the
  VersionViewer iframes them same-origin). The **source of truth is the app itself**:
  `next.config.js` `async headers()` (or the middleware) with the **same negative-lookahead**
  `source: "/((?!seed/|seed-kv/).*)"`. ⚠️ Do **NOT** rely on `vercel.json` — a stranger runs
  `next start` with **no Vercel header layer**, so vercel.json-only headers simply don't
  apply. A `vercel.json` copy may exist as an optional duplicate for the Vercel edge, but the
  portable `next.config`/middleware rule is what the seed requires and what `## Verify` checks.
- **E2E**: Playwright (`npm run e2e`).

---

## 3. The two front doors (mental model)

1. **Human surface** — browser, NextAuth Google session cookie. Reaches every page + every
   `/api/*` route except the agent ones. Identity = the signed-in `@plow.co` email.
2. **Agent surface** — server-to-server, **two request headers** (no cookie). Reaches exactly
   three endpoints (`GET /api/agent-artifact/*`, `POST /api/agent-comments`,
   `DELETE|PATCH /api/agent-comments/[id]`). Writes into the **same** comment KV shape humans
   use, tagged with `agentAuthored: true`.

Both doors mutate one store; a comment placed by an agent renders through the same pin path
as a human comment (with the agent's chosen display name + avatar).

---

## 4. Data model (entities & relations — the 3-level model)

```
Project ──< Option ──< Version ──< Comment ──< Reply
                                      │
                                      ├─ Reactions (per comment & per reply)
                                      └─ Resolved flag
Version ──< Viewer (presence)
```

- **Project** — a design problem. `{ id (slug), name, status, options[], source?, description? }`.
  - `status` ∈ **`active` | `archived` | `shipped`** (the three `STATUSES`).
  - `source`: `"fs"` (auto-discovered from disk) or `"kv"` (manually created via UI).
- **Option** — one distinct *direction/exploration* under a Project.
  `{ id (slug), name, source, description?, versions[] }`. Each Option carries its own
  iteration history.
- **Version** — one artifact **revision** under an Option.
  `{ id (slug, e.g. "v1"), author, roundDir, slug, source: "fs"|"kv", fsSlug? }`.
  - `fs` version → HTML lives on disk, served via `/seed/<roundDir>/<slug>`.
  - `kv` version → HTML lives in KV, served via `/seed-kv/<project>/<option>/<version>`.
  - A `kv` version may be **stacked on top of** an `fs` option (an fs-discovered v1 with a
    manually-uploaded v2/v3).
- **Comment** — a pin. `{ id, projectId, optionId, versionId, x, y, author, authorEmail?,
  body, ts, deleted?, deletedAt?, editedAt?, anchorSelector?, anchorText?, movedBy?,
  movedAt?, agentAuthored?, authorAvatar? }`. `x`/`y` are coordinates **in iframe-document
  pixels**.
- **Reply** — `{ id, parentCommentId, author, authorEmail?, body, ts }`.
- **Reactions** — a `Record<emoji, count>` per comment and per reply; plus a per-(target,
  emoji) **set of userIds** so a user toggles their own reaction.
- **Resolved** — per-comment flag with `{ by, at }` meta, mirrored into a per-version
  resolved **set**.
- **Viewer** — presence record `{ email, name, image, lastTs }`, one per person per version
  (a hash keyed by email; revisits refresh name/image/lastTs).

### Auto-discovery rule (fs projects)

Walk `cookoff-seeds/`. Each subdirectory (minus a hidden-dirs skip-list and dotfiles) is a
**Project** (`id = dir name`). Each `*.html` file inside becomes an **Option**
(`id = filename without ".html"`), and that option owns a single **Version** `id = "v1"`,
`source: "fs"`, with the on-disk file as its artifact. (So one HTML file ⇒ one option ⇒ one
v1.) Manual uploads later can append `kv` versions (v2, v3…) onto these options.

- Project display name: a hardcoded override map for a few slugs (`seed` → "Individual seed
  page", `catalog` → "Seed catalog", plus the archived `seed-page`/`seed-catalog` pair),
  else derive by `split("-")` + title-case (words ≤2 chars stay lowercased).
- Version label: `"v" + N` → `"Version N"`; any other slug renders raw.
- Option label default: numeric `vN` slugs render as `"Option N"`; else the stored
  name/slug.
- Hidden dirs (skipped by discovery, kept on disk for provenance): `round-2`, `round-2-deps`,
  `round-3-synthesis`, `round-4-install-order`, `round-5-design-review`, `round-6-catalog`,
  `round-7-catalog-aligned`, `deps-cookoff`, `copy-1`, `eng-1`, `eng-2`.
- Index ordering: `seed-page` first, then `seed-catalog`, then the rest alphabetically.

### Manual (kv) projects

Created via the UI (§7 POST /api/projects). Stored in KV under both a **canonical 3-level
shape** and a **legacy mirror** (so `loadManualProjects` still discovers them if the new read
path falters). On collision, fs-discovered slugs win.

### Migration & legacy fallback (must implement the fallbacks)

The pre-refactor 2-level data keyed comments/viewers/resolves by `(projectId, versionId)`
where that `versionId` is *now* the **optionId**, with the migrated version being **`v1`**.
Every read path that takes `(projectId, optionId, versionId)` must, when the canonical
3-level key is empty **and** `versionId === "v1"`, **fall back** to the legacy 2-level key
`(projectId, optionId)`. A legacy Comment row lacking `optionId` is back-filled on read:
`optionId ← versionId`, `versionId ← "v1"`. A re-runnable migration script (idempotent,
tags done rows in a `migration:v1:done` set) copies legacy keys forward and patches embedded
triplets; it does **not** delete legacy keys.

---

## 5. KV key schema (fixed — these exact key shapes)

> `<p>` = projectId, `<o>` = optionId, `<v>` = versionId, `<id>` = comment/reply id,
> `<e>` = emoji. IDs are `crypto.randomBytes(8).toString("hex")` → **16 hex chars**.

**Comments / replies / reactions / resolve**
- `comment:<id>` → Comment JSON
- `version:<p>:<o>:<v>:comments` → list of comment ids (RPUSH order = pin order)
- `version:<p>:<v>:comments` → **legacy** 2-level list (read-fallback for v1)
- `comment:<id>:replies` → list of reply ids
- `reply:<id>` → Reply JSON
- `comment:<id>:reactions` / `reply:<id>:reactions` → hash `{ emoji: count }`
- `comment:<id>:reactions:<e>:users` / `reply:<id>:reactions:<e>:users` → set of userIds
- `comment:<id>:resolved` → `{ by, at }` | null
- `version:<p>:<o>:<v>:resolved` → set of resolved comment ids (+ legacy `version:<p>:<v>:resolved`)

**Presence / display names / status / per-user**
- `version:<p>:<o>:<v>:viewers` → hash `{ email: ViewerJSON }` (+ legacy `version:<p>:<v>:viewers`)
- `project:<p>:displayName`, `project:<p>:option:<o>:displayName`,
  `version:<p>:<o>:<v>:displayName` (+ legacy `version:<p>:<v>:displayName`)
- `project:<p>:status` → status override string
- `user:<userId>` → display-name (legacy; userId now = lowercased email)

**Manual project (legacy mirror shape)**
- `manual:projects` (list of slugs), `manual:project:<slug>:meta`,
  `manual:project:<slug>:versions`, `manual:project:<slug>:version:<vid>:meta`,
  `manual:project:<slug>:version:<vid>:html`

**Canonical 3-level project shape**
- `project:<slug>:meta`, `project:<slug>:options` (list)
- `project:<slug>:option:<oslug>:meta`, `project:<slug>:option:<oslug>:versions` (list)
- `project:<slug>:option:<oslug>:version:<vslug>:meta`
- `project:<slug>:option:<oslug>:version:<vslug>:html`

**Agent anchor cache**
- `candidate_anchors:<sha256(html) first-32-hex>` → cached candidate-anchor array

**Active-viewer window**: `ACTIVE_VIEWER_WINDOW_MS = 60_000`. A viewer is "live" if
`lastTs >= now - 60s`. The cumulative list still powers the activity feed + viewed-by panel.

---

## 6. Auth & access control (fixed rules)

- **Provider**: Google OAuth. Restrict to the `plow.co` Workspace: set `authorization.params
  .hd = "plow.co"` and `prompt = "select_account"`; the Google OAuth client should be
  configured **Internal**. A `signIn` callback is **defense-in-depth**: reject any email not
  ending in `@plow.co` (lowercased). Session strategy = **JWT**; carry `email/name/picture`
  through the `jwt` + `session` callbacks. Sign-in + error pages both route to `/login`.
- **Identity** (`readIdentity`): from the server session; `userId = lowercased email`,
  plus `name`, `email`, `image`. No session ⇒ null.
- **Edge middleware** gates everything. It gates on a **valid session** — `getToken` returns
  a JWT **with an `email`** — and **nothing more.** ⚠️ It must **NOT** hard-check `@plow.co`:
  the domain restriction is enforced **only at the Google sign-in `signIn`/`authorize`
  callback** (gated by `ALLOWED_DOMAIN`), never in the middleware. (A **passphrase** session's
  identity is `…@almanac.local` — if the middleware hard-gated `@plow.co` it would bounce every
  passphrase user off every page, breaking the public deploy. This bug is **invisible to the
  §16 dev journeys**, which sign in as `tester@plow.co` — so do not reintroduce it.) Behavior:
  - Skip `/_next`, `/favicon*`, `/robots.txt`.
  - **Public paths** (no session needed): `/api/auth/*`, `/api/agent-comments(/…)`,
    `/api/agent-artifact(/…)`, `/login`, **and `/api/test-login` (dev only — see below)**.
    (The two agent paths are public to NextAuth because they carry their own header auth.)
  - Not signed in + non-public path ⇒ **redirect to `/login?next=<path+search>`** — **EXCEPT**
    the artifact paths `/seed/` and `/seed-kv/`, which return **`401` (not a 307→/login)**.
    *(WHY: these are artifacts served into an `<iframe>` / consumed by `fetch`; a 307 to an
    HTML login page would load the login screen inside the iframe instead of failing cleanly.
    A 401 is the correct unauth response for an asset endpoint and matches the route handlers'
    own 401 — see §7/§14. This reconciles the otherwise-contradictory "middleware redirects
    everything" vs "`/seed` returns 401" rules: the middleware special-cases `/seed`·`/seed-kv`
    to 401.)* In normal use the iframe requests carry the session cookie (same-origin) and get
    200; the 401 is the unauth path.
  - Signed in + hitting `/login` ⇒ redirect to `/`.
  - Matcher: everything except `_next` / `favicon.ico` / `robots.txt`.
- **Dev-auth bypass — `GET /api/test-login` (MANDATORY; this is how Verify signs in without
  Google).** Real Google OAuth is `Internal`-to-`plow.co`, so a fresh implementer has **no
  way to sign in** and the journeys can't run. The build MUST therefore ship a dev-only login
  route so the app is usable + verifiable with **no Google credentials and no externally
  minted JWT**:
  - **Gated by env `ALMANAC_TEST_LOGIN=1`.** When the flag is **unset/≠1**, the route returns
    **404** (so it can never authenticate anyone in production). Never enable it in prod.
  - **Behavior** (flag on): `GET /api/test-login?email=<addr>&next=<path>` — default
    `email=tester@plow.co`, `next=/`. It **mints a valid NextAuth session** for that identity
    and sets it the way NextAuth would: encode a JWT with `next-auth/jwt`'s `encode` using
    `NEXTAUTH_SECRET` (so the middleware's `getToken` validates it), carrying
    `{ email, name, picture }` (derive a name like the local-part; image may be null), and set
    it as the **same session cookie name** NextAuth uses (`next-auth.session-token`, or
    `__Secure-next-auth.session-token` under HTTPS). Then **302 → `next`**.
  - **Domain guard still applies**: reject an `email` not ending in `@plow.co` with 400 (the
    bypass is for *@plow.co test identities*, not an open door).
  - It must be in middleware **PUBLIC_PATHS** so an unauthenticated caller can reach it.
  - With this, a stranger (or Playwright) hits `/api/test-login` once and is a signed-in
    `@plow.co` user for every gated page — no Google, no harness, no hand-minted token.
- **Passphrase login — the real PRODUCTION auth (MANDATORY for a public deploy; Google is optional).**
  `test-login` is dev-only (404 in prod), and Google OAuth requires the deployer's own OAuth
  client + a workspace domain — so for a stranger to stand up a **real, secured, public**
  Almanac with **no Google at all**, the build ships a **NextAuth Credentials provider**
  ("passphrase") as a first-class, production auth path:
  - **Active iff `ALMANAC_ACCESS_PASSWORD` is set** (a strong secret in the deploy env). When
    it's unset, the provider is not offered (dev relies on `test-login`; a Google-only deploy
    ignores it).
  - **`/login` renders a passphrase field** (a "name" field too, optional — see identity
    below) whenever the provider is active, **in addition to** the Google button when
    `GOOGLE_*` is configured. With neither Google nor passphrase configured, only `test-login`
    (dev) can sign in.
  - **`authorize` callback**: compare the submitted passphrase to `ALMANAC_ACCESS_PASSWORD`
    **constant-time** (timing-safe; reject on mismatch). On success, return a session identity
    and mint the **same NextAuth JWT** (signed with `NEXTAUTH_SECRET`) the rest of the app
    already consumes — so middleware/`readIdentity`/pins all work unchanged.
  - **Identity for passphrase sessions**: the login form takes an optional **display name**;
    the session is `{ name: <entered name or "Reviewer">, email: <slug(name)>@<ALMANAC_IDENTITY_DOMAIN
    or "almanac.local"> }`. This keeps per-reviewer comment attribution while staying a single
    shared-secret gate. (Avatars fall back to deterministic initials — no Google image.)
  - **`ALLOWED_DOMAIN` becomes env-configurable** (default `plow.co`): it gates **Google**
    sign-ins only. The passphrase provider is **not** domain-gated (anyone with the secret is
    in) — that's the whole point of a self-contained public deploy. Set `ALLOWED_DOMAIN` to
    your workspace domain if you use Google; ignore it if you use the passphrase.
  - **Faithfulness / Verify**: this does **not** change the dev journeys — `## Verify` still
    signs in via `test-login` (J1–J27 unchanged). The passphrase path is the prod/public auth
    and is exercised by the `## Deploy (public)` acceptance check, not by the §16 dev journeys.
- **Agent two-header gate** (the three agent endpoints): require **both**
  - `x-vercel-protection-bypass` == `VERCEL_AUTOMATION_BYPASS_SECRET` (layer 1; missing/wrong
    ⇒ **401**), and
  - `x-almanac-agent-key` == `ALMANAC_AGENT_API_KEY` (layer 2; missing/wrong ⇒ **403** on
    POST/DELETE, 401 on the artifact GET).
  Compare with a **constant-time** equal (timing-safe; length-mismatch short-circuits).
- **Per-action authorization**:
  - **Edit comment / delete comment / delete reply**: **author-only** — `authorEmail` must
    case-insensitively match the caller. Non-author ⇒ **403**.
  - **Reposition pin** and **resolve/unresolve**: **open to any signed-in `@plow.co` user**
    (CEO directive — the crit team fixes misplaced pins and resolves regardless of author).
    Repositioning records `movedBy`/`movedAt` (audit, not surfaced yet); tombstoned
    (`deleted`) comments still refuse reposition.

---

## 7. Routes, pages & API surface

### Pages (App Router, all `dynamic = "force-dynamic"`, all gated except /login)

| Path | What it is |
|---|---|
| `/` | **Index**: project list filtered by status. |
| `/login` | Sign-in card (public): a **passphrase field** when `ALMANAC_ACCESS_PASSWORD` is set, and/or a **Google button** when `GOOGLE_*` is set (§6). |
| `/welcome` | Obsolete; 307→`/`. |
| `/p/[projectId]` | **Project page**: option grid + status + rename + add-option (manual only). |
| `/p/[projectId]/[optionId]` | Thin resolver → **redirect to the latest version** of the option. |
| `/p/[projectId]/[optionId]/v/[versionId]` | **VersionViewer** (the core review surface, §8). |
| `/p/[projectId]/v/[versionId]` | **Legacy** 2-level URL → **permanent (308) redirect** to `/p/<p>/<v>/v/v1` (old version slug becomes the option slug). 404 if the option doesn't exist post-discovery. |

### Artifact-serving routes (session-gated, `dynamic = "force-dynamic"`)

> Unauthenticated requests to these get **401**, not a 307→/login: the middleware
> **special-cases `/seed`·`/seed-kv`** (§6) so these asset endpoints fail cleanly for the
> iframe/fetch consumer instead of redirecting an HTML login page into the iframe. The route
> handlers also return 401 themselves (belt-and-braces).

| Path | Serves |
|---|---|
| `GET /seed/[round]/[slug]` | fs artifact HTML. Validates `(round, slug)` against the auto-discovered seed-path list; 404 if unknown; 401 if not signed in. `Cache-Control: private, max-age=0, must-revalidate`. |
| `GET /seed-kv/[projectId]/[optionId]/[versionId]` | kv artifact HTML from `…:version:<v>:html`. 401 if not signed in, 404 if no HTML. **All** responses (incl. failures) sent `Cache-Control: no-store`. |

### Human API (session-gated, `runtime = "nodejs"`)

| Method + path | Contract |
|---|---|
| `POST /api/projects` | **multipart** create manual project + first option + first v1. Fields: `name`, `slug`, `description?`, `optionName`, `optionSlug?`(=`option-1`), `versionSlug?`(=`v1`), `file`(.html). Validates (see §10). 409 on slug collision. Returns `{ project, redirect: /p/<slug>/<optionSlug>/v/<versionSlug> }`. |
| `PATCH /api/projects/[projectId]` | rename project (display-name override). Body `{ name }`. Slug unchanged. |
| `POST /api/projects/[projectId]/status` | set status. Body `{ status }` ∈ active/archived/shipped. |
| `POST /api/projects/[projectId]/options` | **multipart** add option (+ its v1) to a **manual** project only (fs projects 404 here). Fields `name`, `slug`, `versionSlug?`(=`v1`), `file`. Returns `{ option, redirect }`. |
| `PATCH /api/projects/[projectId]/options/[optionId]` | rename option. Body `{ name }`. |
| `POST /api/projects/[projectId]/options/[optionId]/versions` | **multipart** append version. Works on **both** manual & fs options. `file` required; optional `versionSlug` else **auto-increment** to `v<maxN+1>`. Returns `{ versionId, redirect }`. |
| `PATCH /api/projects/[projectId]/options/[optionId]/versions/[versionId]` | rename version. Body `{ name }`. |
| `POST /api/comments` | create pin. Body `{ projectId, optionId, versionId, x, y, body }`. Validates triplet exists, coords in range, body non-empty. Author = session name/email. Returns `{ comment: <thread-shaped> }`. |
| `PATCH /api/comments/[commentId]` | edit body (**author-only**). 404/403/400. Sets `editedAt`, keeps `ts`. |
| `DELETE /api/comments/[commentId]` | delete (**author-only**). **Soft** (tombstone) if the comment has replies; **hard** purge otherwise (see §10). |
| `PATCH /api/comments/[commentId]/position` | reposition (**any signed-in user**). Body `{ x, y, anchorSelector? }`. Tombstones ⇒ 400. |
| `POST /api/comments/[commentId]/resolve` | toggle resolved (**any signed-in user**). Body `{ resolved: boolean }`. Returns `{ resolved, resolvedBy, resolvedAt }`. |
| `POST /api/replies` | create reply. Body `{ commentId, body }`. |
| `DELETE /api/replies/[replyId]` | delete reply (**author-only**). |
| `POST /api/reactions` | toggle reaction. Body `{ target: "comment"|"reply", id, emoji }`. Returns `{ reactions, userReactions }`. |
| `POST /api/heartbeat` | presence beat. Body `{ projectId, optionId, versionId }`. Records the view, returns `{ active: Viewer[] }` (the live <60s roster). |
| `GET/POST /api/auth/[...nextauth]` | NextAuth handler. |
| `GET /api/test-login` | **Dev-only** sign-in bypass (§6). 404 unless `ALMANAC_TEST_LOGIN=1`. `?email=<@plow.co>&next=<path>` → mints the NextAuth session cookie + 302→`next`. The only way to authenticate locally without Google; how `## Verify` signs in. |

### Agent API (two-header gate, `runtime = "nodejs"`) — see §11.

`commentId`/`replyId` path-param validation regex: **`/^[a-f0-9]{16}$/`**. Slug validation
regex: **`/^[a-z0-9][a-z0-9-]*$/`**, max 64. HTML upload cap: **3,670,016 bytes (3.5 MB)**;
`.html` only; over cap ⇒ **413**.

---

## 8. UI / UX spec

### 8.1 Global chrome

- **Top bar** (index + project pages): sticky, chalk, bottom rule. Left: brand
  "`plow` · `almanac`" (serif italic wordmark + small volt dot). Right: signed-in name + a
  **"sign out"** button (`signOut → /login`).
- **Footer**: `plow` wordmark · "internal · seeds · 2026".
- Document title template: `Plow • Almanac · %s`; default `Plow • Almanac`. `robots: noindex,
  nofollow`.

### 8.2 Index `/`

- Hero `projects`. A **status-filter pill nav** (`active` | `archived` | `shipped`), default
  `active`; non-active statuses link to `/?status=<s>`. A **"+ new project"** button opening
  the New Project modal. *(Casing, per the real: mono labels render **uppercase** — the brand
  suffix is `ALMANAC`, the button reads `+ NEW PROJECT`, pills `ACTIVE`/`ARCHIVED`/`SHIPPED`;
  the active pill is **outlined with a status dot**, not solid-filled.)*
- Project rows (filtered by **live** status resolved from KV): a **leading `•` bullet**, then
  the inline-renamable **sans** name (pencil trigger; §9.2 — *not* serif), then — **right-aligned
  on the same row** — `<N> options · <M> pins`, "open →"; and "updated <relative-time>" on a
  second line (latest version mtime across all option/version leaves; "no source on disk" when
  0). Rows are separated by hairlines and sit on a tight rhythm (compact, not airy). Empty
  filter ⇒ "no projects in this status. switch the filter."

### 8.3 Project page `/p/[projectId]`

- Breadcrumb "← all projects". **Click-to-rename `h1`** project title. A **StatusEditor**
  (`active`/`archived`/`shipped` select, optimistic). Lede "`N` options".
- **Manual projects only**: an **"+ add option"** button (AddOption modal).
- **Option grid**: each card = pencil-renamable option name, "open →",
  `<N> versions · <M> pins · <K> reactions` (reactions hidden when 0), "updated <rel>", and a
  compact **ViewerStack** of recent viewers (from the most-recent version). Card links to
  `/p/<p>/<option>` (which redirects to the latest version).

### 8.4 The VersionViewer `/p/[projectId]/[optionId]/v/[versionId]` (the heart)

On load the server records the viewer, then fetches: current-version thread, **cross-version
option thread** (every version's comments, each row tagged with its `versionId`), viewers,
active viewers, an **author-lookup map** (email→{name,image} merged across all versions'
viewers — so a commenter's Google avatar shows on any version), per-(viewer,version) viewer
events, display names, and the version-switcher entries.

**Sticky version-bar header**, left→right:
- Breadcrumb: **`←`** back to project · **project name** (link) · `/` · **option name**
  (link) · `/` · **version name** (click-to-rename `InlineNameEditor`) + a **VersionSwitcher**
  chevron.
- A hint: "**hold ⌥ to comment**".
- A **ViewerStack** (live active viewers, compact).
- A **"+ Comment"** toggle button (enters/exits placement mode; label cycles
  `Comment` → `Drop pin · Esc`).
- An **"Activity"** panel toggle showing a count (`comments + viewers`).

**The artifact iframe**: `src` = the seed/seed-kv URL, `sandbox="allow-same-origin
allow-scripts"`, **fluid** (width/height 100%) so the seed's own media queries fire against
its real rendered viewport (no CSS transform / no fixed 1280px inner width).

**Pin layer** (injected into the iframe document, plain DOM — not React). The pins are an
**overlay drawn into the seed's iframe document**: absolutely-positioned numbered markers,
one per non-resolved comment, placed at the comment's `(x,y)`. This overlay is **the single
most important behavior of the viewer** and the easiest to get wrong — read the iframe-load
requirement first.

> 🔴 **LOAD-BEARING REQUIREMENT — the iframe-load gate (get this right or pins never paint).**
> An `<iframe>` first holds a transient **`about:blank`** document that often reports
> `readyState === "complete"` *before* the real seed HTML loads. If you draw the pin overlay
> (and attach click/drag/cluster listeners) against that blank document, your effect runs
> once on the empty doc and the real artifact later **replaces** it — so the pins attach to a
> dead document and **0 pins ever appear**, even though the data is present and the artifact
> serves fine. This is the #1 observed deep-screen divergence: the panel lists the comments
> but the canvas shows no pins. Implement it exactly so:
> 1. **Do NOT trust `readyState === "complete"`** on the iframe's initial document. Treat
>    `about:blank` as "not loaded yet."
> 2. Keep a **load counter** in React state. On the iframe's **`load`** event, check
>    `iframe.contentDocument.location.href` — **only when it is NOT `about:blank`**
>    (i.e. the real seed document is in) **increment the counter** (and inject the pin
>    `<style id="feedback-pin-style">` then).
> 2.5. **MOUNT CATCH-UP — do not rely on the `load` event alone (this is the exact bug that
>    painted 0 pins).** When `<iframe src={artifactUrl}>` is **server-rendered**, the browser
>    starts fetching immediately and — for a fast same-origin document — the **`load` event
>    can fire BEFORE React hydration attaches your `onLoad` handler**, so `onLoad` never runs,
>    the counter stays `0`, and a pin effect guarded by `if (loadCount === 0) return` always
>    early-returns → **0 pins**. (This is *not* the `about:blank` case — the document is fully
>    loaded; the event was simply missed.) So in an **empty-dep `useEffect(() => {…}, [])` on
>    mount**, check: if `iframe.contentDocument` already exists **and**
>    `contentDocument.readyState !== "loading"` **and** `location.href !== "about:blank"`,
>    **increment the counter immediately** (and inject the style). Keep this **alongside** the
>    `onLoad` handler from step 2 — `onLoad` still covers version switches / post-mount
>    re-loads; the catch-up covers the already-loaded-before-hydration case. *(Equivalent
>    alternative: render the iframe with **no `src`** on the server and assign
>    `iframe.src = artifactUrl` inside a client-side mount `useEffect`, so `load` always fires
>    after `onLoad` is attached. The catch-up approach above is preferred.)*
> 3. **Key the pin-render effect, the click/Alt-click placement listener, the drag handlers,
>    and the clustering effect on that load counter** (put it in the `useEffect`
>    dependency array). They must **re-run on every real (re)load of the artifact and on
>    every version switch**, re-binding to the live `contentDocument` each time. A boolean
>    "loaded" flag is not enough — a counter guarantees re-fire when the document is replaced.
>
> §17 documents this as a failure mode; **this block is the normative requirement** — a
> blind build must paint pins on the first attempt from §8.4 alone.

**How the overlay is painted (mechanism — same-origin direct DOM, NOT postMessage).** This
is the central feature (pin-anchored commenting); specify it exactly so a blind build paints
the stored pins on first load:

- **Same-origin, direct DOM — do NOT use `postMessage`.** The artifact is served from the
  app's own origin (`/seed` · `/seed-kv`) and the iframe is
  `sandbox="allow-same-origin allow-scripts"`, so the parent React component **reads and
  writes `iframe.contentDocument` directly**. The seed HTML is an arbitrary static document
  with **no message listener** — a `postMessage` handshake would get no reply and paint
  nothing. Reach into `contentDocument`, don't message it.
- **The pins live INSIDE the iframe document, not in the parent DOM.** On the real load
  (per the gate above): (1) inject a `<style id="feedback-pin-style">` into the iframe's
  **`<head>`** (the pin CSS must exist in the document the pins live in); (2) ensure a single
  container `<div id="feedback-pin-layer">` appended to the iframe **`<body>`**.
- **Paint = clear + recreate (idempotent), keyed on the load counter AND `comments`.** On
  each run: `layer.innerHTML = ""`, then for **every non-resolved comment** create a
  `doc.createElement("button")` with class `feedback-pin`, set `dataset.id` = comment id and
  `dataset.pinNumber` = its chronological index (1..N), set `style.left = "<x>px"` /
  `style.top = "<y>px"`, set `innerHTML` to the avatar/initials glyph, and append it to the
  layer. (Cluster glyphs for ≤24px-overlapping pins are appended the same way.)
- **Coordinate space = iframe-document pixels.** A comment's stored `(x,y)` are pixels **in
  the seed document's own layout** (the iframe is true-fluid — no CSS scale transform), so the
  pin uses the **raw stored `x`/`y`** with no scale factor. (Placement captures `e.pageX/
  e.pageY` from a click **inside the iframe document**; a drag writes `mouseEvent.pageX/pageY`
  back; `(x,y)` are clamped server-side to `x∈[0,4000]`, `y∈[0,30000]`.)
- **Source of the pins** = the server-provided current-version thread (`readVersionThread`,
  passed in as `initialComments`). The effect paints **all** of them (minus resolved) — so on
  a fresh page load with N existing pins in the store, N numbered markers appear over the
  artifact. The activity panel listing comments while the canvas shows zero pins is the exact
  symptom of skipping this paint (or keying it on `about:blank`).

The overlay itself:
- Each non-resolved comment → a **24px circular pin**, volt (`#d5ef8a`) fill, midnight
  (`#01000a`) 1.5px border, DM-Mono, **absolutely positioned**, centered on the comment's
  `(x,y)` (iframe-document px) via `translate(-50%,-50%)`, `z-index` very high. The glyph is
  the author's **Google avatar image** (round, cover) or **deterministic-color initials**
  fallback. `data-pin-number` = chronological index (1..N), shown/derivable for the panel.
- **Resolved** comments **hide their pin** from the canvas (the row stays in the panel under
  the "resolved" filter); unresolve re-renders it (the effect re-runs when `comments` change).
- **Hover** opens the pin popover (with a ~350ms close grace); **click** opens it (a real
  drag suppresses the click).
- **Drag to reposition** (any signed-in user): `data-draggable="1"`, `cursor:grab`; drag
  threshold **4px** distinguishes drag from click; on drop, make the pin transparent to
  `elementsFromPoint`, find the seed element under the drop, build a durable CSS
  **anchor selector** (`#id` shortcut else `tag:nth-of-type(n)` path up to body, ≤12 deep),
  optimistically move + PATCH `/position`; rollback snaps the pin home on failure.
- **Clustering**: pins whose centers fall within **24px** of each other collapse into one
  **cluster glyph** (30px midnight square, top author's avatar + a `+N` count badge). Clicking
  a cluster opens a floating **pop-list** (rendered in the parent document) of its member
  pins; picking one opens that pin's popover. (The cluster effect is also keyed on the load
  counter — see the requirement above.)

**Placement modes**:
- **"+ Comment" toggle** = **sticky** placement (drop many pins; stays armed after each
  post/cancel). **Option/Alt + click** = **single-shot** placement. Cursor becomes a
  crosshair in placement mode. **Esc** exits.
- Clicking the artifact in placement (or Alt+click anytime) opens a **Composer** popover at
  the click point: shows the author + "placing pin", a "Leave a note" textarea (Enter posts,
  Shift+Enter newline, max 2000), `cancel` / `post pin`. Posting is optimistic.
- The bare **`c` key shortcut was intentionally removed** (too easy to trigger while reading);
  the only entry points are the toggle and Alt+click.

**Pin popover** (Figma-style): avatar + display name + relative ts (+ "· edited" flag);
an action row (only when not deleted): **add-reaction** (☺+ opens the EmojiPicker), **✓
resolve** toggle (`aria-pressed`), and a **⋯ CommentMenu** (Edit / Delete — author-only).
Body is **linkified** plain text (URLs → real `<a target=_blank rel=noopener>`; never raw
HTML). Below: reaction chips (toggle, `data-mine`), a "✓ resolved" tag when resolved, the
**replies thread** (each reply: author · ts, body, reactions; author sees a `⌫` delete), and
a **reply composer** (Enter sends). Tombstoned comment body renders
`[comment deleted by author]`.

**Delete UX**: deleting a comment or reply removes it optimistically and shows a bottom
**Undo toast** for **5000 ms** ("Comment deleted" / "Reply deleted" + "Undo"). The DELETE
fires only after the window elapses (undo cancels it). Failure restores the row + surfaces an
error.

### 8.5 Activity panel (right drawer, Figma-style)

- Toggled by the header "Activity" button **or the `a` key** (when not typing); open-state
  **persisted in `localStorage` key `almanac.panel.open`** (`"1"`/`"0"`).
- Header: "Comments `<matched>` of `<total>`", a **search** (author/body, with clear), a
  **state filter** (`all` | `open` | `resolved`), a **sort** (`recent` | `reactions`), and —
  when the option has >1 version — a **version-chip multi-select** (empty = all; `clear`).
- Feed = the **cross-version option thread interleaved with viewer events** (viewer rows show
  only under the `all` filter), sorted by ts (or by reaction-total for comments under
  `reactions` sort). Each comment row: avatar, **`#<pinNumber>`** (chronological within its
  version) + a **version chip** (highlighted when current), action row (react / resolve /
  edit-delete), author · ts (+ edited), body, reaction chips, resolved tag, and an action
  link — **"jump to pin"** when the row is on the current version (scrolls the iframe so the
  pin sits ~⅓ down + a 900ms flash-pulse), else **"open <versionId>"** linking to that
  version. Replies are collapsible (`N replies ▾`). Viewer rows read "`<name>` viewed
  `<versionId>` · <rel>".
- Empty: "No activity matches the active filter." + the ⌥-click hint.

### 8.6 VersionSwitcher

A compact chevron dropdown in the version bar listing **all versions of the current option**,
newest-first, the current one marked (`✓`, "current", non-clickable), the newest tagged
"latest". Each row shows label + slug + uploader · relative time, and a **download `↓`**
button that fetches the version HTML and triggers a browser download named
`<project>-<option>-<version>.html`. A **"+ Add version"** action at the bottom opens the
AddVersion modal (auto-increments `v<N+1>`, uploads, redirects). With a single version and no
add action, the compact switcher renders nothing.

### 8.7 Modals (New Project / Add Option / Add Version)

Backdrop + card, Esc/backdrop-click to close (unless busy), focus first field on open.
- **New Project**: project name → auto-kebab slug (editable, shows `/p/<slug>`), optional
  description, a **first option** fieldset (option name → auto-kebab option slug), and an
  **html file** ("becomes v1"). Submits multipart; on success `router.push(redirect)`.
- **Add Option** (manual projects): option name → auto-kebab slug (skips if taken),
  html file. Default slug auto-numbered `option-<n>`.
- **Add Version**: just an html file; header shows the preview slug `v<N+1>`; uploads under
  the current option and redirects.

### 8.8 Inline rename (InlineNameEditor) & StatusEditor

- **InlineNameEditor**: `click` or `pencil` trigger. Edit → PATCH the given endpoint with
  `{ name }` → on success `router.refresh()` (so sibling server-rendered surfaces repaint).
  Enter commits; Esc rolls back; empty/unchanged is a silent no-op. **Slug never changes** —
  only a display-name override is stored.
- **StatusEditor**: a `<select>` (active/archived/shipped); optimistic POST with rollback.

---

## 9. Design system (reproducible spec — get the *feel* right, not just the tokens)

> **Why this section is long.** A correct rebuild is not just the right colors — it's the
> right **fonts + weights**, the **micro-interactions** (every interactive element lifts,
> tints, or reveals on hover), the **transition feel** (one shared easing, a small set of
> durations), and a consistent **shadow/spacing/radius rhythm**. The real app is a light,
> editorial, Plow-branded surface where *everything moves a little* on hover and nothing
> moves a lot. Reproduce the **values and rules** below; you do not need the original CSS.

### 9.1 Palette (exact)

- **Brand**: `--midnight #01000a` · `--volt #d5ef8a` (lime accent) · `--grove #5e7a5e` ·
  `--grove-light #e8ede8` · `--grove-deep #4a6149` · `--iris #c4bfff`.
- **Surfaces**: `--chalk #fafaf7` (page bg) · `--oat #f3f3ee` (hover/secondary fill) ·
  `--card-bg #ffffff` · `--card-border #e5e5e0` · `--card-border-deep #d7d7cf` ·
  `--rule #eceae2` (hairline dividers).
- **Text**: `--text #212121` · `--text-emphasis #181818` · `--text-muted #6b6b6b` ·
  `--text-light #8e8e8e`. **Semantic**: `--danger #ff3b30`.
- **Derived hover shades (exact)**: midnight button hover `#15131f`; volt button hover
  `#c4e07b`; volt-tint hover wash `rgba(213,239,138,0.32)`; volt focus-ring
  `rgba(213,239,138,0.40–0.45)`.
- The app is a **light theme**. `::selection` = volt bg / midnight text.

### 9.2 Typography (the fonts are part of the brand — pin them)

Three families, **loaded from Google Fonts via a `<link>`** in `<head>` (with
`preconnect` to `fonts.googleapis.com` + `fonts.gstatic.com`). Load **these exact weight
axes** — the wrong weights are the single biggest cause of "the fonts look off":

```
family=DM+Mono:wght@400;500;600
&family=DM+Sans:wght@400;500;600;700
&family=Instrument+Serif:ital@0;1   ← both upright AND italic
&display=swap
```

- **`--serif`** = `'Instrument Serif', Georgia, serif`, weight **400**, **italic**. Its use
  is **deliberately narrow — ONLY these five surfaces**: the index hero `h1` ("projects"),
  the project-head `h1`, the auth wordmark, the top-bar brand wordmark ("plow"), and the
  footer wordmark. Do **not** bold it (the face is light by design).
  > ⚠️ **OBSERVED DIVERGENCE #1 — do not repeat.** A prior rebuild applied serif italic to
  > **project / option / version row names**. That is **wrong**. Row/list/card item **names
  > are `--sans`** (see below), NOT serif. "Display heading" means the big page titles in
  > the five surfaces above and nothing else. If a name sits inside a list row, a card, a
  > breadcrumb, or a switcher, it is **sans**.
- **`--sans`** = `'DM Sans', system-ui, -apple-system, sans-serif` — body, buttons,
  comment text, breadcrumbs, **and every list/card item name** (project rows, option cards,
  version names). Base body = **15px / line-height 1.55**, weight 400; **item names = DM Sans
  500, ~22px, style `normal` (never italic)**; strongest 600–700.
- **`--mono`** = `'DM Mono', 'SF Mono', Consolas, monospace` — all meta/labels/counts:
  pins, version-bar hint, breadcrumb separators, status pills, eyebrows, `.kbd`, footer,
  viewer counts.
- Degrade gracefully to the system fallbacks offline.

**Label casing (OBSERVED DIVERGENCE #2 — pin it).** `text-transform: uppercase` (with
**letter-spacing 0.04–0.12em**) is applied to a **specific set of chrome labels — NOT to
every mono element.** Uppercase exactly these (markup may be lowercase; rendered = caps):
the brand suffix **`ALMANAC`** (next to the serif "plow"), the status filter pills
**`ACTIVE` / `ARCHIVED` / `SHIPPED`**, the **`+ NEW PROJECT`** CTA, eyebrows
("← ALL PROJECTS"), the footer line, `.kbd`, the project-status chip, and the
micro/gate-micro lines. A prior rebuild left these lowercase — reproduce them **uppercased**.
- **Do NOT uppercase (mono, but lowercase / as-authored):** the **`sign out`** link in the
  top bar (plain mono, lowercase — ⚠️ a rebuild uppercased it to "SIGN OUT"; it must stay
  lowercase), the version-bar **hint** ("hold ⌥ to comment"), row **meta/counts**
  ("2 options · 0 pins"), relative **timestamps** ("updated 7d ago"), and viewer counts.
  These are mono UI text, not chrome labels — leave their casing alone. Rule of thumb:
  uppercase the **named chrome labels above**; everything else mono renders as written.
- **Do NOT uppercase (other):** serif wordmarks ("plow", "projects") render as-authored;
  and **proper names** — the signed-in user's name in the top-bar identity pill renders
  **Title-case** ("Daniel", in an oat-filled `999px` pill with a hairline border,
  `padding 4px 10px`), **not** "DANIEL" and not "daniel". Comment author names, viewer
  names, and project/option titles are shown as stored (the project *name* is sans, see
  above), not force-cased.

**Type scale (exact sizes / weights / tracking):**

| Role | Family / style | Size · weight · tracking |
|---|---|---|
| Hero `h1` (index "projects") | serif italic | **52px** · 400 · `-0.01em` · lh 1.05 (→ **36px** ≤720px) |
| Project-head `h1` | serif italic | **42px** · 400 · lh 1.05 |
| Auth wordmark | serif italic | **38px** · 400 · lh 1 |
| Brand wordmark (top bar) | serif italic | **22px** · 400 |
| Footer wordmark | serif italic | **18px** |
| Project-row / option-card / version name | **sans (DM Sans), style normal — NOT serif/italic** | **22px** · 500 · `-0.005em` |
| Body / comment text | sans | **15px** (comments ~14px) · 400 · lh 1.55 |
| Breadcrumb | sans | **14px**; parents 400 muted, current 500 midnight |
| Meta / counts | mono | **12px** · `0.02em` |
| Eyebrow / status pill | mono uppercase | **11px** · `0.08–0.12em` |
| `.kbd`, micro, gate-micro | mono uppercase | **10px** · `0.04–0.1em` |

### 9.3 Motion — one easing, a small duration ladder (this is the missing "feel")

**Every** transition uses **`ease-out`**. Durations come from a fixed ladder — match them:

- **180ms** — the **default** for almost everything (color, background, transform, border).
  When unsure, use `…180ms ease-out`.
- **160ms / 150ms / 140ms** — tighter micro-interactions (small icon buttons, chips,
  emoji-cell, menu items, focus rings).
- **220ms** — layout-scale motion: the activity-panel slide (`padding-right`) and the
  undo-toast entrance.
- **120ms** — snappy taps.
- **1200ms ease-in-out, infinite** — the *provisional* (placing) pin pulse only.

**Keyframes (4, exact behavior):**
- `pop-in` (popovers/menus): **180ms ease-out both**, `opacity 0→1` + `translateY(-4px)→0`.
- `undo-toast-in`: **220ms ease-out**, `opacity 0→1` + `translate(-50%,8px)→(-50%,0)`.
- `pin-pulse` (provisional pin): scale `1 ↔ 1.12` at 50%, around `translate(-50%,-50%)`.
- `sheet-up`: mobile bottom-sheet entrance for the panel (slide up).

**Hover/active/disabled rules — apply consistently (this is what "felt missing"):**

| Element | hover | active / state |
|---|---|---|
| Primary button `.btn` (midnight) | `translateY(-1px)` + bg→`#15131f` | active `translateY(0)` |
| Volt button | bg→`#c4e07b` | — |
| Secondary button | bg→`--oat` | — |
| "+ Comment" toggle | bg→`--oat` + `translateY(-1px)` | active = **volt fill**, midnight border |
| "+ new project" CTA (midnight pill) | `translateY(-1px)` + bg→`#1a1923` | — |
| Breadcrumb crumb | text→midnight + **volt-tint wash** `rgba(213,239,138,0.32)` bg | current = midnight 500, no hover |
| Project-row | **`padding-left: 8px`** (whole row nudges right) | — |
| Project-row arrow ("open →") | color→midnight + **`translateX(4px)`** | — |
| Version/option card | border→midnight + **`translateY(-2px)`** + shadow deepens | — |
| Card "open →" | color→midnight + `translateX(3px)` | — |
| Inline-rename **pencil** | **revealed only on row/card hover** (hidden at rest) | — |
| Status filter pill | inactive text → midnight on hover | See the **concrete spec** below the table (⚠️ DIVERGENCE #4) — base pill shape + inactive vs active values must all be pinned, not just the active colors. |
| Status chip (project-head) / select | border → midnight | disabled select `opacity 0.55`, cursor progress |
| Small icon buttons (react ☺+, ✓ resolve, ⋯) | bg/oat tint | resolve `[data-active]` = volt/midnight |
| Text input / textarea | — | `:focus` border→midnight; some inputs add a **volt focus-ring** `0 0 0 3px rgba(213,239,138,0.45)` |
| Identity "who" / sign-out, footnotes | muted→midnight | — |

Rule of thumb to converge: **interactive = lifts (`translateY(-1px..-2px)`), tints (oat or
volt-wash), or reveals (pencil/arrow), on a 180ms ease-out.** Directional affordances
("open →", "← back") **translate** toward their direction on hover.

**Status filter pills — concrete values (⚠️ DIVERGENCE #4, pin all three layers).** The
failure mode here is pinning only the *active colors* and losing the **pill shape**. Specify
the **base** so the rounded outline survives in every state:

- **Base `.status-pill` (ALL states)** — `display:inline-flex; align-items:center; gap:8px`,
  **`border-radius: 999px`**, padding **`7px 14px`** (left a touch tighter for the dot, ~11px),
  **`border: 1px solid transparent`** (reserves the outline's space so nothing shifts when it
  activates), mono **uppercase 11px**, `letter-spacing 0.08em`. Always carries a leading
  **dot** (7px circle).
- **Inactive** — `color: var(--text-muted)`; background **transparent**; border stays
  `1px solid transparent`; the dot is muted (`--text-light`). It's a pill-shaped hit-area
  that reads as plain text until hovered (hover → `color: --midnight`).
- **Active (`[data-active="true"]`)** — `color: var(--midnight)`; **`background: #ffffff`**
  (`--card-bg`); **`border-color: var(--midnight)`** (now a visible 1px dark outline, radius
  already 999px); the dot is colored by status: **`--volt`** (active, with a 1px midnight
  ring) / **`--text-muted`** (archived) / **`--grove`** (shipped).
- So the active tab is a **rounded white pill with a thin dark outline + a colored dot** —
  **not** a solid fill, and **not** bare text. A first rebuild made it a solid volt fill; a
  later one dropped the border + radius (transparent bg, `border-width:0`, `radius:0`). Both
  wrong — the base radius/border-reserve above prevents that.
- (Distinct from the **"+ Comment" toggle**, which genuinely *is* a volt fill when active —
  don't conflate the two pill styles.)

### 9.4 Geometry, spacing & shadows

- **Radius**: `--radius-sm 4px` (crumbs, kbd, small chips) · `--radius 8px` (inputs) ·
  `--radius-lg 12px` (cards, popovers, modals) · **`999px`** for all pills/buttons/avatars.
- **Borders**: hairlines use `--rule`; cards `--card-border`; emphasized `--card-border-deep`
  or `--midnight` (1px, except pins/volt buttons at **1.5px** midnight).
- **Spacing rhythm** (reproduce the rhythm, not pixel-pedantic): page frame max-width
  **980px** (`.wide` 1180px), `padding 0 24px`. Top bar / version bar min-height **56px / 52px**.
  Hero pad `56px 0 24px`; project-head `40px 0 8px`; project rows `22px 0` with a bottom
  `--rule`; card grids `gap 20px`, cards `padding ~22px 24px`; buttons `7–11px × 14–18px`;
  pills `7px 14px`. Activity panel = **340px** desktop drawer (iframe reflows via
  `padding-right`), bottom-sheet ≤720px.
- **Shadow ladder (exact — soft, midnight-tinted, low-spread):**
  - Pin (rest): `0 2px 6px rgba(1,0,10,0.18)`; dragging: deepen to `0 8px 18px rgba(1,0,10,0.32)`.
  - Card hover: `0 14px 30px rgba(1,0,10,0.08→0.18)`.
  - Popover / dropdown menu: `0 14px 40px -8px rgba(1,0,10,0.18), 0 2px 8px rgba(1,0,10,0.06)`.
  - Activity panel (left edge): `-14px 0 32px -16px rgba(1,0,10,0.18)`.
  - Cluster pop-list / undo toast: `0 16px 36px -10px rgba(1,0,10,0.32)`.
  - Modal card: `0 24px 60px rgba(1,0,10,0.22)`.
  - Focus ring (volt glow): `0 0 0 3px rgba(213,239,138,0.40–0.45)`.

### 9.5 Film-grain overlay (brand signature — non-negotiable)

A fixed full-viewport `body::after`: `z-index 1000`, `pointer-events:none`,
`opacity 0.025`, `mix-blend-mode:multiply`, painted from an **inline SVG `feTurbulence`
data-URI** (`baseFrequency 0.85`, `numOctaves 2`, near-black at low alpha) so **nothing is
fetched**. Subtle but present on every page.

### 9.6 Pins, clusters & avatars (canvas identity)

- **Pin**: 24px circle, **volt fill**, **1.5px midnight border**, DM-Mono 11px,
  `translate(-50%,-50%)` centering, very high z-index, rest shadow `0 2px 6px rgba(1,0,10,.18)`.
  `:hover` scale **1.12**; `[data-dragging]` scale **1.18** + deep shadow + `cursor:grabbing`;
  `.provisional` (placing) = white + **dashed** border + `pin-pulse`; `[data-resolved]` =
  grove-light bg / grove text / **0.7 opacity** (→1 on hover); `[data-flash]` = **900ms** volt
  outline flash (jump-to-pin).
- **Cluster glyph**: 30px **midnight square** with the top member's round avatar inset + a
  small **volt `+N`** count badge bottom-right.
- **Avatars** (pins, popover, panel, viewer stack): a Google profile **image** (round,
  `object-fit:cover`) when present, else **deterministic-color initials**. Color =
  `hsl(<hash(email||name)> % 360, 40%, 70%)`. Initials: one word → first 2 chars upper;
  ≥2 words → first + last initial. Sizes: pin glyph 24px; `.fig-avatar.lg` **36px** /
  `.fig-avatar.sm` **24px**; viewer-stack avatars overlap with a `+N` overflow past 5.

### 9.7 Emoji — two scopes

- **Quick reactions** (the canonical `EMOJI` set used for aggregate rollups): exactly
  **`["👍","👎","🔥","🤔","❤️"]`**.
- **EmojiPicker** (the add-reaction surface): a curated **in-house set (~80 emoji)** across
  three categories ("Smileys & People", "Hearts & Reactions", "Symbols"), substring keyword
  **search**, and a **"Frequently used"** row backed by `localStorage` key
  `almanac.emoji.freq.v1` (max 12). **No emoji-picker library** (keeps the bundle lean).
  Picking closes the picker. Emoji cells tint on hover (~140ms).

### 9.8 List rows & density (OBSERVED DIVERGENCE #3 — the index "felt different")

The real index reads as a **dense, editorial list** — compact rows, hairline dividers, the
metadata on the row's baseline (not stacked) — and a prior rebuild rendered it **airy and
stacked**. These are reusable *list-row* rules (apply to any project/option/version list):

- **Bullet marker.** Each project-row name is preceded by a **small muted bullet `•`** as a
  list affordance — visible in the real surface. Reproduce it as a leading marker on every
  row name (a `name::before { content: "•" }` in `--text-light`, or an equivalent leading
  glyph). ⚠️ A prior rebuild omitted it. *(Implementation note: in the reference build the
  marker is part of the list rendering rather than an explicit literal in the row markup —
  match the **visual**, however you render it.)*
- **Row layout = one baseline, not a stack.** A project row is a **horizontal grid**:
  `[ • name ]  [ N options · M pins ]  [ open → ]` all aligned on the **same baseline**
  (`grid-template-columns: 1fr auto auto`, `align-items: baseline`, gap ~24px). The
  `updated <rel>` line is the **only** thing that wraps to a **second line** below
  (`grid-column: 1 / -1`, small mono, `--text-light`). ⚠️ Do **not** stack `options · pins`
  beneath the name — that was the divergence.
- **Density / rhythm.** Rows are **compact with hairline dividers**: each row
  `padding: 22px 0` with a `border-bottom: 1px solid --rule`; the list is a plain flex
  column (no card chrome). The result is many rows visible at once (≈6+ on a laptop), not 2.
  Counts/meta are **mono 12px**; the name is **sans 22px/500** (per §9.2 — *not* serif).
- **Hover** (per §9.3): the whole row nudges `padding-left: 8px` and the "open →" arrow
  slides `translateX(4px)` — both 180ms ease-out; the rename pencil appears only on hover.

### 9.9 Rich surfaces — popover / activity panel / cluster (DIVERGENCE #5: under-detailed)

The real stylesheet is ~520 rule-blocks / 73 hovers; the interactive surfaces carry most of
that. Reproduce these states so the review UI doesn't read as a thin sketch:

- **Pin popover** (Figma-style, rendered in the parent doc): fixed, **width 360px**,
  `--card-bg`, 1px `--card-border-deep`, radius 12px, shadow
  `0 14px 40px -8px rgba(1,0,10,.18), 0 2px 8px rgba(1,0,10,.06)`, entrance `pop-in 180ms
  ease-out`. Header row: 36px avatar (`.fig-avatar.lg`) · author (sans 500) · relative ts (+
  "· edited"). An **action row that is revealed/affirmed on hover** of the comment: a
  **react** button (`☺` + a small `+`), a **✓ resolve** toggle (`[data-active]` → volt/
  midnight when resolved), and a **⋯ menu** (Edit/Delete, author-only). Body is linkified
  sans ~14px. Reaction **chips** toggle (`data-mine` = volt-tinted, `aria-pressed`). A
  "✓ resolved" tag when resolved. Replies nested below (24px `.fig-avatar.sm`), then a reply
  composer. Tombstone renders `[comment deleted by author]` in muted italic.
- **Activity panel**: a **340px** right **drawer** on desktop (the `.viewer` reflows via
  `padding-right: 340px`, 220ms ease-out), left-edge shadow `-14px 0 32px -16px rgba(1,0,10,
  .18)`; a **bottom-sheet** (`sheet-up`) ≤720px. Header: "Comments `<n>` of `<total>`",
  search, state pills (all/open/resolved), sort (recent/reactions), version chips. Each feed
  row carries a `#<pinNumber>` + a **version chip** (`data-current` highlighted). Same
  hover-revealed action row as the popover. Pills/chips use the standard tint/outline states.
- **Cluster pop-list**: floating list (parent doc), shadow `0 16px 36px -10px rgba(1,0,10,
  .32)`; rows = member avatar + author + body snippet; hover-tinted; Esc / outside-click
  closes. The cluster **glyph** itself: 30px midnight square, inset round avatar, volt `+N`
  badge (per §9.6).
- **Modals** (new project / add option / add version): backdrop + centered card,
  radius 12px, shadow `0 24px 60px rgba(1,0,10,.22)`; inputs get the **volt focus-ring**
  `0 0 0 3px rgba(213,239,138,.45)`; primary submit = midnight pill (lifts on hover).

---

## 10. Business rules & edge cases (must handle)

- **Auth domain**: only `@plow.co`; Google Workspace "Internal" + a server `signIn` check;
  `?error=AccessDenied` on `/login` renders "Almanac is only for @plow.co accounts."
- **Authorship**: edit/delete comment + delete reply are **author-only** (`authorEmail`
  case-insensitive). Reposition + resolve are **open to any signed-in user**.
- **Soft vs hard delete**: deleting a comment **with replies** → **soft** (blank body,
  `deleted:true`, clear its reactions + resolved state; replies stay so the thread reads
  coherently; pin renders the tombstone). **Childless** comment → **hard** purge (remove from
  canonical + legacy lists, delete the row, replies list, resolved, reaction keys).
- **Coordinate clamps**: comment create + reposition require finite `x∈[0,4000]`,
  `y∈[0,30000]`; out of range ⇒ **400 "bad coordinates"**.
- **Body limits**: human comment/reply `clampBody` to **2000** (UI textarea `maxLength=2000`);
  agent body clamps to **4000**.
- **Slugs**: `/^[a-z0-9][a-z0-9-]*$/`, max 64; kebab-cased client-side; collisions ⇒ **409**.
- **Manual-only mutation**: adding an **option** via the UI works only on manual projects (fs
  projects 404 — those go through the external `publish-to-almanac` flow). Adding a **version**
  works on **both** (a kv version can stack on an fs option).
- **Version auto-increment**: scan existing slugs for the highest `v<N>` (across both the kv
  list and the discovered option versions) → `v<N+1>`; explicit slug must be unique (409).
- **Latest-version resolution** (`/p/<p>/<o>` redirect): descending mtime, ties broken by
  slug descending (so v3 beats v2).
- **Legacy URL**: `/p/<p>/v/<v>` → **308** to `/p/<p>/<v>/v/v1`; 404 if option missing.
- **Legacy data fallback**: every `(p,o,v)` read falls back to the 2-level `(p,o)` key when
  the canonical key is empty **and** `v === "v1"`; legacy comment rows back-fill the triplet
  on read.
- **Optimistic + rollback**: post pin, reply, edit, delete (with 5s undo), reposition,
  resolve, react, status, rename — all update locally first and **revert on a non-OK
  response**, surfacing the error text.
- **Presence**: heartbeat every **20s** while the tab is **visible** (Page Visibility API;
  pause when hidden, beat immediately on becoming visible). Live window **60s**.
- **iframe robustness**: ignore the transient `about:blank` document; re-bind pin/cluster/
  click/scroll effects when the real seed document loads (load-counter, not a boolean).
- **Reactions cleanup**: a count hitting 0 is removed from the hash so empty chips don't
  dangle; `userReactions` is per-caller.
- **Security headers**: `X-Frame-Options: DENY` + `frame-ancestors 'none'` on everything
  **except** `/seed/` and `/seed-kv/` (those must be frameable same-origin) — applied in
  `next.config.js` `async headers()`/middleware (portable), **not** vercel.json (see §2).
- **Agent comment is identical KV shape** to human comments (+ `agentAuthored:true`,
  `authorAvatar`, optional `anchorText`), so it shows in the same pin path, activity feed and
  rollups with zero read-side merge.

---

## 11. Agent API surface (the non-human reviewer contract)

All three require the **two-header gate** (§6). `runtime = "nodejs"`. Slugs validated
`/^[a-z0-9][a-z0-9-]*$/`; commentId `/^[a-f0-9]{16}$/`.

**`GET /api/agent-artifact/[project]/[option]/[version]`** — the **read** surface. Resolves
the triplet (404 if absent), loads the HTML (fs or kv; 404 if none), and returns JSON:
`{ html, comments (full thread, userReactions empty for the anonymous agent), activity,
candidate_anchors, candidate_anchors_cache: {hash, cached}, project_meta, option_meta,
version_meta }`. **`candidate_anchors`** is a cheerio-extracted, KV-cached list (cap **50**)
of pin-able elements — `{ selector, tag, classes, text_preview (≤120 chars), bbox: null,
bbox_reason: "cheerio_fallback" }` — ranked by text length, drawn from an interest set
(`section, article, aside, nav, header, footer, main, [data-pin-anchor], .card, .deps,
.release, .feature, h1, h2, h3, figure, blockquote`).

**`POST /api/agent-comments`** — **write** a pin. JSON body: `author` (≤80), `avatar?`
(≤256; defaults to `author[0]`), `project`, `option`, `version`, `body` (≤4000), and a
**position** via one of (priority order): **`anchorText`** (≤400) → **`anchorSelector`**
(≤512) → **`x,y`** → sentinel. Requires at least one of those three (else **400**).
Position resolution:
1. **anchorText** → cheerio finds the **smallest containing element** (deepest normalized-text
   match, ties by DOM order); persists text + a derived selector + projected `x,y`. **No
   match ⇒ 400** with a `candidates` array (word-overlap-scored nearby snippets) so the agent
   can retry.
2. **anchorSelector** → cheerio resolves a position (depth-first index projected onto an
   estimated doc height); unresolved ⇒ a sentinel `(320,200)`.
3. **x,y** → used directly (clamped).
4. none → sentinel.
Seeds are treated as **1280px** natural width; selector/text-resolved pins center at
`x = 640`, `y` projected from DOM order (top margin 120, est. height 3200). Returns
`{ commentId, url: https://almanac.plow.co/p/<p>/<o>/v/<v>#pin-<id> }`, `Cache-Control:
no-store`.

**`DELETE /api/agent-comments/[commentId]`** — prune an **agent-authored** comment. Requires
an `x-almanac-agent-author` header; the server compares it (case-insensitively) to the row's
`author` (a **soft** anti-footgun, not a real boundary). Refuses human comments
(`agentAuthored !== true` ⇒ **409 not-agent**); wrong author ⇒ 403; missing ⇒ 404.

**`PATCH /api/agent-comments/[commentId]`** — toggle an agent comment's **resolved** flag
(default `true`; `{resolved:false}` to un-resolve). **No** author check (matches the open
resolve model). Optional `x-almanac-agent-author` → written as the resolve `by` provenance
(else `"agent"`). Refuses human comments (409).

---

## 12. Inputs (Interview)

> **Default posture = stranger / paste-and-run.** Assume the implementer has **nothing
> pre-installed** beyond a shell + `claude` — no Node, no Playwright browsers, no system libs,
> no Google credentials, no harness-minted auth. The `## Steps` section below **installs or
> creates everything** in this table that is marked "seed installs". Inputs the user must
> still supply (real Google OAuth, real KV) are only needed for **production**, never to build
> + verify locally.

| name | required | default | detect | ask / how the seed satisfies it |
|---|---|---|---|---|
| Node.js ≥ 18.17 + npm | yes | — | `node -v` (≥18.17; Next 14 needs it) | **Seed installs if absent/old** (Steps §1): nvm, or the distro's nodesource/`apt`/`brew`. Do not assume it's present. |
| Chromium + OS libs for Playwright | yes (for Verify) | — | `npx playwright install --dry-run` shows chromium present | **Seed installs** (Steps §5): `npx playwright install --with-deps chromium` (downloads the browser **and** apt-installs libnss3/libatk/libgbm/etc). ⚠️ Without this, `npm run e2e` fails "Executable doesn't exist". |
| `coreutils` / `curl` / `openssl` | yes | — | `command -v curl openssl` | Standard on most bases; Steps installs via the host pkg mgr if missing. (No `ffmpeg`/`jq` needed — Verify uses none.) |
| `cookoff-seeds/` corpus | yes | **seed creates an example if absent** | `ls cookoff-seeds/*/*.html` | **Seed self-seeds** (Steps §4): if the dir is empty/missing, write an example `cookoff-seeds/seed/v1.html` (a small valid HTML doc) so auto-discovery surfaces ≥1 project and the app is navigable from a bare paste. |
| `NEXTAUTH_SECRET` | yes | **seed auto-generates** | env set | If unset, Steps generates one (`openssl rand -base64 32`) into `.env.local`. Signs the session JWT (incl. the dev-login token). |
| `ALMANAC_TEST_LOGIN` | yes (dev/verify) | **`1` in dev `.env.local`** | env set | Enables `GET /api/test-login` (§6) so the app is loggable as `@plow.co` **without Google**. Steps sets it to `1` for local build+verify; it MUST be unset in prod. |
| `ALMANAC_ACCESS_PASSWORD` | **yes for a public deploy** | none | env set | The **production passphrase** (a strong secret). Enables the NextAuth Credentials login (§6) so a stranger's public deploy has real, Google-free auth. Unset in plain dev (Verify uses `test-login`). |
| `ALMANAC_IDENTITY_DOMAIN` | no | `almanac.local` | env set | Email domain used to synthesize the passphrase-session identity (`<slug(name)>@<domain>`) for comment attribution (§6). Cosmetic. |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | conditional (**SSO option**) | none | env set | Optional Google OAuth (domain-gated by `ALLOWED_DOMAIN`). **Not needed** — the passphrase login (above) covers a public deploy with no Google. Use only if you want real per-user SSO. |
| `ALLOWED_DOMAIN` | no | `plow.co` | env set | Email-domain gate for **Google** sign-ins only (§6). Set to your workspace domain if using Google; ignored by the passphrase provider. |
| `NEXTAUTH_URL` | conditional (prod) | `http://localhost:3210` | env set | Public base URL of the deploy. Local default is fine for build+verify. |
| `KV_REST_API_URL` + `KV_REST_API_TOKEN` | no (dev) / yes (prod) | none → in-memory store | both env set | Vercel KV. **Absent ⇒ in-memory fallback** (per-process, non-durable) — fine for build+verify. Provision for shared/prod use. |
| `ALMANAC_AGENT_API_KEY` | conditional (agent door) | **seed sets a dev value** | env set | Steps sets a throwaway value in `.env.local` so the agent-endpoint journeys (J20–J22) can run locally. Use a real secret in prod. |
| `VERCEL_AUTOMATION_BYPASS_SECRET` | conditional (agent door) | **seed sets a dev value** | env set | Same — Steps sets a dev value locally; layer-1 of the agent gate. |

**Step 0 — Interview (mandatory):** detect each row; send the user ONE consolidated message
listing ✓ satisfied / ✗ needed (with the `ask`) / ⚠ prior state to confirm (e.g. an existing
KV with data the rebuild would read). For a stranger with nothing installed, the honest
message is short: "I'll install Node (if needed), the npm deps, and the Playwright browser +
its OS libs; auto-generate dev secrets + an example seed; you need supply **nothing** to build
and verify locally." Then build autonomously through `## Steps` → `## Verify` → §16.

---

## 13. Components (what this seed assembles)

| Component | Source | Notes |
|---|---|---|
| Next.js 14 + React 18 + TypeScript | npm | App Router, `strict`, port 3210 |
| `next-auth` v4 + Google provider | npm | JWT session, `@plow.co` gate |
| `@vercel/kv` | npm | prod store; in-memory `Map` fallback in dev |
| `cheerio` | npm | server-side anchor/candidate resolution (agent surface) |
| `@playwright/test` + **its chromium browser & OS libs** | npm (dev) + `npx playwright install --with-deps chromium` | E2E (`npm run e2e`). The browser/libs are **installed by Steps §5**, not assumed present. |
| `GET /api/test-login` dev-auth route | inline (built from §6) | env-gated (`ALMANAC_TEST_LOGIN=1`) sign-in bypass so the app is loggable + verifiable with no Google. |
| Google Fonts: Instrument Serif, DM Sans, DM Mono | CDN | preconnect + stylesheet in `<head>`; degrades to system fallback offline. |
| `cookoff-seeds/` HTML corpus | repo/input, **or seed-generated example** | auto-discovered; Steps §4 writes an example `seed/v1.html` if absent. |
| Security headers in **`next.config.js` `async headers()`** (or middleware) | inline config | DENY framing except `/seed/`,`/seed-kv/` via `(?!seed/|seed-kv/)`. Portable — works under `next start`. `vercel.json` is an optional duplicate, NOT the source of truth. |
| migration script (2-level → 3-level) | inline | idempotent, copies legacy keys forward |

---

## 13.5 Steps — install & run (paste-and-run, zero pre-baked)

Ordered procedure for a **bare host** (only a shell + `claude`). Each step states intent;
the agent adapts the exact command to the host's OS/pkg-mgr. Step 0 is the Interview (§12).

1. **Ensure Node ≥ 18.17 + npm.** `node -v`; if missing/older, install it — `nvm install 20`
   (preferred, no root) or the host pkg mgr (`apt`/`dnf`/`brew`/nodesource). Verify
   `node -v` and `npm -v` print.
2. **Get the code.** Either you're hydrating into a fresh project dir (build the app from the
   spec) or working in the repo. Land at a project root with `package.json`.
3. **Install npm deps.** `npm install` (pulls next, react, next-auth, @vercel/kv, cheerio,
   typescript, @playwright/test). `npm run build` must later succeed on Node ≥18.17.
4. **Ensure a seed corpus.** If `cookoff-seeds/` has no `*/*.html`, **create an example**:
   write `cookoff-seeds/seed/v1.html` — a small, valid standalone HTML document (a heading +
   a couple of sections with real text so anchored comments + candidate-anchors have
   something to bind to). This guarantees a navigable, non-empty app from a bare paste.
5. **Install the Playwright browser + OS libs (REQUIRED for Verify).**
   `npx playwright install --with-deps chromium`. This downloads chromium **and** apt-installs
   the system libraries headless chromium needs (libnss3, libatk-1.0, libgbm, libasound2, …).
   On a non-Debian host use the matching `playwright install-deps` path or the distro
   equivalents. ⚠️ Skipping this is why a bare env paints 0 test runs ("Executable doesn't
   exist"). If `--with-deps` can't get root, run `npx playwright install chromium` then install
   the listed libs via the host pkg mgr.
6. **Write `.env.local` (dev secrets — auto-generated, no user input).** Ensure:
   `NEXTAUTH_SECRET=$(openssl rand -base64 32)` (if unset), `NEXTAUTH_URL=http://localhost:3210`,
   **`ALMANAC_TEST_LOGIN=1`**, and throwaway dev values for `ALMANAC_AGENT_API_KEY` +
   `VERCEL_AUTOMATION_BYPASS_SECRET` (so J20–J22 run). Leave `GOOGLE_*` and `KV_*` unset for
   local (Google not needed thanks to the dev-login route; KV falls back to in-memory).
7. **Build + run.** `npm run build` then `npm start` (serves `:3210`); or `npm run dev` for
   iterating. Confirm `curl -sI localhost:3210/login` returns 200.
8. **Sign in for verification (no Google).** Hit `GET /api/test-login` (flag is on from §6) →
   it sets the `@plow.co` session cookie. Playwright does this in `beforeAll`; a human can
   open it in the browser.
9. **Verify.** Run `## Verify` / `npm run e2e` (§15) — all §16 journeys against `:3210` only.

---

## 13.6 Deploy (public) — your OWN live Almanac on Vercel + Upstash Redis

Local build/verify proves the app; this section makes it a **real, public, secured deploy
that anyone reaches from outside your LAN — with YOUR OWN accounts/keys, no `plow` anything.**
Backend = **Upstash Redis** (Vercel KV is Upstash; Almanac is a Redis-style KV app — **not**
Postgres/Supabase, so there is **no SQL schema/migration**). Auth = the **passphrase login**
(§6). Most steps are CLI; exactly **two are unavoidable human browser actions** (marked 🧑).

> Prereqs: a free **Vercel** account; the app hydrated locally (`## Steps`); and the **Vercel
> CLI installed** — `npm i -g vercel` (the bare host has no `vercel` binary).
>
> **Account note:** the REST/API calls below take `?teamId=<team>`. That's for a **Team**
> account — on a **personal/free** account there is **no team**, so **omit `?teamId=` entirely**
> (and use your username as `<scope>`). The CLI auth token lives at
> `~/Library/Application Support/com.vercel.cli/auth.json` on **macOS** and
> `~/.local/share/com.vercel.cli/auth.json` on **Linux**. The dashboard path works for every
> step if you'd rather click than curl.

1. **🧑 Vercel login (browser).** Run `vercel login`. It prints a device URL like
   `https://vercel.com/oauth/device?user_code=XXXX-XXXX` and waits. **You** open that URL and
   click **Confirm** (pick your team/scope). One click; the CLI then proceeds authenticated.
2. **Link/create the project (CLI).** `vercel link --yes --project <your-almanac> --scope <your-scope>`
   (creates the Vercel project).
3. **Provision Upstash Redis** (no SQL/schema — Redis keyspace is created on first write).
   Two ways:
   - **🧑 Dashboard (simplest):** your project → **Storage → Create Database → "Upstash for
     Redis" (Marketplace) → Connect**, then **Connect Project → select `<your-almanac>` →
     All Environments → Connect.**
   - **CLI/API (no browser click for the connect — verified):** create the store once in the
     dashboard (or reuse an existing one), then connect it to the project via the Vercel REST
     API — the endpoint the dashboard button calls, which the `vercel` CLI does *not* expose
     (`integration-resource` only disconnects/removes). With your CLI token
     (`~/Library/Application Support/com.vercel.cli/auth.json`) and `teamId`/`storeId`/`projectId`:
     `POST https://api.vercel.com/v1/storage/stores/<storeId>/connections?teamId=<team>`
     with body `{"projectId":"<prj_…>","envVarEnvironments":["production","preview","development"]}`.
     (Find ids via `GET /v1/storage/stores?teamId=…` and `GET /v9/projects/<name>?teamId=…`.)
   Either way it **auto-injects `KV_REST_API_URL` + `KV_REST_API_TOKEN`** (+`KV_URL`,`REDIS_URL`,
   `KV_REST_API_READ_ONLY_TOKEN`). Confirm with `vercel env ls`.
4. **Set the remaining prod env (CLI).** Generate + set, e.g.:
   `printf '%s' "$(openssl rand -base64 32)" | vercel env add NEXTAUTH_SECRET production`;
   `printf '%s' "<a strong passphrase>" | vercel env add ALMANAC_ACCESS_PASSWORD production`.
   **Do NOT set `ALMANAC_TEST_LOGIN`** (so the dev bypass 404s in prod). `GOOGLE_*` +
   `ALLOWED_DOMAIN` only if you also want Google SSO.
5. **Ensure the framework is Next.js (CLI/API — REQUIRED).** If you created the project with
   bare `vercel project add`, Vercel may not detect the framework and the deploy fails with
   *"No Output Directory named 'public' found."* Fix: deploy from the app dir via `vercel link`
   (auto-detects Next from `package.json`/`next.config`), **or** set it explicitly —
   `PATCH https://api.vercel.com/v9/projects/<prj>?teamId=<team>` body `{"framework":"nextjs"}`.
6. **Deploy (CLI).** `vercel deploy --prod` → Vercel builds server-side and prints your
   `https://<project>.vercel.app` URL. (The seed app compiles cleanly; if your build trips a
   strict type-check, fix the type — do **not** ship `ignoreBuildErrors`.)
7. **🔓 Turn OFF Vercel Deployment Protection (REQUIRED — or the URL 401s to everyone).** New
   Vercel projects default to **Vercel Authentication** (`ssoProtection`) which gates the
   ENTIRE URL behind Vercel SSO — an external visitor gets **401 even on `/login`**, before
   your app runs. Disable it so the deploy is truly public: Dashboard → project → **Settings →
   Deployment Protection → Vercel Authentication → Disabled**, **or** via API:
   `PATCH /v9/projects/<prj>?teamId=<team>` body `{"ssoProtection":null}`. (Your app's own
   passphrase login is the real gate; Vercel's SSO layer must be off for a public review URL.)
8. **Set the public URL + redeploy (CLI).**
   `printf '%s' "https://<project>.vercel.app" | vercel env add NEXTAUTH_URL production`, then
   `vercel deploy --prod` again (so NextAuth callbacks resolve to the real host).
9. **Confirm it's live + public.** From **off your LAN** (phone on cellular, or a server-side
   fetch): the URL loads `/login` (passphrase field); signing in with the **passphrase**
   reaches the index; a comment you leave **persists** across a reload / second device —
   proving the **real Upstash backend**, not in-memory.

**Acceptance (the public deploy is done when):** an external client reaches
`https://<project>.vercel.app`, logs in via the passphrase, and a left comment survives a
reload (Upstash-persisted). **Human steps are only:** #1 (Vercel device login) and creating
the Upstash store in step 3 (the connect itself can be the API call) — everything else
(framework, deploy, **disable protection**, env, redeploy) is CLI/API above.

---

## 14. Done (observable conditions)

Each independently checkable from a fresh shell (KV-less dev mode is fine for most):

- `npm run build` succeeds; `npm start` serves on **:3210**.
- Unauthenticated `GET /` ⇒ **redirect to `/login`** (302/307 to a `/login?next=/`).
- `GET /login` ⇒ 200, renders the Google sign-in card.
- With a signed-in `@plow.co` session: `GET /` lists ≥1 auto-discovered project; the status
  pills filter; `GET /p/<project>` shows the option grid; `GET /p/<p>/<o>` 307→ the latest
  version; the version page renders the iframe + version bar.
- `GET /seed/<round>/<slug>` returns the artifact HTML for a discovered path (200) and **404**
  for an unknown path; **401** when unauthenticated.
- A pin posted via `POST /api/comments` round-trips: it appears in `readVersionThread`, the
  iframe pin layer, and the activity panel; editing (author) sets `editedAt`; resolving hides
  the canvas pin but keeps the panel row; deleting a childless comment hard-purges while a
  replied-to comment soft-tombstones with a 5s undo.
- `POST /api/heartbeat` returns `{ active: [...] }` including the caller within 60s.
- Agent door: with both headers, `GET /api/agent-artifact/<p>/<o>/<v>` returns
  `{ html, comments, activity, candidate_anchors, … }`; `POST /api/agent-comments` with an
  `anchorText` that exists returns `{ commentId, url }` and the pin shows up alongside human
  pins; a bad `anchorText` returns 400 + `candidates`. Missing/!wrong headers ⇒ 401/403.
- Security headers present on `/` and **absent-framing-block** on `/seed/…` and `/seed-kv/…`.

---

## 15. Verify (runnable acceptance harness)

`## Verify` is a script whose **exit code is the truth** (0 = Done). It runs after `## Steps`
on a **bare host** and must itself guarantee its tooling — do not assume a seedbed:

1. **Preflight (self-installing).** Assert `node -v` ≥ 18.17. Ensure the Playwright browser is
   present — run `npx playwright install --with-deps chromium` if a launch probe fails (never
   assume a pre-baked browser). Ensure `ALMANAC_TEST_LOGIN=1` + `NEXTAUTH_SECRET` are in the
   env/`.env.local`.
2. **Boot** the built app on `:3210` (KV-less in-memory mode is fine), wait for
   `curl -sf localhost:3210/login`.
3. **Sign in without Google:** `GET /api/test-login?email=tester@plow.co` to obtain the
   `@plow.co` session cookie (Playwright `storageState`/`beforeAll`). No Google creds, no
   externally minted JWT.
4. **Assert** the §14 conditions + the §16 journeys via Playwright (`npm run e2e`) against
   `http://localhost:3210` only. Exit code = truth.

It must:
- run from a fresh shell on a host with **nothing pre-installed but the Steps' output**,
- print enough to debug failures,
- finish in < 5 min for the core path.

> **Self-contained — no reference instance.** Verify drives **only the app this seed built**,
> on `localhost:3210`. It does **NOT** require the production Almanac, any other running
> instance, or golden screenshots captured from one. Visual fidelity (J23–J27) is asserted
> against the **absolute values in §9**, not by diffing another app. If any check here needs a
> second/real instance to pass, that is a seed bug — fix the seed (make §9 carry the value),
> not the harness. A fresh blind agent on a clean machine with **no Almanac anywhere** must be
> able to reach exit 0.

The reference implementation (`github.com/plow-pbc/almanac`) ships a Playwright suite under
`tests/e2e/` (`verify-comment-flow`, `verify-resolve`, `verify-draggable-pins`,
`verify-agent-artifact`, `verify-anchor-text`, `verify-version-switcher`, `verify-activity`,
`verify-responsive`, `verify-3-level-migration`, …) — listed only as an **illustration** of
what §16 looks like in executable form. It is **not** a dependency of this seed; your build
authors its own equivalent suite from §16.

---

## 16. Verification journeys (acceptance tests — all must pass)

Each states an action and the observable expected result. Manual or headless (Playwright).

1. **Auth gate.** Hit `/` with no session. *Expect:* redirect to `/login?next=/`, and `/login`
   renders a **sign-in card** with whatever providers are configured — the **passphrase field**
   (when `ALMANAC_ACCESS_PASSWORD` is set) and/or the **Google button** (when `GOOGLE_*` is set).
   (In dev `## Verify` signs in via `test-login`; the Google domain-rejection copy "Almanac is
   only for @plow.co accounts" appears only when Google is the configured provider.)
2. **Index list + status filter.** Signed in, open `/`. *Expect:* at least one project row
   (`<N> options · <M> pins`, "updated …"); clicking `archived`/`shipped` pills re-filters;
   default is `active`.
3. **Drill-in + latest redirect.** Open a project → option grid renders. Open an option
   (`/p/<p>/<o>`). *Expect:* a redirect to `/p/<p>/<o>/v/<latest>`, where `<latest>` is the
   newest version by mtime.
4. **Artifact renders.** On the version page. *Expect:* the version bar (breadcrumb
   project/option/version + "+ Comment" + "Activity") and an iframe whose document is the seed
   HTML (not `about:blank`).
5. **Drop a pin (toggle mode).** Click "+ Comment", click inside the artifact, type "needs
   more contrast", post. *Expect:* a numbered volt pin appears at the click point with the
   author's initials/avatar; the comment shows in the activity panel; reloading the page keeps
   it.
6. **Drop a pin (Alt+click).** Hold ⌥/Alt and click the artifact. *Expect:* the composer opens
   single-shot; posting drops a pin and returns to idle (mode not sticky).
7. **Hover/click popover + reply + react.** Hover a pin → popover opens; add a reply "agreed";
   open the emoji picker and react 🔥. *Expect:* the reply appears nested; the 🔥 chip shows
   count 1, toggled `data-mine`; clicking it again removes it (count→0, chip gone).
8. **Edit (author-only).** As the author, ⋯ → Edit a comment, save new text. *Expect:* body
   updates + "· edited" flag; `ts`/sort unchanged. A different signed-in user does **not** see
   Edit/Delete for that comment (403 if forced via API).
9. **Resolve hides the pin.** Toggle ✓ resolve on a pin. *Expect:* its canvas pin disappears;
   the panel row remains and is reachable under the "resolved" state filter; unresolve brings
   the pin back.
10. **Delete with undo.** *(Use a dedicated project/version and place every pin this journey
    needs at **fixed, well-separated coordinates — ≥24px apart**, e.g. `y=180` and `y=560` like
    J12. WHY: the app correctly **clusters pins within 24px** into one cluster glyph, so two
    pins that happen to land close together stop existing as isolated `.feedback-pin` elements
    and the assertions below flake. The clustering is correct app behavior — do **not** change
    it; just pin the test coords so the undo-restored pin and the part-2 pin never cluster.)*
    Place a **childless** comment (e.g. at `y=180`) and delete it. *Expect:* the pin vanishes +
    an Undo toast for ~5s; clicking Undo restores it (and, being ≥24px from any other pin, it
    re-renders as its own `.feedback-pin`, not a cluster); letting the window elapse instead
    hard-deletes (gone after reload). Then, on a separate comment placed well apart (e.g.
    `y=560`) that **has replies**, delete it ⇒ tombstone "[comment deleted by author]" with
    replies intact.
11. **Drag to reposition (any user).** As a **non-author** signed-in user, drag a pin >4px and
    drop on a different element. *Expect:* the pin persists at the new spot after reload; a
    failed PATCH snaps it back.
12. **Pin clustering.** Place two pins within ~24px. *Expect:* they collapse into one cluster
    glyph with a `+N` badge; clicking it opens a pop-list of the members; picking one opens
    that pin's popover.
13. **Activity panel filters.** Open the panel (button or `a` key). *Expect:* search by author/
    body narrows the feed; `open`/`resolved` tabs filter; `recent`/`reactions` re-sorts; with
    >1 version, version chips multi-select; "jump to pin" scrolls + flashes the current-version
    pin; cross-version rows show "open <vN>". Panel open-state survives reload
    (`almanac.panel.open`).
14. **Version switcher + download + add version.** Open the switcher. *Expect:* all versions
    newest-first, current marked ✓, newest "latest"; the `↓` downloads
    `<p>-<o>-<v>.html`; "+ Add version" uploads an `.html` and redirects to the new `v<N+1>`.
15. **New project / add option (manual).** "+ new project" → fill name/slug/first-option +
    upload `.html` → redirect to the new version. On that project (manual) "+ add option"
    appears and works; on an **fs** project it does not (API 404 if forced).
16. **Inline rename keeps slug.** Rename a project (and an option, and a version) inline.
    *Expect:* the display name changes everywhere after `router.refresh()`, but the **URL/slug
    is unchanged** and existing pins/data still resolve.
17. **Presence.** Open the same version in two sessions. *Expect:* each sees the other in the
    ViewerStack within ~20s; a session whose tab is hidden drops out of the live (<60s) roster.
18. **Status edit.** Change a project status active→shipped. *Expect:* it moves to the
    `shipped` filter on the index immediately.
19. **Legacy URL redirect.** Hit `/p/<p>/v/<oldVersionSlug>`. *Expect:* a 308 to
    `/p/<p>/<oldVersionSlug>/v/v1` (or 404 if that option doesn't exist).
20. **Agent read.** `GET /api/agent-artifact/<p>/<o>/<v>` with both headers. *Expect:* JSON
    with `html`, `comments`, `activity`, and a non-empty `candidate_anchors` (each
    `bbox:null`, with `selector` + `text_preview`). Missing/wrong `x-vercel-protection-bypass`
    ⇒ 401; wrong `x-almanac-agent-key` ⇒ 401.
21. **Agent write (text anchor).** `POST /api/agent-comments` with `anchorText` matching real
    seed copy. *Expect:* `{ commentId, url:…#pin-<id> }`; the pin renders in the iframe + panel
    next to human pins, marked agent-authored. A bogus `anchorText` ⇒ **400** with a
    `candidates` array. Both agent-write headers missing ⇒ 401/403.
22. **Agent resolve / delete.** `PATCH /api/agent-comments/<id>` flips resolved (no author
    check); `DELETE` with the matching `x-almanac-agent-author` prunes it. Targeting a
    **human** comment ⇒ **409 not-agent**.

### Visual fidelity (the rebuild must *look* like §9, not just function)

Functional journeys 1–22 pass even on a wrong-looking build, so add these. The fidelity gate
is **computed-style / DOM assertions against the ABSOLUTE values written in §9** — and it is
**fully self-contained**: it requires **no reference instance, no production Almanac, no
golden screenshots**. The implementer never has the original app; §9 carries every value
(fonts, weights, colors, shadows, hover deltas, casing, layout) precisely enough that
asserting the build against those literals IS the fidelity check.

> **Assert against §9's absolute values, NOT against another running app.** Earlier drafts of
> this seed told the verifier to screenshot-diff against the *production* Almanac. That was a
> mistake: it made the seed non-self-contained (a real implementer has no production instance
> to diff against) and it outsourced fidelity to an external app instead of to this spec. The
> rule now: **every visual check reads computed style / DOM geometry and compares to the
> literal value in §9.** The lesson that motivated the old rule still holds — **sample the
> elements that actually drift** (project-row name font, pill casing, active-pill outline,
> metadata layout, leading bullet), not just `body`/`h1`/one mono label — but the comparand is
> **§9, not production**. (A self-captured screenshot baseline only proves a build is
> consistent with itself, so screenshot-diff is at most an **optional same-build regression
> aid**, never the fidelity gate — see J27.)

23. **Fonts resolve correctly — including the row name.** Via `getComputedStyle`: `body`
    `font-family` resolves to a **DM Sans** stack; the hero/page-title `h1` resolves to
    **Instrument Serif** with `font-style: italic` and `font-weight: 400`; a mono label
    (status pill / `.kbd`) resolves to **DM Mono**; **and a project-row name resolves to the
    DM Sans stack with `font-style: normal`** (per §9.2 — row/version-card names are *sans*,
    **not** serif italic; a serif row title is the single most common fidelity miss and must
    fail this check). *Expect:* exact matches — this is what "the fonts look distinct" was.
24. **Tokens + shadows exact.** Computed `--volt` = `rgb(213,239,138)`; page bg = chalk;
    a card's `box-shadow` and a popover's `box-shadow` match the §9.4 ladder; radius on a
    card = 12px, on a pill = 999px.
25. **Hover micro-interactions fire.** Programmatic hover + computed-style/bounding-box diff:
    `.project-row` gains `padding-left: 8px` and its arrow `translateX(4px)`; a breadcrumb
    crumb gains the volt-tint wash `rgba(213,239,138,0.32)`; the "+ Comment" toggle lifts
    `translateY(-1px)`; a card lifts `translateY(-2px)`; the rename **pencil** is hidden at
    rest and becomes visible on row hover. *Expect:* each state change observed (not just
    "element exists").
26. **Transition feel.** Computed `transition-duration`/`timing-function` on the sampled
    interactive elements are from the §9.3 ladder (default **180ms ease-out**; panel slide
    **220ms**). *Expect:* no `0s`/`linear` defaults left on interactive elements.
27. **Layout / casing / typography assertions vs §9 (self-contained — the real fidelity gate).**
    Read DOM + `getComputedStyle` on the **own** build and assert against the literal §9 values
    — no external app:
    - **Row name = sans, normal.** `.project-row .name` (or the rename target inside it)
      `font-family` resolves to the **DM Sans** stack, `font-style: normal` (⚠️ a serif/italic
      row title fails — the #1 historical miss).
    - **Leading bullet.** Each project row shows a leading **`•`** marker before the name
      (assert a visible bullet glyph / `::before` content / list-marker — §9.8).
    - **Label casing.** The active filter pill renders **`ACTIVE`** (computed
      `text-transform: uppercase` *or* the rendered text is all-caps); the brand suffix is
      **`ALMANAC`**, the CTA **`+ NEW PROJECT`** (uppercase); **but** `sign out`, the
      version-bar hint, and row meta/counts are **lowercase** (§9.2).
    - **Active filter pill = outlined, not filled.** Computed on the active pill:
      `border-radius` = `999px`, `border-width` ≈ `1px` with `border-color` = `rgb(1,0,10)`
      (midnight), `background` = `rgb(255,255,255)` (`--card-bg`) — **not** transparent/`0`
      border and **not** a solid volt fill (§9.3 concrete pill spec).
    - **Metadata layout.** In a project row the `N options · M pins` meta + `open →` sit on the
      **name's baseline** (same grid row, right side), and only `updated <rel>` wraps to a
      second line — **not** all stacked under the name (§9.8).
    *Expect:* every assertion matches the §9 literal. This is the gate that catches the
    casing/row-typography/pill/metadata drift the global-token checks (J24) miss.
    **Optional regression aid (NOT a fidelity gate):** a project may *also* keep its **own**
    `toHaveScreenshot` baselines to catch unintended self-regressions between commits. That is
    explicitly **not** part of passing this seed and needs **no** reference instance — fidelity
    is established by the assertions above against §9, period.

---

## 17. Failure modes (known)

**Symptom: `npm run e2e` fails "browserType.launch: Executable doesn't exist … run npx playwright install".**
- Detect: bare host; the chromium binary was never downloaded (the dev-dep installs the test
  *runner*, not the browser).
- Fix: Steps §5 / Verify preflight must run `npx playwright install --with-deps chromium`.
  Never assume a pre-baked browser (that was a seedbed artifact).

**Symptom: chromium launches then crashes on missing system libs (`libnss3`, `libgbm`, …).**
- Detect: launch error referencing shared libraries on a slim Debian/Ubuntu base.
- Fix: `--with-deps` (apt, needs root) or install the listed libs via the host pkg mgr;
  `playwright install-deps` lists them per distro.

**Symptom: can't sign in / every page bounces to `/login`; Verify can't authenticate.**
- Detect: no Google creds (or Google OAuth is `Internal`-to-plow.co so a stranger's account is
  rejected); no `/api/test-login` reachable.
- Fix: ship `GET /api/test-login` (§6), set `ALMANAC_TEST_LOGIN=1` in `.env.local`, and add the
  route to middleware PUBLIC_PATHS. Verify signs in through it — **not** through Google or a
  hand-minted token.

**Symptom: app builds but the index is empty (no projects).**
- Detect: `cookoff-seeds/` has no `*/*.html` (e.g. only the seed `.md` was pasted, repo not
  cloned).
- Fix: Steps §4 writes an example `cookoff-seeds/seed/v1.html` when the corpus is absent.

**Symptom: pins/listeners attach to a blank doc and never fire.**
- Detect: pins don't render though comments exist; iframe shows content.
- Fix: don't trust `readyState==="complete"` on the initial `about:blank`; bump a load
  **counter** on the real `load` (URL ≠ `about:blank`) and key pin/click/cluster effects on it.

**Symptom: `/seed*` won't load in the iframe (blocked by X-Frame-Options).**
- Detect: empty iframe + a framing console error.
- Fix: the security-header rule must **exclude** `/seed/` and `/seed-kv/` via the negative-
  lookahead `"/((?!seed/|seed-kv/).*)"`. Put it in **`next.config.js` `async headers()`/
  middleware** (portable) — a `vercel.json`-only rule does nothing under a stranger's bare
  `next start` (no Vercel header layer).

**Symptom: security/framing headers absent under `next start` (present only on Vercel).**
- Detect: `curl -I localhost:3210/` shows no `X-Frame-Options`/CSP though the deploy had them.
- Fix: headers were defined only in `vercel.json` (deploy-layer). Move them to
  `next.config.js` `async headers()` (or middleware) so they apply on any host. §2.

**Symptom: legacy projects show 0 comments/viewers after deploy.**
- Detect: a known project's pins/viewed-by vanished.
- Fix: implement the **2-level read fallback** for `v === "v1"` (and triplet back-fill on
  legacy rows); don't blank the surface ahead of the migration script.

**Symptom: agent endpoints 307→/login.**
- Detect: agent POST/GET redirected to the sign-in page.
- Fix: add `/api/agent-comments` and `/api/agent-artifact` to middleware **PUBLIC_PATHS** (they
  carry their own header auth).

**Symptom: HTML upload 413s.**
- Detect: large seed files rejected.
- Fix: cap at **3.5 MB** (3,670,016 bytes) — under Vercel's 4.5 MB serverless body limit with
  multipart headroom.

**Symptom: reposition/resolve 403 for non-authors.**
- Detect: the crit team can't move/resolve others' pins.
- Fix: reposition + resolve are **open to any signed-in user** by design — only edit/delete are
  author-gated.

**Symptom: dev has no KV and the app crashes.**
- Detect: `@vercel/kv` errors with no `KV_REST_API_*`.
- Fix: the **in-memory Map fallback** must engage when those env vars are absent (warn once;
  never in production).

---

## 18. Convergence notes (read before building)

Details most likely to drift between two independent rebuilds — lock them in:
- **3-level model is canonical** (Project → Option → Version) but **every v1 read falls back to
  the legacy 2-level key**; legacy comment rows back-fill `optionId←versionId, versionId←"v1"`.
- **KV key shapes in §5 are exact.** IDs = 16 hex chars (`/^[a-f0-9]{16}$/`).
- **Two auth doors**: session-cookie (humans, `@plow.co`) and two-header (agents); both write
  the **same** comment shape; agent rows carry `agentAuthored:true`.
- **Authorship split**: edit/delete = author-only; **reposition + resolve = any signed-in
  user**.
- **Soft-delete iff replies exist**, else hard purge; **5s undo** window.
- **Pins live inside the iframe doc**, numbered chronologically, **resolved pins hidden from
  canvas**, **24px clustering** with a pop-list.
- **Placement**: "+ Comment" sticky toggle + **Alt/⌥-click single-shot**; the bare **`c`
  shortcut is removed**; `a` toggles the panel; **Esc** exits placement.
- **Quick-reaction set is exactly `👍 👎 🔥 🤔 ❤️`**; the picker is a curated in-house ~80-emoji
  set (no library) with a `localStorage` frequently-used row.
- **Heartbeat 20s / live window 60s**, paused on hidden tabs.
- **Optimistic-with-rollback** on every mutation; `router.refresh()` after renames.
- **Security headers DENY framing except `/seed/` and `/seed-kv/`** — applied portably in
  `next.config`/middleware (not vercel.json), so they hold under a bare `next start`. And
  unauth `/seed`·`/seed-kv` return **401**, not a 307→/login (artifact endpoints — see §6).
- **Port 3210.** Brand: **chalk bg, volt accent, Instrument Serif headings, film-grain
  overlay**; fonts DM Sans / DM Mono / Instrument Serif.
- **Agent position priority**: `anchorText` > `anchorSelector` > `(x,y)` > sentinel; text-miss
  returns `candidates`.

---

## 19. Installation / handoff

Hand this seed to a coding agent: *"Hydrate this seed: build the Almanac app it specifies (a
Next.js 14 + NextAuth-Google + Vercel-KV design-review surface) until every §16 journey
passes. Run §15 to self-verify before declaring done."* The canonical source of truth is the
running app on `:3210` plus a green Playwright suite; the reference build lives at
`github.com/plow-pbc/almanac` (codebase package `seeds-feedback`).
