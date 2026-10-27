#!/usr/bin/env bash
# Decide which upstream version to build and whether/how to release it.
# Writes version, tag, release and latest to $GITHUB_OUTPUT.
#
# Inputs (environment):
#   EVENT          github.event_name
#   REF_NAME       github.ref_name
#   INPUT_VERSION  workflow_dispatch input (version)
#   INPUT_REVISION workflow_dispatch input (rebuild number, optional)
#   GH_TOKEN, GITHUB_REPOSITORY  for querying existing releases
set -euo pipefail

version_re='^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$'
tag_re='^v([0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?)(-[0-9]+)?$'

fail() { echo "::error::$*" >&2; exit 1; }
release_exists() { gh release view "$1" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; }

release=true
case "$EVENT" in
  push)
    if [[ "$GITHUB_REF" == refs/tags/* ]]; then
      [[ "$REF_NAME" =~ $tag_re ]] || fail "tag '$REF_NAME' must look like v0.25.0 or v0.25.0-1"
      version=${BASH_REMATCH[1]}
      tag=$REF_NAME
      ! release_exists "$tag" || fail "release $tag already exists"
    else
      # THRIFT_VERSION changed on main (e.g. a merged Renovate PR).
      version=$(tr -d '[:space:]' < THRIFT_VERSION)
      tag=v$version
      if release_exists "$tag"; then
        echo "::notice::release $tag already exists; building without releasing"
        release=false
      fi
    fi
    ;;
  workflow_dispatch)
    version=$INPUT_VERSION
    tag=v$version${INPUT_REVISION:+-$INPUT_REVISION}
    [[ -z "$INPUT_REVISION" || "$INPUT_REVISION" =~ ^[0-9]+$ ]] || fail "revision must be a number"
    ! release_exists "$tag" || fail "release $tag already exists; set a revision to rebuild it (e.g. 1 -> $tag-1)"
    ;;
  pull_request)
    version=$(tr -d '[:space:]' < THRIFT_VERSION)
    tag=v$version
    release=false
    ;;
  *)
    fail "unsupported event: $EVENT"
    ;;
esac

[[ "$version" =~ $version_re ]] || fail "invalid version '$version'"

# Mark as "latest" only if this tag sorts highest among all releases, so that
# backfilled old versions don't take over the latest release.
latest=false
if [ "$release" = true ]; then
  highest=$( { gh release list --repo "$GITHUB_REPOSITORY" --limit 1000 --json tagName --jq '.[].tagName'; echo "$tag"; } \
    | sed 's/^v//' | sort -V | tail -n 1)
  [ "v$highest" = "$tag" ] && latest=true
fi

echo "version=$version tag=$tag release=$release latest=$latest"
{
  echo "version=$version"
  echo "tag=$tag"
  echo "release=$release"
  echo "latest=$latest"
} >> "$GITHUB_OUTPUT"
