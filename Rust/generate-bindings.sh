#!/usr/bin/env bash
set -euo pipefail

# Regenerates Swift bindings + C header/modulemap.  Run this after changing the
# UniFFI interface, then commit the generated files under
# Minesweeper/Core/Generated and Rust/include.
#
# The Xcode build phase only runs build-ios.sh, so normal builds do not need the
# bindgen toolchain.

cd "$(dirname "$0")"
export PATH="${HOME}/.cargo/bin:/usr/local/bin:/opt/homebrew/bin:${PATH}"

cargo build --release
cargo run --features cli --bin uniffi-bindgen -- \
  generate --library target/release/libminesweeper_core.dylib \
  --language swift --out-dir generated

mkdir -p include
cp generated/minesweeper_coreFFI.h include/
cp generated/minesweeper_coreFFI.modulemap include/module.modulemap

mkdir -p ../Minesweeper/Core/Generated
cp generated/minesweeper_core.swift ../Minesweeper/Core/Generated/minesweeper_core.swift

echo "Bindings generated:"
ls -lh generated/minesweeper_core.swift generated/minesweeper_coreFFI.h include/module.modulemap
