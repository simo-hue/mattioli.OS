# TO_SIMO_DO.md
- [ ] Local AI Models ( Ollama for desktop? Other solutions? For mobile what can we do? )
- [ ] Widget for iPhone & MacOS
- [ ] Implementing iPhone data's based like screen time, fitness ( Data iPhone already collect so I can read them )
- [ ] 

---

## [2026-07-11] Verify "swipe back" navigation (needs Xcode — unavailable on this machine)
Code is implemented and `flutter analyze` is clean on both apps, but the gesture can only be confirmed at runtime on a device/simulator.

**iOS (mobile):**
- [ ] From Profile → open each settings sub-page (Personal Info, Subscription, App Settings, Notifications, Privacy, App Logs, and Privacy → iCloud Sync) and swipe from the left edge to the right → should pop back. Previously only the main Profile/settings page and AI Chat could.
- [ ] Confirm the transition now feels native (Cupertino parallax) rather than the old 400 ms custom slide — this change is intended.

**macOS (desktop):**
- [ ] Two-finger trackpad swipe to the RIGHT on the content area → returns to the previously visited section. Also test ⌘[.
- [ ] IMPORTANT — confirm the swipe DIRECTION feels correct (right = back). If it's inverted on your trackpad, flip one sign in `desktop/lib/features/shell/presentation/desktop_shell.dart` → `_onTrackpadPanUpdate`: change `final backwardDx = isRtl ? -dx : dx;` to `isRtl ? dx : -dx`. (The pan sign couldn't be runtime-verified here without Xcode.)
- [ ] Confirm section changes (sidebar click, ⌘1-5, swipe, ⌘[) animate with a directional slide+fade, and that the swipe does not interfere with vertical scrolling or any horizontal scrollers inside charts/lists.
- [ ] FORWARD (new): after swiping back, two-finger swipe LEFT (or ⌘]) → re-enters the section you backed out of, browser-style, sliding in from the trailing edge. Confirm it's a no-op until you've gone back, and that clicking a sidebar item / ⌘-key afterwards clears the forward history (swipe-left then does nothing). Forward uses the same pan sign as back — if you flipped the back sign above, forward follows automatically.

