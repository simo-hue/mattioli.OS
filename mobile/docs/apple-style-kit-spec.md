# Apple-Style UI Kit — Implementation Spec (mobile)

Status: **Finalized, ready to implement.** Owner: Simo. Scope agreed via grill-me session.

## 0. Goal & guardrails

Make three surfaces feel authentically Apple, via **one shared reusable kit**, then stop
(other surfaces come later as a separate pass).

- **Strategy:** Cupertino *look* on Material *scaffolding* — no stock `CupertinoActionSheet`/
  `CupertinoPicker`, no native platform channels.
- **Cross-platform:** changes are **NOT** gated on `Platform.isIOS`. This becomes the app's
  design language on both iOS and Android.
- **No new dependencies.** Keep `flutter_colorpicker` (restyled). `cupertino_icons` already present.
- **No theme rename.** Kit builds on the existing `context.appColors` / `AppColors`. We do **not**
  rename mobile theming to `Evolve*` (that's an app-wide refactor, out of scope, zero payoff here).

## 1. The kit — `lib/ui/kit/`

New layer sibling to `screens/` and `widgets/`. `Evolve`-prefixed API, mirroring desktop
(`desktop/lib/shared/widgets/evolve_controls.dart`, `color_picker_dialog.dart`) so the two
platforms share names.

### 1a. `lib/ui/kit/evolve_sheet.dart`

**`showEvolveSheet<T>({context, title, builder, ...}) → Future<T?>`** — modal bottom sheet:
- **Grabber** 36×5, `appColors.border`, radius 2.5, centered, ~8px top padding.
- **Header title** — Inter **17 / w600**, centered, `appColors.foreground`. Replaces the old
  10px uppercase micro-label. **No Cancel/Done** (selection lists are tap-to-dismiss).
- **Background** solid `appColors.card`, top corners radius **24**.
- **Detents** via `DraggableScrollableSheet`: `initial 0.6, min 0.4, max 0.92`, `expand: false`
  (sizes to content up to the detent; drags to large).

**`showEvolveEditorSheet<T>({context, title, builder, onCancel, onDone, ...}) → Future<T?>`** —
same chrome **plus** a nav-style header: **Cancel** (left, `mutedForeground`) / title (center) /
**Done** (right, accent, w600). For create/edit forms. Returns value on Done, `null` on Cancel.

**`EvolveListSection`** — grouped-inset container: `appColors.card`, radius ~14, hairline
`appColors.border`, inset **16px** horizontal, children separated by hairline dividers that start
after the leading icon-tile.

**`EvolveListRow`** — a **`ConsumerWidget`** (owns its own `ref` so it fires *gated* haptics
internally, no caller plumbing):
- Leading **icon-tile** 28×28, radius 8, bg = item color @ alpha 0.2 (or `muted` for neutral),
  centered glyph 15–16 — **or** a leading color dot for color rows.
- Title Inter **17 / w400** (**w600 when selected**), `foreground`.
- Optional subtitle Inter 13 `mutedForeground`; optional trailing widget.
- Selected → trailing **`CupertinoIcons.check_mark`**, size 18, tinted **`colorScheme.primary`**
  (accent). Drill-in rows → trailing **`CupertinoIcons.chevron_right`**, size 14, `mutedForeground`.
- `onTap` fires **`Haptics.selectionClick(ref)`** then the callback.

### 1b. `lib/ui/kit/evolve_color_picker.dart`

**Palette (mirror desktop, 6):**
```dart
const kEvolveDefaultPalette = [
  Color(0xFFEF4444), Color(0xFFEAB308), Color(0xFF22C55E),
  Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFFA855F7),
];
```

**`EvolveColorSwatchGrid({palette, selected, onChanged, showCustom = true, isLocked?, onLockedTap?})`**
— the everyday control:
- Solid color **circles**; selected shows an inset checkmark; tap fires `Haptics.selectionClick(ref)`.
- Off-palette `selected` (a prior custom color) renders as an extra selected chip so it's never lost.
- `showCustom` → trailing **"Custom"** cell (`+`) → `showEvolveColorPicker`.
- **Per-cell locking hook** (`isLocked` / `onLockedTap`) so the accent site keeps its exact Pro
  monetization behavior (gold-locked cells → `ProFeaturesModal`).

**`showEvolveColorPicker(BuildContext, Color initial) → Future<Color?>`** — mirrors desktop
signature exactly. The **custom escape hatch**: restyled `flutter_colorpicker` `ColorPicker`
(`enableAlpha: false`, `labelTypes: const []`, `displayThumbColor: true`) inside a kit
**editor sheet** (Cancel/Done). Returns picked color on Done, `null` on Cancel.

## 2. Blast radius — files changed

| # | File | Change |
|---|------|--------|
| 1 | `lib/ui/kit/*` | **New** kit (§1). |
| 2 | `lib/ui/screens/statistics_screen.dart` | "Select Habit" (`_showGoalSelector`, ~728) → `showEvolveSheet` + `EvolveListSection`/`EvolveListRow`. **Preserve** "All habits" row, Pro-lock rows (lock glyph + `ProFeaturesModal` → reset to All), selected highlight. |
| 3 | `lib/ui/widgets/macro_goals/category_picker_sheet.dart` | Sheet → kit sheet + rows (**preserve** none-row, linked-goals count, edit/delete, "create new category", archive semantics). **Editor** `Dialog` → **`showEvolveEditorSheet`** (Cancel/Done) — keep the pre-captured-notifier post-dispose-safe pattern. Swatches + `_showColorPickerDialog` → `EvolveColorSwatchGrid` + `showEvolveColorPicker`. **Delete confirm** `AlertDialog` → **`CupertinoAlertDialog`** (destructive red "Archive", `isDestructiveAction: true`; keep linked-count messaging). |
| 4 | `lib/ui/widgets/habit_management_modal.dart` | Color section → `EvolveColorSwatchGrid` + `showEvolveColorPicker`. **Preserve** `computeLuminance()` contrast handling for arbitrary colors. |
| 5 | `lib/ui/screens/app_settings_screen.dart` | Accent → `EvolveColorSwatchGrid` with **`palette: premiumAccentColors`** + locking hook. **Preserve** Pro gating (free 3 + custom locked → `ProFeaturesModal`) and `setAccentColor`. |

## 3. Interaction & type rules (apply inside the kit)

- **Typography:** keep **Inter**; iOS scale — 17 body / 15 subhead / 13 footnote, semibold titles.
  Eliminate uppercase letter-spaced micro-labels.
- **Icons:** surgical **`CupertinoIcons`** for **checkmark** + **chevron** only. Lucide stays for
  everything else (content, brand, pencil/trash actions).
- **Haptics (gated, via `lib/core/haptics.dart`):** `Haptics.selectionClick(ref)` on every row tap
  **and** every swatch tap; `Haptics.mediumImpact(ref)` on editor commit (save/create).
- **Selection state:** checkmark + any selected tint = **accent** (`colorScheme.primary`),
  replacing today's `foreground`/`primary`/`white` mix.

## 4. Non-goals (the boundary)

- ✗ Renaming `AppColors`/`context.appColors` → `Evolve*`.
- ✗ Migrating the other ~12 `showModalBottomSheet` sheets (kit is built to absorb them later).
- ✗ New dependencies. ✗ `Platform.isIOS` gating.

## 5. Implementation order

1. Build `evolve_color_picker.dart` (palette + grid + hatch) — highest reuse.
2. Build `evolve_sheet.dart` (sheet + section + row).
3. Migrate 3 color sites (habit, category editor, accent).
4. Migrate "Select Habit".
5. Migrate "Choose category" sheet + editor→sheet + delete→CupertinoAlertDialog.

## 6. Verification (per implementation)

- `flutter analyze` clean; `flutter build` (or `flutter test`) passes.
- Compiling/testing needs the 4 gitignored/generated files noted in project memory
  (`mobile-gitignored-build-configs`) — restore before building.
- Visual tests: **owner (Simo)** handles device/simulator visual QA.
- Behavior-parity checklist to re-verify: All-habits row + Pro lock flow; category none-row /
  linked count / edit / delete-archive / create; accent Pro gating; habit custom-color contrast.
