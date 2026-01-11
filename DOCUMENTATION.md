# Documentation Log

## [Current Date] - Documentation Overhaul (Excellence Update)
- **Premium README.md**: Redesigned with:
  - Centralized "Landing Page" header.
  - "Quick Start" command block.
  - Comparison Table (Life OS vs Competitors).
  - Collapsible Feature Sections for cleaner UI.
- **Technical Deep Dive v2**:
  - Added **Mermaid.js** diagrams for System Architecture and Auth Flow.
  - Clarified State Management decisions.
- **New Standard Files**:
  - `docs/CONTRIBUTING.md`: Guidelines for open source contribution.
  - `docs/TROUBLESHOOTING.md`: Common error resolution guide.
  - `docs/assets/Daily Tasks view mensile.png`: Main dashboard preview.
  - `docs/assets/...`: Comprehensive screenshot gallery for Daily Tasks and Macro Goals.
- **Asset Requests**: Updated `TO_SIMO_DO.md` to request GIFs for higher visual impact.
- **UI Improvements**:
  - **Calendar**: Fixed desktop responsive height and removed ghost tabs layout issues.
  - **Export**: Added confirmation dialog for data export.
  - **Layout**: Optimized sidebar alignment, restored natural flow, and tightened bottom spacing.
  - **Tabs**: Fixed visual alignment of tab triggers and selection highlight.
  - **Weekly View**: Aligned layout behavior with monthly view, implementing dynamic vertical stretching for habit blocks.
  - **Mobile Layout**: Implemented "Native App Shell". Finalized mobile calendar with `shrink-wrap` strategy (`h-auto`, `flex-none`). This forces the calendar card to occupy only the exact vertical space needed by its content, eliminating internal black voids while maintaining perfect cell proportions.
  - **Edge-to-Edge**: Removed bottom padding (`pb-4`) on mobile container to ensure the calendar box sits flush with the bottom of the content area, eliminating the "empty black block".
  - **Annual View**: Replaced "Daily" view with a new "Annual" view (`AnnualView.tsx`), offering a 12-month heatmap grid to visualize habit consistency over the entire year.

## 2026-01-11 - Mobile Calendar Full-Screen Fix

- **Problem**: Il calendario (mensile e settimanale) non occupava tutto lo schermo su iPhone, lasciando ampio spazio nero vuoto.
- **Root Cause**: I container usavano `flex-none` e `h-auto` su mobile invece di espandersi verticalmente.
- **Fix Applied**:
  - `Index.tsx`: Container cambiato da `flex-none lg:flex-1` a `flex-1` sempre.
  - `HabitCalendar.tsx`: Rimosso `aspect-square` dalle celle, aggiunto `h-full` al container e `flex-1` alla griglia.
- **Files Modified**: `src/pages/Index.tsx`, `src/components/HabitCalendar.tsx`
- **Additional Fix**: Aggiunto `grid-template-rows: repeat(numRows, 1fr)` dinamico per forzare tutte le righe a distribuirsi uniformemente nello spazio disponibile.
- **Layout Fix**: Modificato `Layout.tsx` per usare `h-dvh overflow-hidden` su mobile, impedendo lo scroll della pagina. Il calendario ora è vincolato all'altezza viewport.
