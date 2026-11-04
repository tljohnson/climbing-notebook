#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SUITE=core
LIST_ONLY=0
if [[ "${1:-}" == "--suite" ]]; then
  if [[ $# -lt 2 ]]; then
    printf 'Missing suite name: core, qualification or all.\n' >&2
    exit 2
  fi
  SUITE="${2:-}"
  shift 2
fi
if [[ "${1:-}" == "--list" ]]; then
  LIST_ONLY=1
  shift
fi
case "$SUITE" in
  core|qualification|all) ;;
  *) printf 'Usage: bash Scripts/test-ios.sh [--suite core|qualification|all] [--list] [xcodebuild arguments]\n' >&2; exit 2 ;;
esac
SELECTION=()
while IFS= read -r test || [[ -n "$test" ]]; do
  [[ -z "$test" || "$test" == \#* ]] && continue
  case "$SUITE" in
    core) SELECTION+=("-only-testing:$test") ;;
    qualification) SELECTION+=("-skip-testing:$test") ;;
  esac
done < "$ROOT/Scripts/mvp-core-tests.txt"
if [[ "$SUITE" != all ]]; then
  for argument in "$@"; do
    case "$argument" in
      -only-testing*|-skip-testing*|-testPlan*|-only-test-configuration*|-skip-test-configuration*)
        printf 'Use --suite all for ad-hoc selections; named cohorts must run unchanged.\n' >&2
        exit 2 ;;
    esac
  done
fi
printf 'Test suite: %s\n' "$SUITE"
if [[ "$LIST_ONLY" == 1 ]]; then
  if [[ "$SUITE" == all ]]; then
    printf 'All tests in the shared ClimbingNotebook scheme.\n'
  else
    printf '%s\n' "${SELECTION[@]}"
  fi
  exit 0
fi
: "${SIMULATOR_ID:?Set SIMULATOR_ID to an installed iOS Simulator UUID from xcrun simctl list devices available}"
RESULT="${RESULT_BUNDLE_PATH:-$ROOT/.build/Tests-$(date +%Y%m%d-%H%M%S).xcresult}"
xcodebuild test -project ClimbingNotebook.xcodeproj -scheme ClimbingNotebook \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath .build/DerivedData -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO ${SELECTION[@]+"${SELECTION[@]}"} "$@"
