#!/bin/zsh

set -euo pipefail

echo "=== Xcode Cloud post-clone ==="

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Repository: $PWD"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen..."
  brew install xcodegen
fi

echo "XcodeGen version:"
xcodegen --version

echo "Generating KASANE.xcodeproj..."
xcodegen generate --spec project.yml

test -d KASANE.xcodeproj

echo "Generated project:"
xcodebuild -project KASANE.xcodeproj -list
