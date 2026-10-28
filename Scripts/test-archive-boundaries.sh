#!/bin/bash
# Explicit opt-in host feasibility harness, not part of routine simulator tests.
set -euo pipefail
if [[ "${1:-}" != --run-large ]]; then
  printf 'Usage: bash Scripts/test-archive-boundaries.sh --run-large\nRequires 16 GiB free; writes real >4 GiB ZIPs in owned temporary scratch.\n' >&2
  exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/.build/DerivedData/SourcePackages/checkouts/ZIPFoundation"
REVISION=22787ffb59de99e5dc1fbfe80b19c97a904ad48d
# Xcode's cached checkout may retain an alternate path from the former repository name.
# Supply the current object store for read-only verification; do not patch package metadata.
export GIT_ALTERNATE_OBJECT_DIRECTORIES="$ROOT/.build/DerivedData/SourcePackages/repositories/ZIPFoundation-789121e4/objects"
[[ "$(git -C "$SOURCE" rev-parse HEAD)" == "$REVISION" ]]
PACKAGE_STATUS="$(git -C "$SOURCE" status --porcelain)"
[[ -z "$PACKAGE_STATUS" ]]
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/CF05A.XXXXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
AVAILABLE="$(df -k "$SCRATCH" | /usr/bin/tail -1 | /usr/bin/awk '{print $4}')"
[[ "$AVAILABLE" -ge 16777216 ]] || { printf 'Insufficient free space\n' >&2; exit 1; }
printf 'Scratch: %s\nFree KiB: %s\nZIPFoundation revision: %s\n' "$SCRATCH" "$AVAILABLE" "$REVISION"
xcodebuild -version
swift --version
python3 --version
# Compile existing approved sources, with the same Apple Compression backend. No package installation/resolution.
xcrun swiftc -O -emit-library -emit-module -module-name ZIPFoundation \
  "$SOURCE"/Sources/ZIPFoundation/*.swift -o "$SCRATCH/libZIPFoundation.dylib" \
  -emit-module-path "$SCRATCH/ZIPFoundation.swiftmodule"
xcrun swiftc -O -I "$SCRATCH" -L "$SCRATCH" -lZIPFoundation \
  -Xlinker -rpath -Xlinker "$SCRATCH" "$ROOT/Scripts/ArchiveBoundaryProbe.swift" -o "$SCRATCH/probe"
/usr/bin/time -l "$SCRATCH/probe" create "$SCRATCH"
/usr/bin/time -l python3 "$ROOT/Scripts/archive-boundary-independent.py" "$SCRATCH"
/usr/bin/time -l "$SCRATCH/probe" verify "$SCRATCH"
if [[ "${CF05D_PREFLIGHT:-0}" == 1 ]]; then
  xcrun swiftc -O "$ROOT/ClimbingNotebookTests/ArchivePreflightProbe.swift" \
    "$ROOT/Scripts/ArchivePreflightHostProbe.swift" -o "$SCRATCH/preflight"
  /usr/bin/time -l "$SCRATCH/preflight" "$SCRATCH"
fi
du -k "$SCRATCH"/*.zip
printf 'PASS CF-05A large boundary probe; removing owned scratch %s\n' "$SCRATCH"
