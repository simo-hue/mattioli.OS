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

## 🍏 3. iOS App Store Privacy Resubmission (ATT & Tracking Fix)
Per superare il blocco di Apple Review riguardo all'**App Tracking Transparency (ATT)**:
1. **Configurazione App Store Connect**: Accedi ad *App Store Connect* > seleziona la tua app > vai alla sezione **Privacy dell'app** (App Privacy) nel menu a sinistra. Assicurati che per ogni dato raccolto (es. Diagnostica/Sentry, Indirizzo Email, Contenuto dell'Utente) le risposte alla domanda **"Questo dato viene utilizzato per scopi di tracciamento?" (Is this data used for tracking purposes?)** siano impostate tassativamente su **NO**. L'app infatti non fa alcun tipo di tracciamento pubblicitario o profilazione di terze parti.
2. **Note per la Review (Review Notes)**: Nel pannello di sottomissione della build (Prepare for Submission), sotto la sezione **Note di verifica** (Review Notes), inserisci questo testo in inglese per chiarire ai reviewer di Apple dove risiedono i permessi e la rimozione del prompt:
   ```text
   Hello Apple Review Team,
   
   In this build, we have completely removed the custom prompt option regarding app improvement analytics (Sentry) during onboarding to ensure full compliance with the guidelines.
   We do not perform any third-party user tracking, ad-targeting, or data sharing with third-party brokers.
   Consequently, the app does not request or require the App Tracking Transparency (ATT) permission, and there are no custom prompts related to tracking.
   
   Thank you for your time and dedication!
   ```

## 🍏 4. iOS App Store Sign in with Apple Compliance
Per superare il blocco di Apple Review relativo al design di **Sign in with Apple**:
1. Abbiamo automatizzato la cattura del nome (se condiviso dall'utente nella schermata di Apple) memorizzandolo istantaneamente nei metadata del profilo utente Supabase ed eliminato ogni dialogo di prompt manuale successivo (dialogo "Benvenuto in Evolve! Come possiamo chiamarti?") per gli utenti che usano Apple.
2. **Note per la Review (Review Notes)**: Nelle **Note di verifica** (Review Notes) su App Store Connect, aggiungi anche questo trafiletto per spiegare la risoluzione della compliance:
   ```text
   Regarding the Sign in with Apple flow:
   We have updated the authentication UX. The application now fully harvests the user's name and email directly from the Authentication Services framework during the initial sign-in and saves it directly to their user profile.
   Furthermore, any secondary or custom prompt requesting the user's name or email has been completely removed for users authenticating via Sign in with Apple, ensuring a perfectly consistent, seamless, and compliant design.
   ```
