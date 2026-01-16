# 🌟 Mattioli.OS - Release Notes v1.0.0

> **Master Your Discipline. Own Your Data. Gamify Your Growth.**

**Release Date**: January 14, 2026  
**Status**: Production Ready ✅

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Major Features](#-major-features)
- [Dashboard & Statistics](#-dashboard--statistics)
- [Mobile Optimization](#-mobile-optimization)
- [Technical Improvements](#-technical-improvements)
- [Tech Stack](#-tech-stack)
- [Installation](#-installation)
- [Known Issues](#-known-issues)

---

## 🎯 Overview

**Mattioli.OS v1.0.0** represents a complete personal growth operating system designed for individuals who value **data ownership**, **privacy**, and **actionable insights**. This release introduces advanced habit tracking, comprehensive statistics, and a mobile-first responsive experience.

### Vision
Built on the principle that "We don't rise to the level of our goals. We fall to the level of our systems" (James Clear), Mattioli.OS provides the infrastructure to build and maintain life-changing habits with precision and clarity.

---

## 🚀 Major Features



### 📊 Mood & Energy Matrix
Advanced psychological tracking system for comprehensive self-awareness.

**Features:**
- **4-Quadrant Analysis**: Track mood (positive/negative) vs energy (high/low)
- **Smart Categorization**: Automatic placement based on user input
- **Correlation Analysis**: Discover relationships between emotions and habits
- **Mobile-Optimized**: Vertical card layout on small screens
- **Desktop Matrix**: Interactive 2x2 grid visualization

**Quadrants:**
- 🚀 **High Energy + Positive**: Peak Performance
- 😰 **High Energy + Negative**: Stress/Anxiety
- 😌 **Low Energy + Positive**: Calm/Content
- 😔 **Low Energy + Negative**: Burnout/Depression

**Insights:**
- Identify which emotions correlate with habit success
- Track mood patterns over time
- Understand energy cycles for optimal task scheduling

> 📍 **Location**: Stats → M&E tab  
> 📁 **Integration**: Mood data synchronized with daily logs

---

### 📅 Daily Habits System
The core of Mattioli.OS - granular daily habit tracking with maximum flexibility.

**Tracking Features:**
- ✅ **Tri-State Logging**: Done / Missed / Skipped
- 🎨 **Custom Colors**: Visual organization by category
- 📆 **Frequency Control**: Specific days of the week (Mon-Sun)
- 🔢 **Quantifiable Metrics**: Optional numeric values (e.g., "8 glasses of water")
- 📈 **Streak Tracking**: Visualize consecutive completion days
- 🗓️ **Multiple Views**: Monthly, Weekly, and Annual calendars

**View Modes:**
| View | Purpose | Best For |
|------|---------|----------|
| **Monthly** | 30-day overview with heatmap | Spotting weekly patterns |
| **Weekly** | Granular 7-day breakdown | Daily accountability |
| **Annual** | Full 365-day calendar | Long-term trends |

**Smart Deletion:**
- **Soft Delete**: Habits with logs are archived (set `end_date`)
- **Hard Delete**: Empty habits are permanently removed
- Preserves historical data while maintaining clean UI

> 📍 **Location**: Dashboard (Main Page)  
> 🔑 **Key Components**: `WeeklyView.tsx`, `HabitSettings.tsx`, `MonthlyCalendar.tsx`

---

### 🎯 Macro Goals & Long-Term Vision
Track life's biggest ambitions with the same precision as daily habits.

**Goal Types:**
- **Annual Goals**: Yearly milestones (e.g., "Run a marathon")
- **Monthly Goals**: 30-day challenges
- **Weekly Goals**: Short-term objectives

**Statistics Dashboard:**
- 📊 **Single Year View**: Monthly breakdown with detailed trends
- 📈 **All-Time View**: Multi-year progression with KPIs
- 🏆 **Performance Radar**: Category-based success visualization
- 📉 **Distribution Chart**: Goal type effectiveness analysis

**Key Metrics:**
- **Success Rate**: Percentage of completed goals
- **Best Month/Year**: Highest performance period
- **Category Performance**: Which life areas are thriving
- **Productivity Trends**: Volume vs efficiency over time

> 📍 **Location**: `/mappa` route  
> 📁 **Components**: `MacroGoalsStats.tsx`, `MacroGoalForm.tsx`

---

## 📊 Dashboard & Statistics

### Statistics Reorganization
Complete restructure of the stats interface for clarity and usability.

**Tab Structure:**

#### 1. **Trend Tab** (Default)
- 30-day completion rate trends
- Weekly consistency heatmap
- Overall success metrics
- Time-series analysis

#### 2. **Habits Tab**
- Individual habit statistics
- Per-habit success rates
- Streak leaderboard
- Frequency analysis

#### 3. **Mood Tab** (Previously "M&E")
- Mood & Energy Matrix (described above)
- Emotional pattern recognition
- Correlation with habit success

#### 4. **Info Tab** (Previously "Panoramica")
- Overview cards
- Quick insights
- Global statistics

#### 5. **Alert Tab** (Global View Only)
- Performance warnings
- Streak breaks
- Declining trends
- Actionable notifications

**Chart Enhancements:**
- 📐 **Optimized Radar Chart**: 65% outer radius (previously 80%) for label visibility
- 🎨 **Improved Typography**: 13px font, weight 500 for readability
- 🌗 **Dark Mode Polish**: Zinc-400 text color for optimal contrast
- 📊 **Composed Charts**: Multi-metric visualization (bars + lines)

> 📁 **File**: `src/components/stats/MacroGoalsStats.tsx`

---

### All-Time Dashboard
Dedicated high-level view for multi-year habit tracking.

**Premium KPIs:**
- 🎯 **Total Storico**: All-time goal count
- 📈 **Successo Globale**: Average completion rate across all years
- 🏆 **Anno Migliore**: Year with highest success %
- 💪 **Anno Più Produttivo**: Year with most completions (absolute)

**Visualizations:**
- **Progressione Annuale**: Bars (volume) + Line (efficiency %)
- **Analisi Categorie**: Aggregated radar chart
- **Distribuzione Tipologie**: Goal type effectiveness

**Technical Achievement:**
- 🚀 **Recursive Pagination**: Handles 100k+ records without API limits
- 📅 **Dynamic Range**: Automatically detects first goal date (not hardcoded to 2022)
- ⚡ **Performance**: Chunks of 1000 for optimal loading

> 📍 **Access**: Stats → Select "Dal 2022" in year dropdown  
> 📁 **Documentation**: `DOCUMENTATION_DASHBOARD_RESTRUCTURE.md`

---

## 📱 Mobile Optimization

### Responsive Design Philosophy
**Mobile-first** approach ensures full functionality on any screen size.

**Key Optimizations:**

#### Calendar Views
- **Desktop**: Full monthly grid with hover states
- **Mobile**: Vertical scrolling with touch-optimized buttons
- **Adaptive Heights**: Dynamic sizing based on screen real estate

#### Mood Matrix
- **Desktop**: 2x2 interactive grid with tooltips
- **Mobile**: Vertical cards with full-width layout
- **Professional Aesthetics**: Glassmorphism, gradients, smooth animations

#### Navigation
- **Desktop**: Fixed sidebar with icons + labels
- **Mobile**: Bottom navigation bar (iOS-style)

#### Statistics
- **Chart Scaling**: Recharts responsive containers
- **Tab Navigation**: Horizontal scroll on small screens
- **Export Banner**: Collapsible on mobile

**Testing Coverage:**
- ✅ iPhone SE (375px)
- ✅ iPhone 12/13 Pro (390px)
- ✅ iPad (768px)
- ✅ Desktop (1920px+)

---

## 🛠 Technical Improvements

### Architecture
- **SPA Framework**: React 18 + Vite for instant dev experience
- **Type Safety**: Full TypeScript coverage
- **State Management**: TanStack Query (React Query) for server state
- **Database**: Supabase (PostgreSQL) with Row-Level Security (RLS)
- **Authentication**: Supabase Auth with JWT

### Component Library
- **UI Framework**: shadcn/ui (Radix Primitives)
- **Styling**: Tailwind CSS with custom design tokens
- **Icons**: Lucide React (tree-shakeable)
- **Charts**: Recharts with custom themes
- **Animations**: Framer Motion for micro-interactions

### Best Practices
- ✅ **Absolute Imports**: `@/` alias for clean imports
- ✅ **Functional Components**: Hooks-based architecture
- ✅ **Date Handling**: date-fns for reliable manipulation
- ✅ **Error Handling**: Toast notifications + console logging
- ✅ **Code Quality**: ESLint + TypeScript strict mode

### Performance
- ⚡ **Lazy Loading**: Code splitting for route-based chunks
- 🗜️ **Optimized Builds**: Vite's Rollup bundler
- 💾 **LocalStorage**: Persistent preferences
- 🔄 **Infinite Pagination**: Efficient large dataset handling

### Database Schema
**Key Tables:**
- `goals`: Habit definitions (title, color, frequency, dates)
- `goal_logs`: Daily entries (status, value, date)
- `macro_goals`: Long-term objectives (type, category, year)
- `mood_logs`: Emotional tracking (mood, energy, notes)

**Critical Logic:**
- **Soft Delete**: `end_date` for habits with history
- **Frequency Array**: `[1,3,5]` for Mon/Wed/Fri
- **Status Enum**: 'done' | 'missed' | 'skipped'

> 📁 **Schema**: `schema.sql` (full setup script)

---

## 🧰 Tech Stack

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Framework** | React | 18.3.1 | UI library |
| **Build Tool** | Vite | 7.3.1 | Dev server + bundler |
| **Language** | TypeScript | 5.8.3 | Type safety |
| **Styling** | Tailwind CSS | 3.4.17 | Utility-first CSS |
| **Components** | shadcn/ui | Latest | Radix-based UI kit |
| **Backend** | Supabase | 2.87.1 | Database + Auth |
| **State** | TanStack Query | 5.83.0 | Server state |
| **Routing** | React Router | 6.30.1 | Client-side routing |
| **Charts** | Recharts | 2.15.4 | Data visualization |

| **Icons** | Lucide React | 0.462.0 | Icon library |
| **Animation** | Framer Motion | 12.26.2 | Motion library |
| **Forms** | React Hook Form | 7.61.1 | Form handling |
| **Validation** | Zod | 3.25.76 | Schema validation |
| **Dates** | date-fns | 3.6.0 | Date utilities |

---

## 📦 Installation

### Prerequisites
```bash
# Node.js 18+ required
node --version
```

### Quick Start
```bash
# 1. Clone repository
git clone https://github.com/simo-hue/habit-tracker.git
cd habit-tracker

# 2. Install dependencies
npm install

# 3. Configure environment
cp .env.example .env
# Edit .env with your Supabase credentials

# 4. Run database migrations
# Import schema.sql in your Supabase project

# 5. Start dev server
npm run dev
```

---

## ⚠️ Known Issues

| Issue | Impact | Workaround | Status |
|-------|--------|------------|--------|
| Large datasets (100k+ logs) | Initial load 2-3s | Recursive pagination implemented | Resolved |
| Export banner overflow | Minimal on very small screens | Scroll horizontally | Low Priority |

---

## 🎉 What's Next?

### Planned for v1.1.0
- 🤖 **AI Coach**: Local LLM integration with Ollama
- 🗣️ **Multi-Language**: English/Italian auto-detection
- 🎨 **Custom Themes**: User-defined color schemes
- 📊 **Advanced Correlations**: Habit interdependencies
- 🔔 **Smart Notifications**: Streak reminders

### Long-Term Vision
- 🌐 **Progressive Web App (PWA)**: Offline-first capabilities
- 🔗 **Third-Party Integrations**: Fitness trackers, calendar sync
- 📈 **Predictive Analytics**: ML-based success forecasting
- 👥 **Social Features** (Optional): Accountability partners

---

## 🤝 Contributing

We welcome contributions! See our [Contributing Guide](./docs/CONTRIBUTING.md) for:
- Code style guidelines
- Development workflow
- Pull request process
- Issue templates

---

## 📄 License

**MIT License** - You are free to use, modify, and distribute this software.

---

## 🙏 Acknowledgments

Built with ❤️, ☕, and **obsessive attention to detail**.

**Special Thanks:**
- James Clear for the "Atomic Habits" philosophy
- The shadcn/ui team for the incredible component library
- Supabase for making backend simple
- The open-source community

---

<div align="center">

**Mattioli.OS v1.0.0** | January 2026  
*Master Your Discipline. Own Your Data. Gamify Your Growth.*

Made by **Simone Mattioli**

[📚 Documentation](./docs) • [🐛 Report Bug](./issues) • [✨ Request Feature](./issues)

</div>
