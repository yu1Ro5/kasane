# KASANE agent guide

This file guides AI coding agents working in this repository.

## Project overview

KASANE is an iOS workout logger whose planned differentiator is monthly and yearly Replay-style training summaries. It uses SwiftUI, adopts SwiftData for persistence as models are introduced, and follows an MVVM-oriented architecture. XcodeGen generates `KASANE.xcodeproj` from `project.yml`.

## Repository layout

- `Sources/App/`: app lifecycle and dependency composition
- `Sources/Models/`: SwiftData and domain models
- `Sources/Services/`: persistence and external integrations
- `Sources/ViewModels/`: presentation state and business actions
- `Sources/Views/`: SwiftUI views
- `Sources/Assets.xcassets/`: app assets
- `Tests/`: unit tests
- `project.yml`: source of truth for Xcode project configuration
- `.github/workflows/`: continuous integration

Empty architecture directories need not be committed. Add files to the appropriate directory when that layer is needed.

## XcodeGen workflow

Do not edit or commit a generated `.xcodeproj`. After adding, removing, or moving source files, regenerate it:

```sh
brew install xcodegen
xcodegen generate
open KASANE.xcodeproj
```

## Build and test

Use an available iOS 26 simulator on the local machine:

```sh
xcodegen generate
xcodebuild -project KASANE.xcodeproj \
  -scheme KASANE \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project KASANE.xcodeproj \
  -scheme KASANE \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Simulator names vary between Xcode releases. Check `xcrun simctl list devices available` and substitute an installed device when necessary. CI must build and test generated projects and must not rely on a hard-coded simulator UUID.

## Architecture and naming

- Keep Views focused on rendering UI and forwarding user actions.
- Put state and business logic in testable ViewModels, Models, or Services rather than Views.
- Name SwiftUI views `SomethingView` and view models `SomethingViewModel`.
- Prefer small types with explicit responsibilities and dependency injection over global state.
- Do not use force unwraps (`!`) or forced tries (`try!`). Handle failures explicitly.
- Add focused unit tests for business behavior; avoid large, meaningless scaffolding.

## Formatting and CI

Format Swift with the repository configuration before submitting changes:

```sh
swift-format format --in-place --configuration .swift-format --recursive Sources Tests
```

Use four-space indentation, preserve trailing newlines, and keep imports ordered. Pull requests are expected to pass the XcodeGen generation, simulator build, and unit-test steps in `.github/workflows/ios-build.yml`.

## Security

Never commit secrets, credentials, API keys, certificates, provisioning profiles, or private signing material. Keep code signing disabled for CI simulator builds.
