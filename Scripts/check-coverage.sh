#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
    printf 'Usage: %s /path/to/TestResults.xcresult\n' "$0" >&2
    exit 2
fi

result_bundle="$1"
report="$(xcrun xcresulttool get test-results summary --path "$result_bundle" --compact)"
coverage_report="$(xcrun xccov view --report --json "$result_bundle")"
minimum="${MIN_COVERAGE_PERCENT:-70}"
export minimum
printf '%s\n' "$report"

python3 -c '
import json
import os
import sys

report, coverage_report = map(json.loads, sys.stdin.read().split("\n---COVERAGE---\n", 1))
failed = report.get("failedTests", 0)
passed = report.get("passedTests", 0)
if failed or passed <= 0:
    print(f"Coverage gate requires passing tests; passed={passed}, failed={failed}.", file=sys.stderr)
    raise SystemExit(1)

targets = [target for target in coverage_report.get("targets", [])
           if target.get("name") == "Cragfolio.app"]
source_files = [file for target in targets for file in target.get("files", [])
                if "/Cragfolio/" in file.get("path", "")]
covered = sum(file.get("coveredLines", 0) for file in source_files)
executable = sum(file.get("executableLines", 0) for file in source_files)
if not targets or executable <= 0:
    print("Coverage report is missing first-party app source files.", file=sys.stderr)
    raise SystemExit(1)

percent = 100.0 * covered / executable
threshold = float(os.environ["minimum"])
share = next((target for target in coverage_report.get("targets", [])
              if target.get("name") == "CragfolioShare.appex"), None)
if share:
    print("Share-extension line coverage (foundation stub only): {}/{}".format(share.get("coveredLines", 0), share.get("executableLines", 0)))
print(f"First-party app line coverage: {covered}/{executable} ({percent:.2f}%)")
if percent < threshold:
    print(f"Coverage is below the required {threshold:.2f}%.", file=sys.stderr)
    raise SystemExit(1)
' <<<"$report
---COVERAGE---
$coverage_report"
