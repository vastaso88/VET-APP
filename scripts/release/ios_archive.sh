#!/bin/bash
# Run as the signed-in developer on macOS; no sudo, no automatic upload.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'An App Store archive requires macOS and Xcode.' >&2
  exit 1
fi
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your registered Apple team}"
if [[ $# != 2 ]]; then
  echo 'Usage: APPLE_TEAM_ID=ABCDEFGHIJ bash scripts/release/ios_archive.sh /absolute/dart-defines.json BUILD_NUMBER' >&2
  exit 1
fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
defines="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd "$root"
python3 -m scripts.ci.validate_ios_release --defines "$defines" --build-number "$2" --team-id "$APPLE_TEAM_ID"
xcodebuild -version
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
if (( ${sdk_version%%.*} < 26 )); then
  echo 'App Store submissions currently require iOS SDK 26 or newer.' >&2
  exit 1
fi
cd "$root/apps/mobile_app"
signing=ios/Flutter/Signing.xcconfig
if [[ -e "$signing" ]]; then
  echo 'Signing.xcconfig already exists; preserve it and build through Xcode.' >&2
  exit 1
fi
export_options="$(mktemp -t quokka-export).plist"
trap 'rm -f "$signing" "$export_options"' EXIT
printf 'DEVELOPMENT_TEAM = %s\nCODE_SIGN_STYLE = Automatic\n' "$APPLE_TEAM_ID" > "$signing"
cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>teamID</key><string>$APPLE_TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>uploadSymbols</key><true/>
<key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze
flutter test
flutter build ipa --release --build-number="$2" --dart-define-from-file="$defines" --export-options-plist="$export_options"
shopt -s nullglob
ipas=(build/ios/ipa/*.ipa)
if [[ ${#ipas[@]} -eq 0 ]]; then
  echo 'Archive may exist, but IPA export failed. Resolve signing in Xcode Organizer.' >&2
  exit 1
fi
codesign --verify --strict build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app
echo 'Signed IPA exported in build/ios/ipa. No upload performed.'
