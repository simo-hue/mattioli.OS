# 🔧 Troubleshooting Guide

Stuck? Here are the most common issues and how to solve them.

## 🔴 Database Connection Issues

### "Error: SupabaseUrl is required"
**Cause**: The application cannot find your environment variables.
**Fix**:
1. Check that `.env` exists in the root directory (not `src/`).
2. Ensure it contains `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON` (or `VITE_SUPABASE_PUBLISHABLE_KEY`).
3. Restart the dev server (`Ctrl+C` then `npm run dev`).

### "Row Level Security Policy Violation"
**Cause**: You are trying to access data that doesn't belong to the logged-in user.
**Fix**:
- Check your Supabase Policies in the dashboard.
- Ensure you are logged in using the App's login page.

## 🎨 UI/Styling Issues

### "Icons are missing"
**Cause**: `lucide-react` might not be installed or imported correctly.
**Fix**: Run `npm install lucide-react` again.

### "Tailwind styles aren't applying"
**Cause**: The `tailwind.config.ts` might be misconfigured.
**Fix**: Ensure `content` array includes `"./src/**/*.{ts,tsx}"`.

## 💾 State Issues

### "My Goals aren't loading"
**Cause**: React Query cache might be stale or the network request failed.
**Fix**:
- Open the Browser Console (F12).
- Look for red network errors.
- If it says `401 Unauthorized`, your session expired. Sign out and Sign In again.

---

## 🆘 Still Stuck?
Open an issue on GitHub or reach out to the project maintainer.
