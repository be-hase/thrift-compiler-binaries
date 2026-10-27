#!/usr/bin/env bash
# Package a built compiler with the upstream LICENSE and NOTICE.
#
# Usage: scripts/package.sh <version> <platform> <build-dir> <out-dir>
#   build-dir must contain thrift, LICENSE and NOTICE (as produced by build.sh).
#   Produces <out-dir>/thrift-<version>-<platform>.tar.gz with thrift, LICENSE
#   and NOTICE at the archive root.
set -euo pipefail

version=${1:?usage: package.sh <version> <platform> <build-dir> <out-dir>}
platform=${2:?usage: package.sh <version> <platform> <build-dir> <out-dir>}
build_dir=${3:?usage: package.sh <version> <platform> <build-dir> <out-dir>}
out_dir=${4:?usage: package.sh <version> <platform> <build-dir> <out-dir>}

name="thrift-$version-$platform"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

mkdir -p "$out_dir"
install -m 0755 "$build_dir/thrift" "$stage/thrift"
install -m 0644 "$build_dir/LICENSE" "$build_dir/NOTICE" "$stage/"

out_dir=$(cd "$out_dir" && pwd)
# COPYFILE_DISABLE keeps macOS tar from adding AppleDouble (._*) entries.
(cd "$stage" && COPYFILE_DISABLE=1 tar -czf "$out_dir/$name.tar.gz" thrift LICENSE NOTICE)
echo "$out_dir/$name.tar.gz"
