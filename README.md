# Raven mesh for macOS: the RavenNearby helper

Bluetooth nearby lets two laptops exchange [Raven](https://raven-messager.com) messages over
Bluetooth LE when there is no Wi-Fi, cable, hotspot or Internet between them: verified contacts
only, one hop, in radio range. The message is the same end-to-end encrypted object as on any other
way; Bluetooth is only one more carrier. This repository is the macOS part: **RavenNearby.app**, the
small helper app that runs Apple's CoreBluetooth for `raven-node`, and how to build and test it.

## Status: held, lab only

- **Off in every build.** Bluetooth nearby is held by a gate in the code
  (`NEARBY_PRODUCTION_ENABLED = false` in raven-core) until its release record
  (`core/docs/WAIVER_NEARBY_DRAFT.md`, unsigned) is signed after the hardware test rows
  (`core/docs/PHYSICAL_NEARBY_LAPTOPS.md`, N1-N12), which have not been run yet. In a release
  build `raven nearby status` says "held in this build" and nothing touches Bluetooth.
- **Developers can try it** in debug builds with lab switches, on test profiles only (see "Try it"
  below).
- Nothing here is packaged, signed with a Developer ID or notarised. There is nothing to download.

## Where the code lives

The nearby carrier cannot be split out of `raven-node` without breaking its build and tests, so the
code stays in [`raven-core`](https://github.com/Raven-ASHCO/raven-core) (the git submodule at
`core/` here):

| What | Where (in `core/`) |
|---|---|
| The helper's source (Rust: CoreBluetooth through objc2, a state machine, its tests) | `node/crates/raven-node/src/bin/raven-nearby-helper/` |
| raven-node's macOS backend and the line protocol it speaks with the helper | `node/crates/raven-node/src/nearby/apple.rs`, `nearby/apple/proto.rs` |
| The radio-independent engine (pair keys, scanning, advertising, the knock, the pipes) | `node/crates/raven-node/src/nearby/` |
| The wire format (RNL1) and its vectors | `protocol/RAVEN_NEARBY_LINK_V1.md`, `shared-vectors/rvn1/nearby/` |
| The user guide (what others can see, permissions, troubleshooting) | `docs/NEARBY.md` (section 5 is macOS) |
| The installer that puts the helper in place | `node/scripts/install/macos_launchd.sh` (`RAVEN_INSTALL_NEARBY_HELPER=1`) |

This repository holds the helper app's bundle definition (`RavenNearby.app/Contents/Info.plist`),
its build script, a test script, and this guide. raven-core keeps an identical copy of the
Info.plist for its own tests and installer; `scripts/check.sh` fails when the two differ.

## How raven-node uses the helper

macOS gives Bluetooth only to an app whose Info.plist says why it needs it
(`NSBluetoothAlwaysUsageDescription`). So the radio runs in its own process:

1. raven-node (with cargo feature `nearby-radio`, nearby on, the gate open) looks for the helper:
   `RAVEN_NEARBY_HELPER` when set (an absolute path to the helper or its .app; nothing else is
   tried), else `RavenNearby.app` next to the raven-node executable, else
   `~/Library/Application Support/Raven/RavenNearby.app`.
2. It starts `RavenNearby.app/Contents/MacOS/raven-nearby-helper` and speaks a line protocol (one
   JSON object per line) over the helper's stdin and stdout; the helper's stderr goes to
   raven-node's log. The helper's first line is `hello` with its protocol version, or why it cannot
   run (for example `unauthorized` without the usage description).
3. The helper only runs CoreBluetooth: scanning, advertising, connections and the one GATT
   characteristic. It **holds no keys**, reads no profile and writes no file; it sees random-looking
   IDs and encrypted frames, nothing else. Nothing it logs names a device.
4. raven-node itself never links CoreBluetooth and is never re-signed for it, so its code signature
   and the Keychain access you allowed stay as they are. If macOS refuses Bluetooth it stops the
   helper (SIGABRT) and nothing else: raven-node reports `not allowed` and tries again after 1
   minute, then 2, 4 and so on up to 1 hour.

`raven-nearby-helper --check` answers `hello` (or why it cannot run) and exits without touching
Bluetooth; the build script and the installer use it.

## Build

Requirements: macOS 11 or newer, Rust ([rustup](https://rustup.rs); raven-core CI uses 1.98.0), the
Command Line Tools (`codesign`, `plutil`).

```sh
git clone --recurse-submodules https://github.com/Raven-ASHCO/raven-mesh-macos.git
cd raven-mesh-macos
scripts/build-helper-app.sh dist                 # release build, signed ad hoc
scripts/build-helper-app.sh dist --debug         # debug build
scripts/build-helper-app.sh dist --sign "Developer ID Application: <name> (<team>)"
```

Install it next to a raven-node you installed with raven-core's installer, keeping this bundle and
its signature:

```sh
cd core/node
RAVEN_INSTALL_NEARBY_ONLY=1 RAVEN_NEARBY_APP="$PWD/../../dist/RavenNearby.app" RAVEN_NEARBY_SIGN=keep \
  bash scripts/install/macos_launchd.sh
```

(or `RAVEN_INSTALL_NEARBY_HELPER=1 bash scripts/install/macos_launchd.sh`, which builds and installs
raven-node and the helper together; see `core/docs/INSTALL_macOS.md`).

## Test

```sh
scripts/check.sh
```

It checks that the Info.plist matches raven-core's, then runs the helper's tests and raven-node's
macOS backend tests from `core/node`. No Bluetooth is used, and the tests use throwaway profiles with
file-backed test stores (never the Keychain or `~/.raven`). Real-radio tests are the hardware rows
in `core/docs/PHYSICAL_NEARBY_LAPTOPS.md`.

## Try it (developers, lab only)

A debug build with Bluetooth support and both lab switches, on a test profile, never `~/.raven`:

```sh
cd core/node
cargo build --locked -p ash -p raven-node --features raven-node/nearby-radio
../../scripts/build-helper-app.sh "${CARGO_TARGET_DIR:-target}/debug" --debug   # next to the debug raven-node
export RAVEN_LAB_TEST_A=1 RAVEN_LAB_NEARBY=1 RAVEN_DATA_DIR="$HOME/raven-nearby-test"
```

Then `raven nearby enable` and `raven nearby status`; the first start asks whether RavenNearby may
use Bluetooth. `core/docs/NEARBY.md` explains every status line and what other people in radio range
can see.

## License

GNU Affero General Public License v3.0 (`LICENSE`). Security issues: please write to
security@raven-messager.com (`SECURITY.md`), not a public issue.
