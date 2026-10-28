#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
: "${SIMULATOR_ID:?Set SIMULATOR_ID to an installed iOS Simulator UUID from xcrun simctl list devices available}"
RESULT="${RESULT_BUNDLE_PATH:-$ROOT/.build/Tests-$(date +%Y%m%d-%H%M%S).xcresult}"
xcodebuild test -project ClimbingNotebook.xcodeproj -scheme ClimbingNotebook \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath .build/DerivedData -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO "$@"
