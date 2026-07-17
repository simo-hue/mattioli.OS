# AI Context & Development Guide

## Project Overview
**Habit Tracker** is a personal growth application built with React, Vite, and Supabase. It allows users to track daily habits (goals), view statistics, and visualize progress through calendars and heatmaps.

## Tech Stack
- **Framework**: React 18 + Vite
- **Language**: TypeScript
- **Styling**: Tailwind CSS + shadcn/ui (Radix Primitives)
- **State Management**: TanStack Query (React Query)
- **Routing**: React Router DOM
- **Backend/DB**: Supabase (PostgreSQL)
- **Auth**: Supabase Auth
- **Icons**: Lucide React
- **Charts**: Recharts

## Architecture
- **Single Page Application (SPA)**: Client-side routing.
- **Supabase Integration**: Direct client-side calls using `@supabase/supabase-js`.
- **Component Library**: Uses `shadcn/ui` components located in `src/components/ui`.

## Key Data Models (`src/types/goals.ts`)

### `Goal` (Habit)
- `id`: UUID
- `title`: Name of the habit
- `color`: Visual identifier
- `frequency_days`: Array of numbers (1-7) representing days of the week (1=Mon, 7=Sun).
- **Soft Deletion Logic**: If `end_date` is set, the habit is considered "archived" or "stopped" after that date. It is NOT physically deleted from the DB unless it has no logs.
- `start_date`: When the tracking began.
- `verify_provider` / `verify_metric` / `verify_comparator` / `verify_threshold` / `verify_unit`: _(Added 2026-07-13: auto-verified habits feature)_ Optional auto-verification rule (all null => ordinary manual habit). Verification runs only on the iOS/Flutter clients; the web app displays these read-only.

### `GoalLog` (Entry)
- `goal_id`: FK to Goal
- `date`: ISO Date string (YYYY-MM-DD)
- `status`: 'done' | 'missed' | 'skipped' | null
- `value`: Optional numeric value for quantifiable habits.

## Folder Structure
```
src/
├── components/         # React components
│   ├── ui/             # shadcn reusable atoms (Button, Card, etc.)
│   ├── stats/          # Statistics specific sub-components
│   └── [Feature].tsx   # Feature-specific components (e.g., WeeklyView, HabitSettings)
├── hooks/              # Custom hooks (e.g., useGoals, useToast)
├── integrations/       # External services (Supabase client & generated types)
├── lib/                # Utilities (cn, date formatting)
├── pages/              # Route views (Index, Stats, Panoramica, MacroGoals, Mensile, AICoach, Auth, ...)
├── types/              # TS Interfaces (goals.ts)
└── App.tsx             # Main entry point with Routes & Providers
```

## Critical Business Logic
1. **Deletion**:
   - If a habit has logs: **Soft Delete** (Update `end_date` to today).
   - If a habit has NO logs: **Hard Delete** (Remove row from DB).
2. **Date Handling**:
   - Usage of `date-fns` for manipulation.
   - Goals are frequency-based (e.g., "Mon, Wed, Fri"). logic checks if `frequency_days` includes the current day index.

## Best Practices
- **Components**: Functional components with strict typing.
- **Styling**: Utility-first with Tailwind. use `cn()` for class merging.
- **Async**: Use `useQuery` and `useMutation` for server state.
- **Imports**: Absolute imports using `@/` alias (configured in `tsconfig.app.json` and `vite.config.ts`).

## Terminology
- **Goal**: Often referred to as "Habit" in the UI.
- **Log**: A daily record of a habit's status.
- **Streak**: Consecutive days of completion (calculated on frontend/backend).
