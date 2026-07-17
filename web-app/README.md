# 🌐 Mattioli.OS — Web

The **React + Vite** client. A single build serves two distinct surfaces:

| Surface | Routes | Notes |
| :--- | :--- | :--- |
| **Public site** | `/` `/features` `/philosophy` `/tech` `/faq` `/get-started` `/creator` `/privacy` `/terms` | Pre-rendered to static HTML at build time and indexed via [`public/sitemap.xml`](./public/sitemap.xml) |
| **Tracker app** | `/auth`, and everything under `/sw` — dashboard, stats, macro goals, AI coach, backup | Behind `ProtectedRoute`, requires a Supabase account |

The native clients live elsewhere in this repository: [`../mobile`](../mobile)
(Flutter — iOS/Android) and [`../desktop`](../desktop) (Flutter —
macOS/Windows/Linux).

---

## ⚡️ Quick Start

```bash
cd web-app
npm install
npm run dev
```

The dev server listens on **`http://localhost:8080`** (Vite redirects `/` to the
`/mattioli.OS/` base path configured in [`vite.config.ts`](./vite.config.ts)).

**Environment**: create a `.env` next to `package.json` — see
[`env_example`](./env_example) for the accepted keys.

**Database**: the schema is shared with the native clients and lives at the
repository root, one level up — [`../schema.sql`](../schema.sql). Run it in your
Supabase SQL Editor.

---

## 📜 Scripts

| Command | What it does |
| :--- | :--- |
| `npm run dev` | Vite dev server on `:8080` |
| `npm run build` | Production build → `dist/`, then pre-renders the public routes to static HTML |
| `npm run lint` | ESLint across the project |
| `npm run preview` | Serve the built `dist/` locally |
| `npm run deploy` | Builds, then publishes `dist/` to the `gh-pages` branch |

> [!IMPORTANT]
> **Deploy runs from this directory, not the repository root**:
> `cd web-app && npm run deploy`. The `gh-pages` target resolves `dist/`
> relative to the current working directory.

---

## 🧱 Stack

- **React 18** + **Vite 7** (SWC)
- **TypeScript** — absolute imports via `@/*` → `src/*`
- **Tailwind CSS** + **shadcn/ui** (Radix primitives)
- **TanStack Query** (server state) · **React Router** (routing)
- **Supabase** — Postgres + Auth

---

## 🗂 Layout

```text
src/
├── components/     UI components (ui/ = shadcn atoms)
├── context/        React contexts (AI, Privacy)
├── hooks/          data fetching + business logic
├── integrations/   Supabase client & generated types, Ollama
├── lib/            utilities (dates, streaks, backup)
├── pages/          route views
└── types/          shared TS types

public/             static assets served verbatim (schema.sql, sitemap.xml, PWA icons)
scripts/            build-time helpers (static route pre-rendering)
docs/               guides for this client
```

---

## 📚 Docs

| 🇺🇸 English | 🇮🇹 Italiano |
| :--- | :--- |
| [Technical Guide](./docs/TUTORIAL_TECH_EN.md) | [Guida Tecnica](./docs/TUTORIAL_TECH_IT.md) |

- [Technical Deep Dive](./docs/TECHNICAL_DEEP_DIVE.md) — architecture, state, RLS
- [Troubleshooting](./docs/TROUBLESHOOTING.md) — common failures and fixes
- [AI_CONTEXT.md](./AI_CONTEXT.md) — orientation for AI agents working in this folder
