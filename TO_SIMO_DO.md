# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Different habits & goals types, not only checkboxes like status,progress bar
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] mobile animation between lateral scroll on the goals page? Improve it

## prompt to run 1
/grill-me we are working on the mobile and desktop flutter implementations. I've activated the iCloud sync but I saw that not everything is being synchronized, an example are the Goals. Is there anything else that's missing? As I want to save all the important things there not only a part. My case is that I've imported the goals ( in privacy mode ) but they haven't sync.

## prompt to run 3
/grill-me  The current desktop AI coach implementation is almost perfect: 

* privacy mode: the user needs his own open router's API KEY;
* standard mode ( user connected with supabase ) uses my API KEY so the user doesn't need to care about that. The thing that needs to be implemented is that the user must have the pro subscription to access to the AI Coach. And in addition to that I see that inside the desktop app the paywall is not implemented  ( or at least it seems as when the pop up came out and I clicked on the button to see the plans it has redirected me to the settings in the profile page ). successfully ( as the mobile, where is fully working and professional ).

The mobile implementation is different ( and it's a problem ) as I want the implementations to be coherent as they are reppresenting the same app.

The mobile has already the paywall configured perfectly but the problem is the fact that the AI coach is accessible even from non pro users and it's a problem I want you to fix.

---

# TO DOUBLE CHECK:
## prompt to run 2
/grill-me We are working on the flutter implementation, so both desktop and mobile. And as we have connected the screen time option for the auto-verifiable habits, I want you to ask this question as obviously I set a timer of 10 minutes for example on a specific app but what I was thinking about as it's obviously true at the beginning of the day. The problem is that how is handled the fact that the number obviously increases during the day? Is the habits checked every time? Or whenever it gets it first state then it's fixed and never checked again?


---

```bash
flutter run -d macos --dart-define-from-file=.env
flutter build macos --release --dart-define-from-file=.env
```

## Screen Time Auto-Verification Sync
- Since background network requests are forbidden in the iOS `DeviceActivityMonitorExtension`, the iOS app *must* be opened by the user periodically to sync the Screen Time habits to Supabase, which then reflects on the macOS app.