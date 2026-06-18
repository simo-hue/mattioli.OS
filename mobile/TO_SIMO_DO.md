# PROSSIME AZIONI MANUALI (SIMO)

## Sicurezza & Privacy
- [ ] **Configurazione `url_launcher` per Android (API 30+)**:
  Se l'app punta ad Android 11+ (API 30+), devi aggiungere questo blocco nel tuo `android/app/src/main/AndroidManifest.xml` (fuori dal blocco `<application>`):
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.VIEW" />
          <data android:scheme="https" />
      </intent>
  </queries>
  ```

---

## 🚀 Pubblicazione Android (Google Play Store)

- [ ] **4. Creare la chiave di firma (Keystore)**
  Per pubblicare devi firmare l'app. Da terminale crea una chiave (salvala al sicuro e non perderla mai!):
  `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
  Segui le istruzioni e inserisci una password.

- [ ] **5. Configurare la firma nel progetto (build.gradle)**
  Crea un file chiamato `key.properties` dentro la cartella `android/` con questi dati:
  ```properties
  storePassword=<la tua password>
  keyPassword=<la tua password>
  keyAlias=upload
  storeFile=/Users/simo/upload-keystore.jks
  ```
  Modifica poi il file `android/app/build.gradle` per caricare le configurazioni della chiave come spiegato nella [documentazione ufficiale Flutter](https://docs.flutter.dev/deployment/android#configure-signing-in-gradle).

- [ ] **6. Compilare l'App Bundle (.aab)**
  Genera il pacchetto ottimizzato da caricare sullo store:
  `flutter build appbundle`
  Questo creerà un file in `build/app/outputs/bundle/release/app-release.aab`.

- [ ] **7. Configurare Google Play Console**
  - Vai su [Google Play Console](https://play.google.com/apps/publish) (costa 25$ una tantum).
  - Crea l'app e compila tutti i dati (Screenshot, Descrizioni, Rating Età).
  - Crea una nuova "Release Interna" o "Produzione" e carica il file `.aab` appena generato.
  - Invia in revisione.

---

## 2026-06-17 - Private Mode Phase 1 manual QA before release

- [ ] On iOS, complete onboarding/consent, open the login screen, choose Private mode, create habits, macro goals, custom categories, moods, profile data, settings, reminders, and export/delete private data.
- [ ] Relaunch the app and confirm the saved active mode reopens Private mode automatically without Supabase login.
- [ ] Return to login from Private mode and confirm the Supabase login/sign-up path still behaves exactly as before.
- [ ] On Android, repeat the same Private mode local-storage flow and confirm iCloud/CloudKit options are not visible.

---

## 2026-06-18 - App Store encryption/export compliance check

- [ ] Before the next iOS release, confirm App Store Connect export-compliance answers for the new SQLCipher-based local database encryption. The app uses encryption for local private data protection, so keep `ITSAppUsesNonExemptEncryption` aligned with Apple's current compliance guidance.

---

Immediately after the insertion of my name in the privacy mode the app crashes and I see this errors here in the terminal: after inserting the name to access the privacy mode I recieve this error here that I pasted in console ══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY
╞═══════════════════════════════════════════════════════════
The following assertion was thrown building
RawGestureDetector(state:
RawGestureDetectorState#f827a(gestures: [tap, long press, tap and
horizontal drag, force press],
excludeFromSemantics: true, behavior: translucent)):
A TextEditingController was used after being disposed.
Once you have called dispose() on a TextEditingController, it can
no longer be used.

The relevant error-causing widget was:
  TextField
  TextField:file:///Users/simo/Developer/mattioli.OS/mobile/lib/ui/
  screens/dashboard_screen.dart:878:23

When the exception was thrown, this was the stack:
#0      ChangeNotifier.debugAssertNotDisposed.<anonymous closure>
(package:flutter/src/foundation/change_notifier.dart:182:9)
#1      ChangeNotifier.debugAssertNotDisposed
(package:flutter/src/foundation/change_notifier.dart:189:6)
#2      ChangeNotifier.addListener
(package:flutter/src/foundation/change_notifier.dart:271:27)
#3      _MergingListenable.addListener
(package:flutter/src/foundation/change_notifier.dart:500:14)
#4      _AnimatedState.didUpdateWidget
(package:flutter/src/widgets/transitions.dart:119:25)
#5      StatefulElement.update
(package:flutter/src/widgets/framework.dart:5991:55)
#6      Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#7      SingleChildRenderObjectElement.update
(package:flutter/src/widgets/framework.dart:7122:14)
#8      Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#9      ComponentElement.performRebuild
(package:flutter/src/widgets/framework.dart:5841:16)
#10     StatefulElement.performRebuild
(package:flutter/src/widgets/framework.dart:5982:11)
#11     Element.rebuild
(package:flutter/src/widgets/framework.dart:5529:7)
#12     StatefulElement.update
(package:flutter/src/widgets/framework.dart:6007:5)
#13     Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#14     ComponentElement.performRebuild
(package:flutter/src/widgets/framework.dart:5841:16)
#15     StatefulElement.performRebuild
(package:flutter/src/widgets/framework.dart:5982:11)
#16     Element.rebuild
(package:flutter/src/widgets/framework.dart:5529:7)
#17     StatefulElement.update
(package:flutter/src/widgets/framework.dart:6007:5)
#18     Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#19     SingleChildRenderObjectElement.update
(package:flutter/src/widgets/framework.dart:7122:14)
#20     Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#21     ComponentElement.performRebuild
(package:flutter/src/widgets/framework.dart:5841:16)
#22     StatefulElement.performRebuild
(package:flutter/src/widgets/framework.dart:5982:11)
#23     Element.rebuild
(package:flutter/src/widgets/framework.dart:5529:7)
#24     StatefulElement.update
(package:flutter/src/widgets/framework.dart:6007:5)
#25     Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#26     SingleChildRenderObjectElement.update
(package:flutter/src/widgets/framework.dart:7122:14)
#27     Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#28     SingleChildRenderObjectElement.update
(package:flutter/src/widgets/framework.dart:7122:14)
#29     Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#30     SingleChildRenderObjectElement.update
(package:flutter/src/widgets/framework.dart:7122:14)
#31     Element.updateChild
(package:flutter/src/widgets/framework.dart:4037:15)
#32     ComponentElement.performRebuild
(package:flutter/src/widgets/framework.dart:5841:16)
#33     StatefulElement.performRebuild
(package:flutter/src/widgets/framework.dart:5982:11)
#34     Element.rebuild
(package:flutter/src/widgets/framework.dart:5529:7)
#35     BuildScope._tryRebuild
(package:flutter/src/widgets/framework.dart:2750:15)
#36     BuildScope._flushDirtyElements
(package:flutter/src/widgets/framework.dart:2807:11)
#37     BuildOwner.buildScope
(package:flutter/src/widgets/framework.dart:3111:18)
#38     WidgetsBinding.drawFrame
(package:flutter/src/widgets/binding.dart:1302:21)
#39     RendererBinding._handlePersistentFrameCallback
(package:flutter/src/rendering/binding.dart:495:5)
#40     SchedulerBinding._invokeFrameCallback
(package:flutter/src/scheduler/binding.dart:1430:15)
#41     SchedulerBinding.handleDrawFrame
(package:flutter/src/scheduler/binding.dart:1345:9)
#42     SchedulerBinding._handleDrawFrame
(package:flutter/src/scheduler/binding.dart:1198:5)
#43     _invoke (dart:ui/hooks.dart:356:13)
#44     PlatformDispatcher._drawFrame
(dart:ui/platform_dispatcher.dart:444:5)
#45     _drawFrame (dart:ui/hooks.dart:328:31)

═══════════════════════════════════════════════════════════════════
═════════════════════════════════

Another exception was thrown: RenderCustomMultiChildLayoutBox
object was given an infinite size during layout.
Another exception was thrown: _RenderInkFeatures object was given
an infinite size during layout.
Another exception was thrown: RenderPhysicalModel object was given
an infinite size during layout.
Another exception was thrown: RenderSemanticsAnnotations object was
given an infinite size during layout.
Another exception was thrown: RenderIgnorePointer object was given
an infinite size during layout.
Another exception was thrown: RenderTapRegion object was given an
infinite size during layout.
Another exception was thrown: RenderMouseRegion object was given an
infinite size during layout.
Another exception was thrown: A RenderFlex overflowed by Infinity
pixels on the bottom.
Another exception was thrown:
'package:flutter/src/widgets/framework.dart': Failed assertion:
line 6268 pos 12: '_dependents.isEmpty': is not true.