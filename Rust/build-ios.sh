#!/usr/bin/env bash
set -euo pipefail

# Builds the Rust static libraries consumed by Xcode.
#
# Invoked from an Xcode Run Script phase (ENABLE_USER_SCRIPT_SANDBOXING must be
# OFF) or manually from the repository root.  When Xcode invokes it, only the
# platform currently being built is compiled; the simulator output is universal
# (arm64 + x86_64) so a thin library from a previous build cannot be reused.

cd "$(dirname "$0")"
export PATH="${HOME}/.cargo/bin:/usr/local/bin:/opt/homebrew/bin:${PATH}"

DEVICE_TARGET="aarch64-apple-ios"
SIM_ARM_TARGET="aarch64-apple-ios-sim"
SIM_X86_TARGET="x86_64-apple-ios"

build_target() {
  local target="$1"

  if command -v rustup >/dev/null 2>&1; then
    if ! rustup target list --installed 2>/dev/null | grep -qx "${target}"; then
      echo "error: Rust target ${target} is not installed." >&2
      echo "       Run: rustup target add ${target}" >&2
      exit 1
    fi
  fi

  echo "Building ${target}..."
  cargo build --release --locked --target "${target}"
}

build_device() {
  build_target "${DEVICE_TARGET}"
  mkdir -p libs/iphoneos
  cp "target/${DEVICE_TARGET}/release/libminesweeper_core.a" \
    libs/iphoneos/libminesweeper_core.a
}

build_simulator() {
  # Always produce a universal simulator library.  Xcode's dependency
  # analysis keys off a single output path, so a thin arm64-only library left
  # behind by an earlier single-arch build would be silently reused when a
  # later build asks for x86_64.  Building both slices is a few seconds on a
  # warm cache and avoids that class of linker error.
  local targets=("${SIM_ARM_TARGET}" "${SIM_X86_TARGET}")
  local libs=()
  local target
  for target in "${targets[@]}"; do
    build_target "${target}"
    libs+=("target/${target}/release/libminesweeper_core.a")
  done

  mkdir -p libs/iphonesimulator
  lipo -create "${libs[@]}" -output libs/iphonesimulator/libminesweeper_core.a
}

# Xcode exports PLATFORM_NAME/ARCHS to the script phase.  Keep the old
# "build everything" behaviour for direct terminal use.
case "${PLATFORM_NAME:-}" in
  iphoneos)
    build_device
    echo "Rust core built:"
    ls -lh libs/iphoneos/libminesweeper_core.a
    ;;
  iphonesimulator)
    build_simulator
    echo "Rust core built:"
    ls -lh libs/iphonesimulator/libminesweeper_core.a
    ;;
  *)
    build_device
    build_simulator
    echo "Rust core built:"
    ls -lh libs/iphoneos/libminesweeper_core.a libs/iphonesimulator/libminesweeper_core.a
    ;;
esac
