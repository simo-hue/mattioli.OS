# Manual Actions Required

- You have a running `flutter run` instance in your terminal. You need to stop it and restart it manually (`flutter run --dart-define-from-file=.env`) so that the newly added `sqflite_sqlcipher` native macOS dependencies are properly linked via CocoaPods. Hot restart might not be enough for a native dependency addition.
