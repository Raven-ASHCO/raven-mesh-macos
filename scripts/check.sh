#!/usr/bin/env bash
# Tests of the macOS nearby radio, run from the raven-core submodule. No Bluetooth is used:
# the helper runs outside a bundle (it then says `unauthorized` before any CoreBluetooth call)
# or with --check, and raven-node's macOS backend is tested against a scripted helper.
#
#   scripts/check.sh
#
# 1. This repository's Info.plist is the one raven-core's tests and installer use.
# 2. raven-nearby-helper's own tests (its state machine) and the helper process tests
#    (tests/nearby_helper.rs in raven-node).
# 3. raven-node's macOS backend (src/nearby/apple.rs and its line protocol).
# The tests use the file-backed test stores and never touch the Keychain or ~/.raven.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$REPO/core/node"
if [[ ! -f "$NODE/Cargo.toml" ]]; then
  echo "core/ is empty: run 'git submodule update --init' first" >&2
  exit 1
fi

if ! cmp -s "$REPO/RavenNearby.app/Contents/Info.plist" \
  "$NODE/crates/raven-node/macos/RavenNearby.app/Contents/Info.plist"; then
  echo "RavenNearby.app/Contents/Info.plist differs from raven-core's copy" >&2
  echo "(core/node/crates/raven-node/macos/RavenNearby.app): change both together" >&2
  exit 1
fi
if command -v plutil >/dev/null; then
  plutil -lint "$REPO/RavenNearby.app/Contents/Info.plist" >/dev/null
fi

export RAVEN_IDENTITY_BACKEND=locked-file RAVEN_SESSION_BACKEND=locked-file \
  RAVEN_PREKEY_BACKEND=locked-file RAVEN_CHAT_HISTORY_BACKEND=locked-file \
  RAVEN_ALLOW_EPHEMERAL_DATA_DIR=1
cd "$NODE"
cargo test --locked -p raven-node --features nearby-radio --bin raven-nearby-helper --test nearby_helper
cargo test --locked -p raven-node --features nearby-radio --bin raven-node -- nearby::apple
echo "raven-mesh-macos checks passed"
