/// Typeface stacks for the places the app does NOT use Inter.
///
/// Every glyph this app draws now comes from a font that is either bundled with
/// it or already present on the device. Nothing is fetched.
///
/// That is a privacy requirement, not a preference. The app used to render type
/// through the `google_fonts` package, which downloads its families from
/// `fonts.gstatic.com` the first time each one is used — so the very first
/// screen, the consent gate, opened a connection to Google before the user had
/// agreed to anything, while displaying the sentence that promises it does not.
/// App Review has already rejected this app twice under Guideline 5.1.2. The
/// dependency was removed rather than disabled: a configuration flag
/// (`GoogleFonts.config.allowRuntimeFetching = false`) has to be set before the
/// first glyph resolves and can be undone by any future call site or package
/// update, whereas a package that is not in `pubspec.yaml` cannot make a
/// request at all.
///
/// **Inter** is bundled and declared in `pubspec.yaml` under the family name
/// `Inter`; reference it with `fontFamily: 'Inter'`, as the rest of the codebase
/// already does in ~215 places. It needs nothing from this file.
///
/// The two stacks below replace families the repo has no binaries for. Each
/// names a face that ships with iOS first and degrades through the generic
/// aliases, so Android and macOS resolve sensibly too.
library;

/// Monospace, for content whose columns must line up — log output, stack traces,
/// error details. Replaces JetBrains Mono and Fira Code.
///
/// `Menlo` ships with iOS and macOS; Android resolves `monospace`. Passing an
/// unresolvable family here would silently fall back to the PROPORTIONAL system
/// font, which is precisely what makes a stack trace unreadable — hence a real
/// stack rather than a single speculative name.
const String kMonospaceFontFamily = 'Menlo';

/// Fallbacks for [kMonospaceFontFamily], in resolution order.
const List<String> kMonospaceFontFallback = <String>[
  'Courier New', // iOS, macOS, Windows
  'monospace', // Android / generic alias
];

/// Serif, for the one decorative line the app has: the italic motto on the login
/// screen. Replaces Playfair Display.
///
/// `Georgia` ships with iOS and macOS and carries a true italic, which matters
/// because the call site asks for one — a family without italics would be
/// synthetically slanted and look wrong.
const String kSerifFontFamily = 'Georgia';

/// Fallbacks for [kSerifFontFamily], in resolution order.
const List<String> kSerifFontFallback = <String>[
  'Times New Roman', // iOS, macOS, Windows
  'serif', // Android / generic alias
];
