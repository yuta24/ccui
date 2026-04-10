#!/bin/bash
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="${1:-ccui}"
CONFIG="${2:-Debug}"
DERIVED_DATA_PATH="$PROJECT_DIR/.build"

xcodebuild build \
  -project "$PROJECT_DIR/ccui.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 \
  | xcbeautify

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  echo "App: $DERIVED_DATA_PATH/Build/Products/$CONFIG/$SCHEME.app"
fi

exit $EXIT_CODE
