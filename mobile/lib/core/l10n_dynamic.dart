import 'package:flutter/widgets.dart';
import '../i18n/translations.g.dart';

/// Localized lookups for values that are computed at runtime (day/month names,
/// tab keys, sort keys). These replace the legacy `context.l10n.translate(<var>)`
/// dynamic calls so the runtime `translate()` shim can be removed.

String tWeekday(BuildContext c, String? day) {
  final w = c.t.common.weekdays;
  switch ((day ?? '').toLowerCase()) {
    case 'monday':
    case 'mon':
    case 'lunedì':
    case 'lunedi':
      return w.monday;
    case 'tuesday':
    case 'tue':
    case 'martedì':
    case 'martedi':
      return w.tuesday;
    case 'wednesday':
    case 'wed':
    case 'mercoledì':
    case 'mercoledi':
      return w.wednesday;
    case 'thursday':
    case 'thu':
    case 'giovedì':
    case 'giovedi':
      return w.thursday;
    case 'friday':
    case 'fri':
    case 'venerdì':
    case 'venerdi':
      return w.friday;
    case 'saturday':
    case 'sat':
    case 'sabato':
      return w.saturday;
    case 'sunday':
    case 'sun':
    case 'domenica':
      return w.sunday;
    default:
      return day ?? '';
  }
}

String tWeekdayShort(BuildContext c, String key) {
  final w = c.t.common.weekdaysShort;
  switch (key) {
    case 'mon':
      return w.mon;
    case 'tue':
      return w.tue;
    case 'wed':
      return w.wed;
    case 'thu':
      return w.thu;
    case 'fri':
      return w.fri;
    case 'sat':
      return w.sat;
    case 'sun':
      return w.sun;
    default:
      return key;
  }
}

String tStatTab(BuildContext c, String tab) {
  final t = c.t.statistics.tabs;
  switch (tab) {
    case 'Info':
      return t.info;
    case 'Trend':
      return t.trend;
    case 'Alert':
      return t.alert;
    case 'Abitudini':
      return t.habits;
    case 'Mood':
      return t.mood;
    case 'Stats':
      return t.stats;
    default:
      return tab;
  }
}

String tSortBy(BuildContext c, String val) {
  final s = c.t.statistics.sortOptions;
  switch (val) {
    case 'rate':
      return s.rate;
    case 'best_streak_label':
      return s.bestStreak;
    case 'worst_streak_label':
      return s.worstStreak;
    case 'current_streak_label':
      return s.currentStreak;
    case 'first_name':
      return s.name;
    default:
      return val.replaceAll('_', ' ');
  }
}
