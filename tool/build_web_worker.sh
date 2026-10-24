#!/usr/bin/env bash
# Builds the encrypting drift web worker (web/drift_worker.js) from
# web/drift_worker.dart. Re-run after upgrading drift or sqlite3, and keep
# web/sqlite3mc.wasm in sync with the sqlite3 package version (download it
# from https://github.com/simolus3/sqlite3.dart/releases).
set -euo pipefail
cd "$(dirname "$0")/.."
dart compile js -O4 -o web/drift_worker.js web/drift_worker.dart
rm -f web/drift_worker.js.deps web/drift_worker.js.map
echo "Built web/drift_worker.js"
