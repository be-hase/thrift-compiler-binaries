#!/usr/bin/env bash
# Print, as a JSON array, every upstream version from the oldest buildable one
# (0.9.2, the first with a CMake build for the compiler) up to THRIFT_VERSION.
#
# THRIFT_VERSION (bumped by Renovate) is the upper bound, so a new upstream
# tag is only included once Renovate has picked it up.
#
# Usage: scripts/list-versions.sh   (needs gh; GH_TOKEN in CI)
set -euo pipefail

oldest=0.9.2
newest=$(tr -d '[:space:]' < "$(dirname "$0")/../THRIFT_VERSION")

in_range() {
  # in_range <version>: oldest <= version <= newest
  [ "$(printf '%s\n' "$oldest" "$1" | sort -V | head -n 1)" = "$oldest" ] &&
    [ "$(printf '%s\n' "$1" "$newest" | sort -V | tail -n 1)" = "$newest" ]
}

# Tags are "0.9.2" up to 0.11.0 and "v0.12.0" afterwards. Only X.Y.Z tags are
# kept, which also drops 0.9.3.1: its compiler still reports itself as 0.9.3.
gh api 'repos/apache/thrift/tags?per_page=100' --paginate --jq '.[].name' |
  sed -nE 's/^v?([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' |
  sort -uV |
  while read -r v; do
    if in_range "$v"; then echo "$v"; fi
  done |
  jq -R . | jq -cs .
