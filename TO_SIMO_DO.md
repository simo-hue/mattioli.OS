# TO_SIMO_DO.md
- [ ] Local AI Models ( Ollama for desktop? Other solutions? For mobile what can we do? )

## DESKTOP + MOBILE — iCloud sync cross-platform (needs your Xcode machine)

All code is done and committed (see `desktop/ICLOUD_SYNC_PLAN.md` §3b). The steps
below are the Apple-side setup and device QA that cannot be done from this dev
environment (no Xcode here; the macOS Swift bridge is `swiftc`-typechecked but
not compiled).

### 1. Xcode capabilities (one-time)
- [ ] **mobile/ios Runner target** → Signing & Capabilities → add **Keychain
      Sharing** with group `com.simo.evolve.sync` (the entitlements file already
      lists `$(AppIdentifierPrefix)com.simo.evolve` + `…sync`; the capability
      toggle makes Xcode/provisioning accept it). iCloud/CloudKit capability is
      already there from 1.0.8.
- [ ] **desktop/macos Runner target** → Signing & Capabilities → add **iCloud
      (CloudKit)** with container `iCloud.com.simo.evolve` (existing container,
      same team) **and Keychain Sharing** with groups
      `com.simo.evolve.evolveDesktop` + `com.simo.evolve.sync` — must match
      DebugProfile.entitlements / Release.entitlements, which are already
      updated. Signing team `8528AN28A3`.
- [ ] Desktop deployment target was raised to **macOS 12.3** (CloudKit APIs) —
      pbxproj + Podfile already changed; run `pod install` in `desktop/macos`
      and check the build.
- [ ] `cd desktop && flutter build macos` (first compile of the Swift bridge —
      it typechecks, but this is the real gate).

### 2. CloudKit Console (before ANY release with avatars)
- [ ] In the `iCloud.com.simo.evolve` container: verify record type
      `PrivateRecord` exists with fields `tableName(String)`, `updatedAt(Int64)`,
      `deleted(Int64)`, `payload(Bytes)` **and `asset(Asset)`** in **Development**
      (a dev-build sync with an avatar creates it automatically), then
      **Deploy Schema Changes → Production**. The `asset` field is NEW in this
      release — without promoting it, avatar sync fails in Production.

### 3. Two-pass QA matrix (per the sequencing decision)
Pass A — both apps Xcode-run (**Development** environment):
- [ ] Mac first-enable: creates key/owner/keycheck; iPhone (dev build) adopts and pulls all.
- [ ] iPhone-had-data + Mac-had-data → union merge, no data loss, owner unified.
- [ ] Edit on iPhone → appears on Mac ≤15 min (periodic) or on window refocus / after-write on the other side.
- [ ] Avatar: set on iPhone → appears on Mac (and reverse); remove propagates.
- [ ] Edit-vs-delete LWW; offline edits converge on reconnect.
- [ ] Delete private data on Mac with sync on → confirm dialog shows the multi-device note; zone wiped; iPhone stops syncing (keycheck/key gone); local iPhone copy intact.
- [ ] Old-iOS simulation (1.0.9 build) + new Mac → Mac shows "Waiting for iCloud Keychain — make sure the app on your iPhone is up to date"; updating the iPhone app unblocks it.
- [ ] macOS sandbox: avatar CKAsset upload/download temp files work (flagged risk).

Pass B — **TestFlight iOS 1.0.10 + TestFlight Mac** (Production environment) — release gate:
- [ ] Repeat the core matrix (fresh pull, merge, edit propagation, avatar, delete).

### 4. Release sequencing (locked in the design interview)
- [ ] Submit **mobile 1.0.10 (build 14)** once 1.0.9 clears review — it carries the shared-keychain migration; restore the real gitignored configs first (supabase/sentry/openrouter, see apple/TO_SIMO_DO.md §1).
- [ ] Create the **separate Mac App Store product** (bundle `com.simo.evolve.evolveDesktop`; universal purchase impossible — bundle ids differ). Privacy answers mirror iOS: data syncs via the user's iCloud, E2E encrypted, no third-party servers; re-confirm `ITSAppUsesNonExemptEncryption`.
- [ ] Submit the Mac app **only after 1.0.10 is live**.

## MOBILE
- [ ] (nothing else pending)

---

fastlane ios update_notes
