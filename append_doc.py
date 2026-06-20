import datetime

now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
entry = f"""
- [{now}]: **App Store Connect Metadata Translation & Upload**
  - *Details*: Successfully downloaded current App Store Connect metadata to resolve name uniqueness conflicts, translated the release notes ("UI improvements") to 38 localized languages using Google Translate, and successfully uploaded the localized release notes to App Store Connect via Fastlane.
  - *Tech Notes*: Downloaded true metadata using `fastlane deliver download_metadata`. Translated `release_notes.txt` iteratively with `deep_translator` for all locales in `fastlane/metadata`. Uploaded securely without duplicate name conflicts via `fastlane deliver --force`.
"""

with open('/Users/simo/Downloads/DEV/mattioli.OS/DOCUMENTATION.md', 'a') as f:
    f.write(entry)
