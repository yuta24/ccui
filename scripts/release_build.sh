#!/bin/bash
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ccui"
CONFIG="Release"
DERIVED_DATA_PATH="$PROJECT_DIR/.build"
ARCHIVE_PATH="$DERIVED_DATA_PATH/ccui.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build"

VERSION="${1:?Usage: $0 <version> <build_number>}"
BUILD_NUMBER="${2:?Usage: $0 <version> <build_number>}"

xcodebuild archive \
  -project "$PROJECT_DIR/ccui.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipPackagePluginValidation \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  2>&1 \
  | xcbeautify

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  exit $EXIT_CODE
fi

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$PROJECT_DIR/scripts/ExportOptions.plist" \
  2>&1 \
  | xcbeautify

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  echo "App: $EXPORT_PATH/$SCHEME.app"
fi

exit $EXIT_CODE
