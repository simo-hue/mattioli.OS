import datetime

now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
entry = f"""
- [{now}]: **App Store Connect Metadata Critical Fixes (404 URLs)**
  - *Details*: Fixed broken Support and Marketing URLs across all 38 localized languages before App Review submission. The old URLs pointed to \`wealth-compass\` which returned HTTP 404s, guaranteeing a rejection.
  - *Tech Notes*: Updated \`support_url.txt\` to \`https://simo-hue.github.io/evolve/#faq\` and \`marketing_url.txt\` to \`https://simo-hue.github.io/evolve/\`. Uploaded via \`fastlane deliver\`.
"""

with open('/Users/simo/Downloads/DEV/mattioli.OS/DOCUMENTATION.md', 'a') as f:
    f.write(entry)
