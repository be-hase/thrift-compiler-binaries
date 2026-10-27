#!/bin/sh
# Build only the thrift compiler from a verified upstream source tarball.
#
#   Linux: run inside an Alpine container; produces a fully static (musl) binary.
#   macOS: produces a universal (arm64 + x86_64) binary. Needs Homebrew bison/flex,
#          because the bison shipped with macOS (2.3) is too old.
#
# Usage: scripts/build.sh <source-tarball> <out-binary>
set -eu

tarball=${1:?usage: build.sh <source-tarball> <out-binary>}
out=${2:?usage: build.sh <source-tarball> <out-binary>}

work=$(mktemp -d)
tar -xzf "$tarball" -C "$work"
src=$(find "$work" -mindepth 1 -maxdepth 1 -type d -name 'thrift-*')
cmake_src=$src
target=thrift-compiler
# 0.9.2 only has a standalone CMake build for the compiler, whose target is "thrift".
if [ ! -f "$src/CMakeLists.txt" ]; then
  cmake_src=$src/compiler/cpp
  target=thrift
fi

set -- \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_COMPILER=ON \
  -DBUILD_LIBRARIES=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_TUTORIALS=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5

case "$(uname -s)" in
  Linux)
    set -- "$@" -DCMAKE_EXE_LINKER_FLAGS=-static
    ;;
  Darwin)
    brew_bison=$(brew --prefix bison)
    brew_flex=$(brew --prefix flex)
    set -- "$@" \
      -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}" \
      -DBISON_EXECUTABLE="$brew_bison/bin/bison" \
      -DFLEX_EXECUTABLE="$brew_flex/bin/flex"
    ;;
  *)
    echo "unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

cmake -S "$cmake_src" -B "$work/build" "$@"
# An explicit job count: a bare --parallel means unlimited `make -j`.
cmake --build "$work/build" --target "$target" --parallel "$(getconf _NPROCESSORS_ONLN)"

bin=$(find "$work/build" -type f -name thrift -perm -u+x | head -n 1)
if [ -z "$bin" ]; then
  echo "thrift binary not found in build tree" >&2
  exit 1
fi

mkdir -p "$(dirname "$out")"
cp "$bin" "$out"
strip "$out"
cp "$src/LICENSE" "$src/NOTICE" "$(dirname "$out")/"
rm -rf "$work"
