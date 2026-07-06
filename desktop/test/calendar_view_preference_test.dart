// Regression coverage for the default-calendar-view persistence fix:
// SharedPreferences and the profiles row now both store the canonical CODE
// ('mese' | 'settimana' | 'anno' | 'vita'); values persisted by older desktop
// builds (the display labels) and legacy English synonyms must keep loading.
import 'package:evolve_desktop/core/calendar_view_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeCalendarViewCode', () {
    test('keeps canonical codes unchanged', () {
      expect(normalizeCalendarViewCode('mese'), kCalendarViewMonth);
      expect(normalizeCalendarViewCode('settimana'), kCalendarViewWeek);
      expect(normalizeCalendarViewCode('anno'), kCalendarViewYear);
      expect(normalizeCalendarViewCode('vita'), kCalendarViewLife);
    });

    test('maps the English synonyms used by legacy rows', () {
      expect(normalizeCalendarViewCode('month'), kCalendarViewMonth);
      expect(normalizeCalendarViewCode('week'), kCalendarViewWeek);
      expect(normalizeCalendarViewCode('year'), kCalendarViewYear);
      expect(normalizeCalendarViewCode('life'), kCalendarViewLife);
    });

    test('maps the display labels older desktop builds stored in prefs', () {
      expect(normalizeCalendarViewCode('Mese'), kCalendarViewMonth);
      expect(normalizeCalendarViewCode('Settimana'), kCalendarViewWeek);
      expect(normalizeCalendarViewCode('Anno'), kCalendarViewYear);
      expect(normalizeCalendarViewCode('Vita'), kCalendarViewLife);
    });

    test('trims whitespace and ignores case', () {
      expect(normalizeCalendarViewCode('  MESE '), kCalendarViewMonth);
      expect(normalizeCalendarViewCode('WeEk'), kCalendarViewWeek);
    });

    test('falls back to the week code for null/unknown values', () {
      expect(normalizeCalendarViewCode(null), kCalendarViewWeek);
      expect(normalizeCalendarViewCode(''), kCalendarViewWeek);
      expect(normalizeCalendarViewCode('galactic'), kCalendarViewWeek);
    });
  });

  group('calendarViewLabel', () {
    test('maps canonical codes to the display labels', () {
      expect(calendarViewLabel('mese'), 'Mese');
      expect(calendarViewLabel('settimana'), 'Settimana');
      expect(calendarViewLabel('anno'), 'Anno');
      expect(calendarViewLabel('vita'), 'Vita');
    });

    test('is stable when given a label (legacy prefs round-trip)', () {
      for (final label in const ['Mese', 'Settimana', 'Anno', 'Vita']) {
        expect(calendarViewLabel(label), label);
        // And the label always normalizes back to the code that produced it.
        expect(
          calendarViewLabel(normalizeCalendarViewCode(label)),
          label,
        );
      }
    });

    test('defaults to Settimana for null/unknown values', () {
      expect(calendarViewLabel(null), 'Settimana');
      expect(calendarViewLabel('nonsense'), 'Settimana');
    });
  });
}
