/// Pure mapping helpers for the "default calendar view" preference.
///
/// The preference is persisted as a canonical CODE (`mese` | `settimana` |
/// `anno` | `vita`) in BOTH SharedPreferences and the profiles row (cloud and
/// Private mode), matching the mobile client. The desktop settings UI shows
/// the display labels (`Mese`, `Settimana`, `Anno`, `Vita`).
///
/// [normalizeCalendarViewCode] also accepts what older desktop builds stored
/// in SharedPreferences (the display LABELS) and the English synonyms some
/// legacy rows used (`month`/`week`/`year`/`life`), so previously persisted
/// values keep loading correctly.
library;

const kCalendarViewMonth = 'mese';
const kCalendarViewWeek = 'settimana';
const kCalendarViewYear = 'anno';
const kCalendarViewLife = 'vita';

/// Maps any persisted value — canonical code, English synonym, or legacy
/// display label — to the canonical code. Unknown/absent values fall back to
/// [kCalendarViewWeek], the historical desktop default.
String normalizeCalendarViewCode(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'mese' || 'month' => kCalendarViewMonth,
    'anno' || 'year' => kCalendarViewYear,
    'vita' || 'life' => kCalendarViewLife,
    'settimana' || 'week' => kCalendarViewWeek,
    _ => kCalendarViewWeek,
  };
}

/// Display label for any persisted value (normalized first, so labels, codes
/// and English synonyms all resolve).
String calendarViewLabel(String? value) {
  return switch (normalizeCalendarViewCode(value)) {
    kCalendarViewMonth => 'Mese',
    kCalendarViewYear => 'Anno',
    kCalendarViewLife => 'Vita',
    _ => 'Settimana',
  };
}
