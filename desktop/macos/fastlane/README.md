fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac release

```sh
[bundle exec] fastlane mac release
```

Build and upload a new macOS release to App Store Connect

### mac build_for_transporter

```sh
[bundle exec] fastlane mac build_for_transporter
```

Build the .pkg for Transporter upload

### mac update_notes

```sh
[bundle exec] fastlane mac update_notes
```

Aggiorna 'What's New in This Version' per macOS

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
