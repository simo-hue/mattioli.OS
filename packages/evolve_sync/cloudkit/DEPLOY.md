# CloudKit schema — `iCloud.com.simo.evolve`

Importable schema + deploy runbook for the E2E-encrypted private-sync backend.

- **File to import:** [`cloudkit-production.ckdb`](./cloudkit-production.ckdb)
- **Container:** `iCloud.com.simo.evolve`
- **Purpose:** the *only* job of this container is to sync a user's own data
  (goals, logs, settings, moods, categories, profile, avatar) across **their own**
  Apple devices via **their personal iCloud private database**, end-to-end
  encrypted. No sharing, no public data, no server-side logic.

---

## Why the schema is a single generic record type

The sync engine (shared `packages/evolve_sync`, consumed by both the iOS and macOS
apps) stores **one encrypted CloudKit record per local row** in a custom zone, and
fetches deltas by **zone change token** — it never runs a `CKQuery`. So the whole
schema is one type. Ground truth: `mobile/ios/Runner/AppDelegate.swift` and
`desktop/macos/Runner/AppDelegate.swift` (`zoneName = "PrivateZone"`,
`recordType = "PrivateRecord"`).

| Field | Type | Written by | Notes |
| --- | --- | --- | --- |
| `tableName` | `STRING` | `record["tableName"]` | which local table the row came from |
| `updatedAt` | `INT64` | `record["updatedAt"]` | row edit time, epoch **ms** (LWW comparator) |
| `deleted` | `INT64` | `record["deleted"]` | tombstone flag, `0`/`1` (CloudKit has no bool) |
| `payload` | `BYTES` | `record["payload"]` | **already** AES‑256‑GCM ciphertext of the row JSON (`nonce‖ct‖tag`); empty for tombstones |
| `asset` | `ASSET` | `record["asset"]` | optional; encrypted avatar bytes only |

Field **names, types and case must match the Swift exactly** — CloudKit would
otherwise create duplicate/wrong fields on first write.

### Design choices baked into this file
- **Plain `BYTES`, not `ENCRYPTED BYTES`** — the app is already zero-knowledge E2E
  (you hold the only key, in iCloud Keychain). CloudKit never sees plaintext.
  Server-side encryption would be redundant *and* would require the Swift to use
  `record.encryptedValues[...]`, which it does not.
- **No indexes** — delta sync needs none. Nothing is queried, so nothing is
  indexed. Minimal metadata surface, and no index you'd be unable to remove later.
  (Trade-off: the CloudKit Console's *Records* tab can't query these records —
  expected, and they're opaque ciphertext anyway.)
- **`GRANT ... TO "_creator"` only** — least privilege. Security roles are
  effectively moot in a per-user private database, but no `_world` read is granted.
- **No `Users` type, no `roles` field, no zone.** `Users` is CloudKit's built-in
  type (left at its default); the app never touches it. The stray `roles LIST<INT64>`
  in the old Development export was accidental and is intentionally gone (see step 1).
  The `PrivateZone` custom zone is **created at runtime** by the app (`ensureZone`) —
  CloudKit schema files describe record types, not zones, so it correctly isn't here.

---

## Deploy runbook (owner: Simo — needs the CloudKit Console)

> One-way warning: **fields and indexes deployed to Production can never be removed.**
> That's why we purge `roles` *before* the first Production deploy.

CloudKit Console → https://icloud.developer.apple.com/dashboard → select
`iCloud.com.simo.evolve`.

### 1. Purge the stray `roles` field (Development)
Pick one:

- **Surgical (recommended, non-destructive):** Schema → **Development** → Record
  Types → `Users` → delete the custom `roles` field. (System `___…` fields can't be
  deleted; that's fine.) Leaves all other Development data intact.
- **Nuclear (pristine baseline):** Development environment → **Reset Environment**.
  Reverts Development to the Production baseline (Production has never been deployed,
  so this drops `roles` *and* clears throwaway dev test records). Use this if the
  surgical delete isn't offered or you want a clean slate.

### 2. Import this file (Development)
Schema → **Development** → use **Import Schema** (the counterpart to the *Export
Schema* you used to produce the old `.ckdb`) → choose
`packages/evolve_sync/cloudkit/cloudkit-production.ckdb`. It adds the `PrivateRecord`
type. Import is additive — it won't touch the built-in `Users` type.

### 3. Verify (Development)
Record Types now shows `PrivateRecord` with exactly `tableName` (String),
`updatedAt` (Int64), `deleted` (Int64), `payload` (Bytes), `asset` (Asset) — and
`Users` shows **no** `roles` field.

Optional live check: run a Development build on a device, enable iCloud Sync, create
a habit + set an avatar. The app creates `PrivateZone` and writes records; the
Console shows only opaque encrypted `payload`/`asset` blobs.

### 4. Deploy to Production
Schema → **Deploy Schema Changes to Production** → confirm. Production now carries a
clean `PrivateRecord` (and default `Users`) — permanently, so double-check step 3 first.

---

## Related manual prerequisites (already in code — just verify)
From `mobile/ICLOUD_SYNC_PLAN.md` §2/§14 and the entitlements files:
- iCloud + CloudKit capability, container `iCloud.com.simo.evolve` on the Runner
  targets (mobile + macos). **No** push capability (deferred).
- Keychain access groups `$(AppIdentifierPrefix)com.simo.evolve` and
  `$(AppIdentifierPrefix)com.simo.evolve.sync` (the sync secret lives in the shared
  `.sync` group so the macOS app can read it).
- App Store privacy answers: data syncs to the **user's own** iCloud; no third-party
  servers. Re-verify `ITSAppUsesNonExemptEncryption`.
