#!/bin/bash
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="${1:-ccui}"
CONFIG="${2:-Debug}"

xcodebuild build \
  -project "$PROJECT_DIR/ccui.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 \
  | xcbeautify

exit ${PIPESTATUS[0]}
