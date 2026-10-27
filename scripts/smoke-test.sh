#!/usr/bin/env bash
# Smoke-test a built thrift compiler.
#
# Usage: scripts/smoke-test.sh <thrift-binary> <expected-version> <platform>
#   platform: linux-x86_64 | linux-aarch64 | macos-universal
set -euo pipefail

bin=${1:?usage: smoke-test.sh <thrift-binary> <expected-version> <platform>}
version=${2:?usage: smoke-test.sh <thrift-binary> <expected-version> <platform>}
platform=${3:?usage: smoke-test.sh <thrift-binary> <expected-version> <platform>}

repo_root=$(cd "$(dirname "$0")/.." && pwd)
idl="$repo_root/test/smoke.thrift"
bin=$(cd "$(dirname "$bin")" && pwd)/$(basename "$bin")

fail() { echo "::error::$*" >&2; exit 1; }

echo "--- version"
actual=$("$bin" --version)
echo "$actual"
[ "$actual" = "Thrift version $version" ] || fail "expected 'Thrift version $version', got '$actual'"

echo "--- binary format"
case "$platform" in
  linux-*)
    info=$(file -b "$bin")
    echo "$info"
    # Alpine's GCC defaults to PIE, so -static yields a static-pie binary.
    grep -qE 'statically linked|static-pie linked' <<<"$info" || fail "not statically linked"
    case "$platform" in
      linux-x86_64) grep -q 'x86-64' <<<"$info" || fail "not an x86-64 binary" ;;
      linux-aarch64) grep -q 'aarch64' <<<"$info" || fail "not an aarch64 binary" ;;
    esac
    # glibc's ldd prints "not a dynamic executable" for static binaries and
    # "statically linked" for static-pie ones.
    ldd_out=$(ldd "$bin" 2>&1 || true)
    echo "ldd: $ldd_out"
    grep -qE 'not a dynamic executable|statically linked' <<<"$ldd_out" || fail "ldd reports dynamic dependencies"
    ;;
  macos-universal)
    archs=$(lipo -archs "$bin")
    lipo -info "$bin"
    min_os=${MACOSX_DEPLOYMENT_TARGET:-11.0}
    for a in arm64 x86_64; do
      grep -qw "$a" <<<"$archs" || fail "universal binary lacks $a"
      # A newer Xcode must not silently raise the minimum macOS version.
      minos=$(otool -arch "$a" -l "$bin" | awk '$1 == "minos" {print $2; exit}')
      echo "$a minos: $minos"
      [ "$minos" = "$min_os" ] || fail "$a slice requires macOS $minos, expected $min_os"
    done
    # Only system libraries may be linked (no Homebrew paths).
    otool -L "$bin"
    # Dependency lines are indented; the others are per-architecture headers.
    if otool -L "$bin" | grep -E '^[[:space:]]' | grep -vE '^[[:space:]]+(/usr/lib/|/System/)'; then
      fail "links against non-system libraries"
    fi
    if arch -x86_64 /usr/bin/true 2>/dev/null; then
      actual_x86=$(arch -x86_64 "$bin" --version)
      echo "x86_64 slice (Rosetta): $actual_x86"
      [ "$actual_x86" = "Thrift version $version" ] || fail "x86_64 slice reports '$actual_x86'"
    else
      echo "::warning::Rosetta unavailable; x86_64 slice not executed"
    fi
    ;;
  *)
    fail "unknown platform: $platform"
    ;;
esac

echo "--- code generation"
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
for lang in java py go cpp js; do
  mkdir -p "$out/$lang"
  "$bin" --gen "$lang" -o "$out/$lang" "$idl"
done

expect() { [ -s "$out/$1" ] || fail "missing generated file: $1"; echo "ok $1"; }
expect java/gen-java/smoke/Point.java
expect java/gen-java/smoke/Geometry.java
expect py/gen-py/smoke/ttypes.py
expect py/gen-py/smoke/Geometry.py
expect cpp/gen-cpp/smoke_types.h
expect cpp/gen-cpp/Geometry.cpp
expect js/gen-js/smoke_types.js
expect js/gen-js/Geometry.js
[ -n "$(find "$out/go/gen-go/smoke" -name '*.go' 2>/dev/null)" ] || fail "no Go files generated"
echo "ok go/gen-go/smoke/*.go"

echo "smoke test passed: $platform $version"
