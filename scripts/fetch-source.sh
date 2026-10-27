#!/usr/bin/env bash
# Download the upstream source tarball (and, if available, the official Windows
# exe) for a given version and verify their PGP signatures against the KEYS
# file published by the upstream project.
#
# Usage: scripts/fetch-source.sh <version> <out-dir>
set -euo pipefail

version=${1:?usage: fetch-source.sh <version> <out-dir>}
out=${2:?usage: fetch-source.sh <version> <out-dir>}

mirrors=(
  "https://downloads.apache.org/thrift"
  "https://archive.apache.org/dist/thrift"
)
keys_url="https://downloads.apache.org/thrift/KEYS"

mkdir -p "$out"
cd "$out"

fetch() {
  # fetch <file>: try each mirror in order. Returns non-zero if none has it.
  local file=$1 base
  for base in "${mirrors[@]}"; do
    if curl -fsSL --retry 3 -o "$file" "$base/$version/$file"; then
      echo "fetched $base/$version/$file"
      return 0
    fi
  done
  rm -f "$file"
  return 1
}

verify() {
  # verify <file>: require a good signature from a key in KEYS.
  local file=$1 status
  status=$(gpg --batch --status-fd 1 --verify "$file.asc" "$file" 2>/dev/null) || {
    echo "::error::PGP signature verification failed for $file" >&2
    return 1
  }
  grep -q '^\[GNUPG:\] GOODSIG ' <<<"$status"
  echo "verified $file: $(grep '^\[GNUPG:\] VALIDSIG ' <<<"$status" | awk '{print $3}')"
}

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

curl -fsSL --retry 3 -o KEYS "$keys_url"
gpg --batch --quiet --import KEYS

tarball="thrift-$version.tar.gz"
fetch "$tarball" || { echo "::error::$tarball not found on any mirror" >&2; exit 1; }
fetch "$tarball.asc" || { echo "::error::$tarball.asc not found on any mirror" >&2; exit 1; }
verify "$tarball"

exe="thrift-$version.exe"
if fetch "$exe"; then
  if fetch "$exe.asc"; then
    verify "$exe"
  else
    echo "::warning::$exe has no signature upstream; not mirroring it"
    rm -f "$exe"
  fi
else
  echo "::notice::upstream has no Windows exe for $version"
fi

rm -f KEYS
