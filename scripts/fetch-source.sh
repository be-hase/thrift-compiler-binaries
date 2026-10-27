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
  # fetch <file>: try each mirror in order. Returns 0 once downloaded, 2 if
  # every mirror answers 404 (upstream doesn't publish it), and 1 on any other
  # failure, so that an outage is never mistaken for a missing file.
  local file=$1 base code missing=0
  for base in "${mirrors[@]}"; do
    code=$(curl -sSL --retry 3 -o "$file" -w '%{http_code}' "$base/$version/$file") || code=000
    if [ "$code" = 200 ]; then
      echo "fetched $base/$version/$file"
      return 0
    fi
    echo "$base/$version/$file: HTTP $code" >&2
    if [ "$code" = 404 ]; then missing=$((missing + 1)); fi
  done
  rm -f "$file"
  if [ "$missing" -eq "${#mirrors[@]}" ]; then return 2; fi
  return 1
}

verify() {
  # verify <file>: require a good signature from a key in KEYS.
  local file=$1 status
  status=$(gpg --batch --status-fd 1 --verify "$file.asc" "$file" 2>/dev/null) || {
    echo "::error::PGP signature verification failed for $file" >&2
    return 1
  }
  local signer
  signer=$(awk '$2 == "VALIDSIG" {print $3}' <<<"$status")
  if ! grep -q '^\[GNUPG:\] GOODSIG ' <<<"$status" || [ -z "$signer" ]; then
    echo "::error::no valid signature for $file" >&2
    return 1
  fi
  echo "verified $file: $signer"
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
exe_status=0
fetch "$exe" || exe_status=$?
case $exe_status in
  0)
    asc_status=0
    fetch "$exe.asc" || asc_status=$?
    case $asc_status in
      0) verify "$exe" ;;
      2)
        echo "::warning::$exe has no signature upstream; not mirroring it"
        rm -f "$exe"
        ;;
      *) echo "::error::could not download $exe.asc" >&2; exit 1 ;;
    esac
    ;;
  2) echo "::notice::upstream has no Windows exe for $version" ;;
  *) echo "::error::could not download $exe" >&2; exit 1 ;;
esac

rm -f KEYS
