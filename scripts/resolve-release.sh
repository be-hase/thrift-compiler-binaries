#!/usr/bin/env bash
# Decide which upstream version to build and whether/how to release it.
# Writes version, tag, release and latest to $GITHUB_OUTPUT.
#
# Inputs (environment):
#   EVENT          github.event_name
#   INPUT_VERSION  workflow_dispatch input (version)
#   INPUT_REVISION workflow_dispatch input (rebuild number, optional)
#   GITHUB_SHA     commit the release would be tagged at
#   GH_TOKEN, GITHUB_REPOSITORY  for querying existing releases and tags
set -euo pipefail

version_re='^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$'

fail() { echo "::error::$*" >&2; exit 1; }

# Every release as "<tag> <draft> <prerelease>". Any API failure aborts, so
# that an outage is never mistaken for "no such release".
releases=$(gh api --paginate "repos/$GITHUB_REPOSITORY/releases?per_page=100" \
  --jq '.[] | "\(.tag_name) \(.draft) \(.prerelease)"') || fail "could not list releases"

# release_state <tag>: none | draft | published
release_state() {
  awk -v t="$1" '$1 == t { s = ($2 == "true") ? "draft" : "published" } END { print s ? s : "none" }' <<<"$releases"
}

release=true
case "$EVENT" in
  push)
    # THRIFT_VERSION changed on main (e.g. a merged Renovate PR).
    version=$(tr -d '[:space:]' < THRIFT_VERSION)
    tag=v$version
    ;;
  workflow_dispatch)
    version=$INPUT_VERSION
    [[ -z "$INPUT_REVISION" || "$INPUT_REVISION" =~ ^[0-9]+$ ]] || fail "revision must be a number"
    tag=v$version${INPUT_REVISION:+-$INPUT_REVISION}
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

if [ "$release" = true ]; then
  case "$(release_state "$tag")" in
    published)
      if [ "$EVENT" = push ]; then
        echo "::notice::release $tag already exists; building without releasing"
        release=false
      else
        fail "release $tag already exists; set a revision to rebuild it (e.g. 1 -> $tag-1)"
      fi
      ;;
    draft)
      # Left behind by an interrupted run. Releases are immutable once
      # published, so a human should look at it rather than this script.
      fail "a draft release for $tag exists (probably from an interrupted run); delete it and re-run"
      ;;
  esac
fi

if [ "$release" = true ]; then
  # gh release create reuses an existing tag, wherever it points. Refuse one
  # that doesn't point at this commit: an immutable release would pin it.
  refs=$(git ls-remote --tags "https://github.com/$GITHUB_REPOSITORY.git" "refs/tags/$tag" "refs/tags/$tag^{}") ||
    fail "could not look up tag $tag"
  if [ -n "$refs" ]; then
    # For an annotated tag, the peeled "^{}" line names the commit.
    tagged=$(awk '{ sha = $1 } $2 ~ /\^\{\}$/ { peeled = $1 } END { print peeled ? peeled : sha }' <<<"$refs")
    [ "$tagged" = "$GITHUB_SHA" ] || fail "tag $tag already exists and points at $tagged, not $GITHUB_SHA"
  fi
fi

# Mark as "latest" only if this tag sorts highest among published releases, so
# that backfilled old versions don't take over the latest release.
latest=false
if [ "$release" = true ]; then
  highest=$( { awk '$2 == "false" && $3 == "false" { print $1 }' <<<"$releases"; echo "$tag"; } |
    sed 's/^v//' | sort -V | tail -n 1)
  if [ "v$highest" = "$tag" ]; then latest=true; fi
fi

echo "version=$version tag=$tag release=$release latest=$latest"
{
  echo "version=$version"
  echo "tag=$tag"
  echo "release=$release"
  echo "latest=$latest"
} >> "$GITHUB_OUTPUT"
