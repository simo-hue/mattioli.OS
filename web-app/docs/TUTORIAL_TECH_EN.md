# 🇺🇸 Technical Guide - Mattioli.OS

Complete guide for developers or anyone wishing to self-host the application.

## 📋 Requirements
- **Node.js** (Version 20.19+ or 22.12+, required by Vite 7)
- **NPM**
- A **Supabase** account (Free tier is sufficient)

---

## 🛠 Local Installation

### 1. Clone the Repository
Download the source code to your machine. The web app lives in `web-app/`;
the repository also holds the Flutter `mobile/` and `desktop/` clients.
```bash
git clone https://github.com/simo-hue/mattioli.OS.git
cd mattioli.OS/web-app
```

### 2. Install Dependencies
Install all necessary libraries.
```bash
npm install
```

### 3. Supabase Configuration (Database)
This app uses Supabase for the database and authentication.
1.  Create a new project on [Supabase.com](https://supabase.com).
2.  Go to **Project Settings** -> **API**.
3.  Copy `Project URL` and `anon public key`.
4.  Create a `.env` file in `web-app/` (next to `package.json`) and paste the
    values — see `env_example` for the full list of accepted keys:

```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON=your_anon_key
```

> [!IMPORTANT]
> **Database Setup**: `schema.sql` lives at the **repository root** — one level
> up from here (`../schema.sql`), because it is shared with the mobile and
> desktop clients.
> 1. Open the SQL Editor in your Supabase project.
> 2. Copy and paste the entire content of `../schema.sql`.
> 3. Run the script to create all necessary tables and security policies.

### 4. Start the App
```bash
npm run dev
```
The app will be available at `http://localhost:8080`.

---

## 🚢 Build & Deploy
To create an optimized production build:

```bash
npm run build
```

The `dist` folder will contain the static files ready to be uploaded to Vercel, Netlify, or your personal web server.

---

## 🗄 Project Structure
- `/src/components`: Reusable UI components.
- `/src/hooks`: Custom business logic (e.g., `useGoals`).
- `/src/integrations/supabase/client.ts`: Database client configuration.
- `/src/pages`: Main application pages.

For architecture details, see [TECHNICAL_DEEP_DIVE.md](./TECHNICAL_DEEP_DIVE.md).
