# DOCUMENTATION.md

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
