#!/bin/bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
project_file="$project/Cragfolio.xcodeproj"
derived_data="${DERIVED_DATA_PATH:-$project/.build/DerivedData}"
result_bundle="${RESULT_BUNDLE_PATH:-$project/.build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult}"

destination="${IOS_SIMULATOR_DESTINATION:-}"
if [[ -z "$destination" ]]; then
    device_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && /Booted/ { print $2; exit }')"
    if [[ -z "$device_id" ]]; then
        device_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
    fi
    if [[ -z "$device_id" ]]; then
        printf 'No available iPhone simulator. Set IOS_SIMULATOR_DESTINATION explicitly.\n' >&2
        exit 2
    fi
    destination="platform=iOS Simulator,id=$device_id"
fi

mkdir -p "$(dirname "$result_bundle")"
if [[ -e "$result_bundle" ]]; then
    printf 'Result bundle already exists; choose another RESULT_BUNDLE_PATH: %s\n' "$result_bundle" >&2
    exit 2
fi

xcodebuild \
    -project "$project_file" \
    -scheme Cragfolio \
    -destination "$destination" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$result_bundle" \
    -enableCodeCoverage YES \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO \
    test
