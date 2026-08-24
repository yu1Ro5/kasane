# KASANE

KASANE is an iOS workout logging app that turns accumulated training history into enjoyable monthly and yearly Replay-style summaries.

The project is currently in the bootstrap and MVP-development phase. The app is intentionally minimal while its SwiftUI, XcodeGen, testing, and continuous-integration foundation is established. The Replay experience is the intended product differentiator, but it has not been implemented yet.

## Requirements

- macOS with Xcode 26
- XcodeGen (`brew install xcodegen`)
- An iOS 26 simulator

## Setup

Generate the Xcode project from the checked-in specification, then open it:

```sh
xcodegen generate
open KASANE.xcodeproj
```

`project.yml` is the source of truth. The generated project is intentionally ignored by Git.

## Build and test

Choose an installed iOS 26 simulator name and run:

```sh
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

GitHub Actions discovers an available iPhone simulator dynamically, so CI does not depend on a fixed simulator UUID.

## Repository structure

- `Sources/App/`: application entry point
- `Sources/Views/`: SwiftUI views
- `Sources/Models/`: domain and SwiftData models (as they are introduced)
- `Sources/Services/`: integration and persistence services
- `Sources/ViewModels/`: testable presentation state and actions
- `Tests/`: unit tests
- `project.yml`: XcodeGen project specification
- `.github/workflows/`: continuous-integration workflows
