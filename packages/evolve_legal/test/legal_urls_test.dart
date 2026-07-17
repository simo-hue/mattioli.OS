import 'package:evolve_legal/evolve_legal.dart';
import 'package:test/test.dart';

void main() {
  group('LegalUrls', () {
    test('Italian is served from the site root — this URL must never move', () {
      // iOS 1.1.2 build 20 is on the App Store with this exact URL compiled in.
      // If this test fails, the mandatory privacy link is dead in every copy of
      // the app already on people's phones.
      expect(
        LegalUrls.privacy('it').toString(),
        'https://simo-hue.github.io/evolve/privacy.html',
      );
    });

    test('each published language resolves to its own directory', () {
      expect(
        LegalUrls.privacy('en').toString(),
        'https://simo-hue.github.io/evolve/en/privacy.html',
      );
      expect(
        LegalUrls.support('de').toString(),
        'https://simo-hue.github.io/evolve/de/support.html',
      );
      expect(
        LegalUrls.terms('ar').toString(),
        'https://simo-hue.github.io/evolve/ar/terms.html',
      );
    });

    test('an unpublished language falls back to the root, not a 404', () {
      // Apple accepts a fallback language. It does not accept a dead link.
      for (final lang in ['fr', 'ja', 'pt', '', 'zz']) {
        expect(
          LegalUrls.privacy(lang).toString(),
          'https://simo-hue.github.io/evolve/privacy.html',
          reason: '"$lang" has no directory on the site',
        );
      }
    });

    test('terms and privacy are different documents in every language', () {
      // Three separate call sites used to label a link "Terms of Service" and
      // open the privacy policy. That is not a functional Terms link.
      for (final lang in ['it', 'en', 'es', 'de', 'ar']) {
        expect(
          LegalUrls.terms(lang),
          isNot(LegalUrls.privacy(lang)),
          reason: 'terms and privacy collided for "$lang"',
        );
      }
    });

    test('the EULA is Apple\'s, not our Terms of Service', () {
      // Designating terms.html as the EULA would oblige it to carry Apple's
      // minimum terms; it carries none of them.
      expect(
        LegalUrls.appleEula.toString(),
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      );
      for (final lang in ['it', 'en']) {
        expect(LegalUrls.appleEula, isNot(LegalUrls.terms(lang)));
      }
    });

    test('every page is https and on the real site', () {
      final urls = [
        for (final lang in ['it', 'en', 'es', 'de', 'ar']) ...[
          LegalUrls.privacy(lang),
          LegalUrls.terms(lang),
          LegalUrls.support(lang),
          LegalUrls.cookies(lang),
        ],
      ];
      for (final u in urls) {
        expect(u.scheme, 'https', reason: '$u');
        expect(u.host, 'simo-hue.github.io', reason: '$u');
        // The old privacy links pointed at a path built from a repo name; a
        // rename would silently break them. Assert the real deployed base.
        expect(u.path, startsWith('/evolve/'), reason: '$u');
      }
    });

    test('subscriptions are managed at Apple, since only Apple can cancel them', () {
      expect(
        LegalUrls.manageSubscriptions.toString(),
        'https://apps.apple.com/account/subscriptions',
      );
    });

    test('the support mailto carries the address the site advertises', () {
      expect(LegalUrls.supportEmail, 'mattioli.simone.10@gmail.com');
      expect(
        LegalUrls.supportMailto().toString(),
        'mailto:mattioli.simone.10@gmail.com',
      );
    });
  });
}
