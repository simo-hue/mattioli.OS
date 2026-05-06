# DOCUMENTATION.md

## [2026-05-06 18:11]: UI - Bottom Nav Bar Cleanup
*Details*: Removed the colored background gradient (selection fill) from the dynamic island bottom navigation bar for a cleaner, more minimal appearance.
*Tech Notes*:
- Removed the `AnimatedPositioned` gradient container in `AppBottomNavBar`.
- Maintained the primary color for the active icon and label to ensure clear navigation state.

---

## [2026-05-06 20:20]: Statistics - Trend Tab Premium Overhaul
*Details*: Completely refactored the Trend tab to align with the new high-end analytics design language, focusing on dynamic data visualization and fluid interactions.
*Tech Notes*:
- **Performance Evolution Chart**: 
  - Migrated from a static custom painter to a professional `LineChart` (fl_chart).
  - Implemented a functional timeframe selector with 4 distinct mock datasets.
  - Added interactive tooltips and responsive axis scaling.
- **Trend Carousel Migration**:
  - **Confronto Temporale**: Converted from a static grid to a snapping carousel with pagination dots.
  - **Abitudini Critiche**: Standardized the existing carousel to match the premium viewport and interaction model of the rest of the app.
- **Code Optimization**: Removed the deprecated `_SmoothAreaChartPainter` and cleaned up redundant card builder methods.

---

## [2026-05-06 20:10]: Statistics - Functional Timeframe Selector
*Details*: Activated the timeframe selector in the "Wellness vs Output" chart, moving beyond a UI-only state to a fully data-driven implementation.
*Tech Notes*:
- **Dynamic Data Provider**: Implemented a state-aware switch that provides unique mock datasets for 7d, 14d, 30d, and "All" timeframes.
- **Responsive Axis Mapping**: The chart now dynamically calculates its `maxX` and date label intervals based on the selected range to ensure optimal readability.
- **Visual Feedback**: Added logic to show/hide data dots depending on the density of the chart (e.g., dots are hidden in 30d/All views to reduce clutter).

---

## [2026-05-06 20:00]: Statistics - 'Wellness vs Output' Professional Redesign
*Details*: Overhauled the primary mood analytics chart, renaming it to the more professional "Wellness vs Output" and upgrading its visual presentation.
*Tech Notes*:
- **Aesthetic Upgrade**: Implemented a `glassPanelDecoration` container with a larger corner radius (24px) and removed heavy shadows for a cleaner, modern look.
- **Chart Refinement**: 
  - Simplified axes with bold, focused labels.
  - Used a more vibrant and distinct color palette (Emerald for Mood, Amber for Energy, Primary for Output).
  - Enhanced line curves and smoothing for a more sophisticated "premium" feel.
- **UX Improvements**: Added interactive tooltips and refined the legend with compact, professional styling.

## [2026-05-06 17:45]: Habit Sorting and Label Cleanup
*Details*: Fixed the habit sorting functionality in the statistics page. Previously, the sorting selector was present but didn't actually sort the habits list. Also updated the labels in the sorting selector to replace underscores with spaces for a more professional appearance. Resolved a build error in `global_alerts_tab_widget.dart` caused by extra closing braces.
*Tech Notes*:
- Implemented `_sortedHabits` getter in `_GlobalHabitsTabWidgetState` to handle sorting based on `_sortBy`.
- Updated `ListView.separated` to use `_sortedHabits`.
- Applied `.replaceAll('_', ' ')` to translated labels in `_buildSortDropdown` and `_showSortPicker`.
- Fixed syntax error in `global_alerts_tab_widget.dart`.

**Current Status**:
- Implementation complete.
- Verification build in progress.

**Next Step**:
- Confirm build success and hand over to user.

## [2026-05-06 18:36]: Goals - Performance Analysis Crash Fix
*Details*: Fixed a crash and several range errors in the Goals "Analisi Performance" tab. Improved chart stability and year filtering logic.
*Tech Notes*:
- **Chart Robustness**: Added range checks to all `fl_chart` title widgets to prevent `RangeError` when values fall outside 0-12 (months) or year list bounds.
- **Empty Stack Protection**: Updated `BarChartRodStackItem` logic to skip items with zero value, preventing potential crashes in certain `fl_chart` versions.
- **Filtering Logic**: Refined the year selector in `MacroGoalsStatsView` to strictly filter by the selected year, excluding goals with null years when a specific year is chosen.

## [2026-05-06 18:38]: Goals - RadarChart Crash Fix
*Details*: Fixed a specific assertion error in `fl_chart`'s `RadarChart` that required at least 3 data entries.
*Tech Notes*:
- Added a check in `_buildCategoryRadarCard` to return a placeholder message if the number of unique categories with goals is less than 3, preventing the assertion failure.

## [2026-05-06 18:40]: Goals - Annual Progression Chart Optimization
*Details*: Upgraded the "Progressione Annuale" bar chart with interactive tooltips and a modern "track" background for a more premium look.
*Tech Notes*:
- **Interactivity**: Added `BarTouchData` with custom `BarTouchTooltipData` to display detailed breakdown of Active, Failed, and Completed goals on tap.
- **Visual Improvements**: 
  - Implemented `backDrawRodData` (track background) to enhance depth.
  - Refined grid styling with dashed lines and reduced opacity.
  - Improved axis labels with better padding and font weights.
  - Adjusted bar width and corner radius for a more balanced aesthetic.

## [2026-05-06 18:43]: Goals - Seasonality & Monthly History Optimization
*Details*: Upgraded the Seasonality (bar) and Monthly History (line) charts with interactive tooltips and premium aesthetics.
*Tech Notes*:
- **Seasonality Chart**: 
    - Added `BarTouchData` for detailed quarterly tooltips.
    - Implemented `backDrawRodData` (tracks) for visual consistency.
    - Improved axis labels and grid styling.
- **Monthly History Chart**:
    - Added `LineTouchData` with localized month names in tooltips.
    - Enhanced line visuals with a soft gradient fill (`BarAreaData`) and smoother curves.
    - Upgraded dot painters (markers) with contrasting strokes for better visibility.
    - Refined grid lines and bolded axis labels.

## [2026-05-06 18:45]: Goals - Layout & Chart Refinement
*Details*: Separated Seasonality and Monthly charts into sequential rows for better visibility and optimized the "Mensile" bar chart for single-year views.
*Tech Notes*:
- **Layout Change**: Removed `Row` containers that paired charts horizontally, placing them vertically in the `Column` for better readability on mobile screens.
- **Monthly Bar Chart (Single Year)**:
    - Added `BarTouchData` for interactive tooltips.
    - Implemented `backDrawRodData` (tracks) for visual depth.
    - Switched to `rodStackItems` for a cleaner "composed" look (Completed vs Total).
    - Improved grid and axis labels.

## [2026-05-06 18:46]: Goals - Interest Evolution Optimization
*Details*: Upgraded the "Evoluzione Interessi" chart with interactive tooltips, tracks, and consistent premium styling.
*Tech Notes*:
- **Interactivity**: Added `BarTouchData` to show a detailed breakdown of categories per year in a tooltip.
- **Visuals**: Implemented `backDrawRodData` (tracks) and refined bar width/radius for better aesthetic alignment.
- **Styling**: Improved axis labels and grid lines for clarity and professional appearance.
