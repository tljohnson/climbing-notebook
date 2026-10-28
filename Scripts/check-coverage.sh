#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec swift "$ROOT/Scripts/CoverageGate.swift" "$@"
