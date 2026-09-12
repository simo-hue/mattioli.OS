# Mobile — findings that need your decision

_From the 2026-09-03 deep scan (16 finders → per-finding adversarial verification → second
skeptic pass on the serious ones → dedup). 63 defects survived; 52 were mechanical and have been
fixed. These 8 could not be: each needs a product call, changed copy, or a change a store
screenshot would show. Nothing below has been touched._

Baseline at the time of writing: `flutter analyze` clean, 1051 tests green.

| # | Severity | Area | One line | Cost of the small option |
|---|---|---|---|---|
| [M1](#m1) | medium | Profile | Email field saves nothing, says it did | 1 line |
| [M2](#m2) | medium | Profile | Account-mode avatar is never stored | ~5 lines |
| [M3](#m3) | medium | Macro goals i18n | de/es lost the `{label}`/`{count}` tokens | 5 locale files |
| [M4](#m4) | low | Life View | Grid spans 86 years, caption says 85 | 1 line (screenshot changes) |
| [M5](#m5) | low | Private DB | Self-heal ignores a settings-only database | needs a rule from you |
| [M6](#m6) | low | Import | Private restore loses habit order | revises a written trade-off |
| [M7](#m7) | low | Import | Raw exception text shown to the user | new copy ×5 locales |
| [M8](#m8) | low | Macro goals / logs | Italian legends + English labels ship in every locale | new copy ×5 locales |

---

<a id="m1"></a>
## M1 · The Personal Info email field discards the edit and reports success · medium

`ui/screens/personal_info_screen.dart:186-207` renders an editable, **validated** email field.
`_save` (`:63-118`) writes only `full_name` and `date_of_birth`; `_emailController` is read
nowhere after `initState`. `updatePrivateProfile` has no email parameter at all, and
`grep UserAttributes(email:` over `mobile/lib` finds nothing.

The user corrects a typo in their login address, sees the success toast, the screen pops — and
reopening reseeds the field from `profile.email`, so the edit visibly reverts. The date field
right above it sets `readOnly: true`; the email field does not.

**Decide:** make the email read-only in account mode (and hide it in private mode, where
`UserProfile.email` is always null) — this matches what desktop already does at
`features/settings/presentation/panes/account_pane.dart:76-81` — **or** implement the real
`auth.updateUser(email:)` change-of-address flow with its confirmation mail.

> The read-only route is one property and needs no new capability. The real flow means handling
> the confirm-in-both-mailboxes round trip.

---

<a id="m2"></a>
## M2 · A newly picked profile photo is shown but never stored, in account mode · medium

`ui/screens/profile_screen.dart:91-117` — the whole persistence block (mkdir, copy to
`private_profile/avatar.png`, `FileImage` evict, `updatePrivateAvatar`) sits inside
`if (dataMode == private)` **with no else**. In account mode the only effect is a `setState` on
this screen's `_profileImage`, still pointing at the image picker's temp file.

So the photo appears, the dashboard header at `dashboard_screen.dart:1440` keeps rendering the
old `avatarUrl`, and popping the screen loses it. `grep avatar_url|storage.from` over `mobile/lib`
returns only private-mode writers and readers — there is no Storage upload and no write to
`profiles.avatar_url` anywhere. The camera badge advertises the affordance in both modes.

**Decide:** implement the account-mode avatar (Supabase Storage bucket + RLS policy + write
`profiles.avatar_url`) — **or** hide the camera badge and make the avatar non-tappable when not
in private mode.

> Note the cloud `avatarUrl` currently read from `meta?['avatar_url']` is only ever populated by
> an OAuth provider, so today a photo can only arrive from Google/Apple sign-in.

---

<a id="m3"></a>
## M3 · The German and Spanish archive-category dialog names the category "Label" · medium

`ui/widgets/macro_goals/category_picker_sheet.dart:283-292` builds the confirmation with
`String.replaceFirst('label', …)` / `replaceFirst('count', …)`. `de.i18n.json:965-966` translated
the tokens to `Label` / `Zählung`; `es` to `etiqueta` / `contar`. `replaceFirst` is
case-sensitive, so neither matches and the template renders untouched:

> „Die Kategorie **„Label"** wird für neue Ziele nicht mehr verfügbar sein … mit der **Zählung**
> historischer Ziele"

en/it/ar keep the literal ASCII tokens and work **by luck**. There is a latent trap even where it
works: `label` is substituted first, so a user category containing the substring `count` — e.g.
"Accountability" — would swallow the count replacement.

Separately, es/de dropped the trailing `': '` from `macroGoals.active/failed2/completed2/total`
and the leading space from `success`, so tooltips render `Aktiv3` and `67%Erfolg`.

**Decide:** convert `categoryUnavailableLinked` / `categoryUnavailableArchived` to real slang
parameters (`{label}`, `{count}`) across all 5 source locales and delete the `replaceFirst` calls
— and for the separators, either restore `': '` in es/de or move the separator into the Dart
interpolation so no locale can lose it again.

> This rewrites shipped localized copy in 2 locales for the dialog and 2 for the tooltips. The
> parameter route is the one that cannot silently break again.

---

<a id="m4"></a>
## M4 · Life View spans 86 years while its own caption says 85 · low

`ui/widgets/life_view_widget.dart:36-42`:

```dart
endYear = birthYear + 85;
totalMonths = (endYear - birthYear + 1) * 12;   // 1032
```

The dots are month-of-life indexed, not calendar-year aligned, so the inclusive `+1` has no
meaning. A 30-year-old sees REMAINING 672 months = 56 years on a grid captioned "birth … 85
years"; 85 − 30 = 55. Desktop computes `const years = 85; totalMonths = years * 12` = 1020 and
draws exactly that, so **85/1020 is the established intent on both apps**. The inflated total also
feeds the accessibility label `lifeGridLabel(lived:, total:)`.

The fix is one line — `(endYear - birthYear) * 12` — and changes no strings.

**Why you have to decide:** the grid loses 12 dots, so a store screenshot of this screen would
differ. That is your own "ask first" test.

> This is distinct from the `lifeWeeks` label item already in `TO_SIMO_DO.md`, which is the
> desktop caption. Worth resolving them together.

---

<a id="m5"></a>
## M5 · The orphaned-owner self-heal cannot rescue a settings-only database · low

`core/private_local_database.dart:506-546` — `_reconcileOrphanedOwner` scans five tables:
`goals`, `goal_logs`, `daily_moods`, `long_term_goals`, `macro_goal_categories`. `user_settings`
is a synced user-data table (`private_db_schema.dart:89-98`, added in schema v6) and was never
added to the list. Desktop carries the identical five names.

A user who has set name, photo, DOB, theme, language, week-start and notification times but has
**no habits yet**, and whose device-local owner id changes (a transient Keychain read returning
null, or a re-key whose `adoptOwner` write did not land), gets: reconcile finds zero rows,
concludes "genuinely empty / first run", returns; `_ensureProfile` seeds a fresh identity; the
profile reads blank and every synced setting falls back to its default. Nothing will ever adopt
the old id back.

**Decide the rule, because the naive fix makes things worse.** Adding `'user_settings'` to
`dataTables` would make legacy identity shells look like data owners — the v6 migration backfills
`user_settings` from the `profiles` columns for *every* `profiles` row, and `_ensureProfile`
always writes non-null `language`/`theme`/`accent`. The steady-state early return or the ambiguity
guard would then fire for a stale shell, and the reconcile would **stop rescuing habit data it
rescues today**.

Candidate rules: count only `user_settings` rows whose value differs from the seeded default; or
count a `profiles` row with a non-null `full_name`/`avatar_url`/`date_of_birth`. Whichever you
pick applies to both implementations (`desktop/lib/core/desktop_private_db.dart:2378-2384`).

> Nothing is destroyed — the rows stay on disk and remain recoverable by a correct fix.

---

<a id="m6"></a>
## M6 · A private-mode restore silently reverts habit order · low

`reorderHabits` writes only `order_key`/`order_key_updated_at`; `display_order` has been frozen
since the v12 migration and nothing maintains it. Export carries the correct keys — the comment
there states the guarantee explicitly ("Without these a backup/restore silently reverts the habit
order"). But `core/import_merge.dart:1082-1122` `_goalRow` writes `display_order` and **skips both
order columns**, so a Replace import inserts all habits with `order_key` NULL and
`backfillOrderKeys` re-keys them from the file's stale `display_order`. The list comes back in the
pre-drag order.

`_normalizeNative` and `validateCanonical` both carry the columns, and `planCloudImport` keeps
them — so the two modes disagree with each other.

**Decide:** carry `order_key`/`order_key_updated_at` on the **INSERT path only**, splitting
`_goalRow` into an insert map and an update map.

> This revises a trade-off you wrote down at `desktop/lib/core/desktop_private_db.dart:2126-2133`.
> That note reasons only about the LWW-**update** branch clobbering a position set on this device;
> it does not cover the INSERT branch, where a Replace import has just wiped the table. A fix must
> also not let a null key in the file overwrite a real one.

---

<a id="m7"></a>
## M7 · Import failure prints the raw exception to the user · low

`ui/screens/privacy_settings_screen.dart:1123-1136` renders `e.toString()` in the alert — a
PostgREST body carrying table, constraint and column names, or a full sandbox path — in English
on an Italian/Spanish/German/Arabic device. The exception is already logged one line above.

The three sibling error paths in the same file were converted to localized sentences by A7; this
one was missed. The regression guard cannot see it: `test/no_raw_exception_in_user_copy_test.dart:71-76`
requires a quoted string literal containing `$e`, so a bare `message: e.toString()` walks through.

**Decide:** add a localized `privacy.errors.importFailed` body in the "We could not X. Try again."
shape its three siblings use — new copy in 5 source locales. While there, widen the guard test's
`message:` sink to match a bare `e.toString()` argument so a fifth site cannot appear.

---

<a id="m8"></a>
## M8 · Italian legends and English labels ship in every locale · low

Five hardcoded user-facing strings in `lib/ui/`:

| Where | Renders |
|---|---|
| `macro_goals_stats_view.dart:1526-1528`, `:1815-1817` | `Attivi / Falliti / Completati`, `Compl.` — the legends under **both** stacked bar charts |
| `macro_goals_stats_view.dart:92-93` | `Performance` header |
| `add_goal_bar.dart:107-109` | picker row labelled `Default` |
| `app_logs_screen.dart:210-213` | `Share Logs File`, between two localized menu items |

`_buildLegend` renders `Text(i.label)` verbatim with no lookup, while the tooltips on the same
cards use `context.t`. The `appLogs` key set has 19 entries and no share key.

**One piece has already been fixed** as a pure autofix, because an existing key covered it:
`add_goal_bar.dart:108` `noneLabel: 'Default'` → `context.t.macroGoals.none`, matching
`goal_item_widget.dart:260`.

**Decide the rest:** add three short legend keys plus a `Performance` header key and an
`appLogs.shareFile` key across the 5 source locales — **or** reuse `macroGoals.active/failed2/completed2`
and trim the trailing `': '` at the call site. Those keys ship with a separator for tooltip use, so
they cannot be reused verbatim.

> Correction to the record: `AUDIT_2026-08-24.md` states "Checked and clean — Hardcoded
> user-facing strings: none found in `lib/ui/`". That is false. Its own coverage section lists
> these files as unaudited.
>
> Not a finding: the export-body strings at `app_logs_screen.dart:70,124` sit inside an
> all-English log dump and are not screen copy.
