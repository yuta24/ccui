#!/bin/bash
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="${1:-ccui}"
CONFIG="${2:-Debug}"
DERIVED_DATA_PATH="$PROJECT_DIR/.build"

xcodebuild test \
  -project "$PROJECT_DIR/ccui.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:ccuiTests \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 \
  | xcbeautify

exit ${PIPESTATUS[0]}
