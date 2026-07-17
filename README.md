<div align="center">

# 🌟 Mattioli.OS

### **Master Your Discipline. Own Your Data. Gamify Your Growth.**

[![Watch the Tutorial](https://img.shields.io/badge/▶_Watch_Tutorial-YouTube-red?style=for-the-badge&logo=youtube)](YOUR_YOUTUBE_VIDEO_LINK_HERE)
[![License: PolyForm NC](https://img.shields.io/badge/License-PolyForm_Noncommercial_1.0.0-yellow.svg?style=for-the-badge)](./LICENSE)
[![Stack](https://img.shields.io/badge/Tech-Flutter%20|%20React%20|%20Supabase-blue?style=for-the-badge)](./web-app/docs/TECHNICAL_DEEP_DIVE.md)
[![Status](https://img.shields.io/badge/Status-Active_Development-success?style=for-the-badge)]()

<br />


![Daily View](./docs/assets/Daily%20Tasks%20view%20mensile.png)

<p align="center">
  <i>"We don't rise to the level of our goals. We fall to the level of our systems." — James Clear</i>
</p>

[🧭 Surfaces](#-surfaces) • [🏁 Quick Start](#-quick-start) • [✨ Features](#-key-features) • [📚 Documentation](#-documentation-hub) • [🧠 Philosophy](#--philosophy)

</div>

---

## 🧭 Surfaces

Mattioli.OS ships as three clients against one shared Supabase backend.

| Folder | Surface | Stack | Docs |
| :--- | :--- | :--- | :--- |
| [`web-app/`](./web-app) | Public website + browser tracker | React 18 · Vite 7 · Tailwind | [README](./web-app/README.md) |
| [`mobile/`](./mobile) | iOS · Android | Flutter · Riverpod | [README](./mobile/README.md) |
| [`desktop/`](./desktop) | macOS · Windows · Linux | Flutter · Riverpod | [README](./desktop/README.md) |

Shared across all three:

| Folder | Contents |
| :--- | :--- |
| [`schema.sql`](./schema.sql) + [`migrations/`](./migrations) | Database schema — the single source of truth |
| [`supabase/`](./supabase) | Edge functions (RevenueCat webhook, Apple token revocation) |
| [`packages/`](./packages) | Shared Dart packages (`evolve_sync`, `evolve_verification`) |

---

## ⚡️ Quick Start

Get the **web client** running in **seconds**.

```bash
# 1. Clone the repo
git clone https://github.com/simo-hue/mattioli.OS.git

# 2. Enter the web app
cd mattioli.OS/web-app

# 3. Install dependencies
npm install

# 4. Start the dev server
npm run dev
```

> **Note**: For full backend functionality, run the provided `schema.sql` — at the
> repository root, since it's shared with the native clients — in your Supabase
> project. See the [Technical Setup Guide](./web-app/docs/TUTORIAL_TECH_EN.md) for details.

Building the **native** clients instead? See [`mobile/README.md`](./mobile/README.md)
or [`desktop/README.md`](./desktop/README.md).

---

## 💎 Key Features

Why choose **Mattioli.OS** over Notion, Todoist, or expensive SaaS apps?

| Feature | 🌟 Mattioli.OS | 📝 Notion/Generic | 💰 Paid SaaS |
| :--- | :---: | :---: | :---: |
| **Data Ownership** | ✅ **100% Yours** (Local/Supabase) | ❌ Cloud Only | ❌ Vendor Locked |
| **Cost** | ✅ **Free Forever** | ⚠️ Monthly Sub | ❌ $$$ / Month |
| **Offline First** | ✅ **Localhost Capable** | ⚠️ Limited | ❌ No |

### 🔥 Core Modules

<details open>
<summary><b>📅 Daily Habits & Tracking</b> (Click to Collapse)</summary>
<br />
Track your daily progress with granular precision. Switch between monthly and weekly views to analyze your consistency.

| Monthly View | Weekly Breakdown |
| :---: | :---: |
| <img src="./docs/assets/Daily%20Tasks%20view%20mensile.png" alt="Monthly View"> | <img src="./docs/assets/Daily%20Tasks%20view%20settimanale.png" alt="Weekly View"> |

**Detailed Statistics:**
<img src="./docs/assets/Daily%20Tasks%20full%20stats.png" alt="Daily Stats" width="100%">
</details>

<details>
<summary><b>🎯 Macro Goals & Long-term Vision</b> (Click to Expand)</summary>
<br />
Align your daily actions with your life's biggest ambitions.

| Single Year Focus | Multi-Year Trends |
| :---: | :---: |
| <img src="./docs/assets/Macro%20Obiettivi%20stats%20anno%20singolo.png" alt="Yearly Goals"> | <img src="./docs/assets/Macro%20Obiettivi%20stats%20aggregate%20multi-anno.png" alt="Long Term Trends"> |
</details>


---

## 📚 Documentation Hub

We have crafted distinct paths for every type of user.

| 🇮🇹 Italian Docs | 🇺🇸 English Docs |
| :--- | :--- |
| **[Manuale Utente](./docs/TUTORIAL_USER_IT.md)** <br> *Per chi vuole solo usare l'app.* | **[User Manual](./docs/TUTORIAL_USER_EN.md)** <br> *For those who just want to use the app.* |
| **[Guida Tecnica](./web-app/docs/TUTORIAL_TECH_IT.md)** <br> *Setup locale e deploy del client web.* | **[Technical Guide](./web-app/docs/TUTORIAL_TECH_EN.md)** <br> *Local setup and deployment of the web client.* |

### 🧠 For Engineers
Check out the **[Technical Deep Dive](./web-app/docs/TECHNICAL_DEEP_DIVE.md)** for:
*   Architecture Diagrams (Mermaid.js)
*   State Management Philosophy (React Query)
*   Supabase Security Rules (RLS) explanations.

Stuck? See **[Troubleshooting](./web-app/docs/TROUBLESHOOTING.md)**.

---

## 🧘 Philosophy

This tool is **Opinionated**. It assumes:
1.  **Friction is the enemy**. Tracking must be instant.
2.  **Privacy is non-negotiable**. Your habit data is your business.
3.  **Aesthetics matter**. If an app looks bad, you won't use it.

---

## 🤝 Contributing

We love contributions! Please read our [CONTRIBUTING.md](./docs/CONTRIBUTING.md) first.

1.  Fork it (`https://github.com/yourname/habit-tracker/fork`)
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

<div align="center">
  <br />
  Made with ❤️, ☕, <b>Flutter</b> and <b>React</b> | Mattioli Simone.
  <br />
</div>
