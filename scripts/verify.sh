#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/release_preflight.py
swift test
python3 -m unittest discover -s backend/tests -v
if [ -x .venv/bin/python ]; then
  .venv/bin/python scripts/backend_smoke.py
fi
if [ -n "${CARE_SIMULATOR_ID:-}" ]; then
  xcodebuild -project CareContinuity.xcodeproj -scheme CareContinuity \
    -destination "platform=iOS Simulator,id=$CARE_SIMULATOR_ID" \
    -parallel-testing-enabled NO -jobs 2 test
fi
