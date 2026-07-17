/// The public legal and support pages, resolved for the app's current language.
///
/// The marketing site (github.com/simo-hue/evolve, served from GitHub Pages)
/// serves Italian from its root and every other language from its own
/// directory. Passing the app's language code therefore matters: an App Review
/// engineer on an English device must not land in an Italian privacy policy,
/// and Guideline 1.5 fired once already partly because the only support contact
/// on the whole site was buried inside the Italian privacy page.
///
/// Two hard constraints:
///
/// 1. **The Italian pages live at the site root and must never move.** Builds
///    already on the App Store (iOS 1.1.2 build 20) hardcode
///    `https://simo-hue.github.io/evolve/privacy.html`. Renaming or relocating
///    it breaks the mandatory privacy link in every installed copy of the app.
/// 2. **Never point two differently-labelled links at the same page.** A link
///    labelled "Terms of Service" that opens the privacy policy is not a
///    functional Terms link — that is what Guideline 3.1.2 means, and all three
///    of the app's non-paywall terms links did exactly this.
abstract final class LegalUrls {
  const LegalUrls._();

  static const String siteBase = 'https://simo-hue.github.io/evolve/';

  /// Languages with their own directory on the site. Italian is absent because
  /// it is served from the root — see constraint 1 above.
  static const Set<String> localisedLanguages = {'en', 'es', 'de', 'ar'};

  /// Language whose pages live at the site root.
  static const String rootLanguage = 'it';

  /// Path prefix for [languageCode]; empty for the root language, and for any
  /// language we do not publish, which falls back to the root rather than
  /// linking to a 404. Apple accepts a fallback language; it does not accept a
  /// dead link.
  static String _prefix(String languageCode) =>
      localisedLanguages.contains(languageCode) ? '$languageCode/' : '';

  static Uri _page(String page, String languageCode) =>
      Uri.parse('$siteBase${_prefix(languageCode)}$page');

  /// The privacy policy. Mandatory on the paywall (Guideline 3.1.2) and named
  /// in App Store Connect's Privacy Policy URL field.
  static Uri privacy(String languageCode) => _page('privacy.html', languageCode);

  /// Our Terms of Service. NOT the EULA — see [appleEula].
  static Uri terms(String languageCode) => _page('terms.html', languageCode);

  /// The support page. This is the App Store Connect Support URL (Guideline 1.5).
  static Uri support(String languageCode) => _page('support.html', languageCode);

  static Uri cookies(String languageCode) => _page('cookie.html', languageCode);

  /// Apple's standard Terms of Use (EULA), which Apple hosts and localises.
  ///
  /// This is deliberately NOT [terms]. Designating our own Terms of Service as
  /// the EULA would oblige it to carry Apple's minimum terms — including the
  /// clause making Apple a third-party beneficiary entitled to enforce it —
  /// and it carries none of them.
  static final Uri appleEula = Uri.parse(
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );

  /// Where users manage or cancel a subscription. Subscriptions are Apple's to
  /// cancel and refund, never ours.
  static final Uri manageSubscriptions = Uri.parse(
    'https://apps.apple.com/account/subscriptions',
  );

  /// The support inbox, for surfaces where a page is the wrong affordance.
  static const String supportEmail = 'mattioli.simone.10@gmail.com';

  static Uri supportMailto() => Uri(scheme: 'mailto', path: supportEmail);
}
