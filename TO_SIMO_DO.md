# Manual Actions Required

## 🚀 1. Deploy the Website Changes
To publish the new Privacy Policy, Terms of Service pages, and unified footers to your live site, execute the following commands in the root of the project:
```bash
# Add and commit the changes
git add .
git commit -m "feat: add privacy policy and terms of service pages"

# Push to your remote repository
git push origin main

# Deploy the React build to GitHub Pages
npm run deploy
```

## 🍏 2. Register URLs in App Store Connect
When submitting your iOS application **Evolve** in App Store Connect, configure the following fields under the **App Information** metadata section:

*   **Privacy Policy URL**:
    `https://simo-hue.github.io/mattioli.OS/privacy`
*   **Terms of Service URL** (Marketing URL / License Agreement):
    `https://simo-hue.github.io/mattioli.OS/terms`
