# thrift-compiler-binaries

Prebuilt binaries of the [Apache Thrift](https://thrift.apache.org/) compiler (`thrift`) for Linux and macOS, built from the upstream source releases by GitHub Actions.

> [!IMPORTANT]
> This is an **unofficial**, community-maintained build. It is **not affiliated with, endorsed by, or supported by the Apache Software Foundation** or the Apache Thrift project. Apache Thrift, Thrift, Apache, and the Apache feather logo are trademarks of the Apache Software Foundation.
> For official releases, see <https://thrift.apache.org/download>.

## Why

The Thrift project publishes a source tarball and a Windows `.exe`, but no prebuilt compiler for macOS or Linux. Package managers usually ship only one version (often an old one on Linux distributions). This repository builds any released version on demand, so you can pin the compiler version your project needs.

## Platforms

| Asset | Platform | Notes |
| --- | --- | --- |
| `thrift-<version>-linux-x86_64.tar.gz` | Linux x86_64 | Fully static (musl), runs on any distribution |
| `thrift-<version>-linux-aarch64.tar.gz` | Linux aarch64 | Fully static (musl), runs on any distribution |
| `thrift-<version>-macos-universal.tar.gz` | macOS 11+ | Universal binary (arm64 + x86_64) |
| `thrift-<version>-windows-x86.exe` | Windows | Upstream's official exe, mirrored as-is, with upstream's `.asc` signature |

Each tarball contains a single directory with the `thrift` binary and the upstream `LICENSE` and `NOTICE` files:

```
thrift-0.25.0-linux-x86_64/
├── LICENSE
├── NOTICE
└── thrift
```

Release tags match the upstream version (`v0.25.0`). If a version has to be rebuilt, the new release gets a suffix (`v0.25.0-1`, `v0.25.0-2`, …); the asset names stay the same.

## Install

```sh
VERSION=0.25.0
PLATFORM=linux-x86_64   # linux-x86_64 | linux-aarch64 | macos-universal
BASE=https://github.com/be-hase/thrift-compiler-binaries/releases/download/v$VERSION

curl -fsSLO "$BASE/thrift-$VERSION-$PLATFORM.tar.gz"
curl -fsSLO "$BASE/SHA256SUMS"
sha256sum --check --ignore-missing SHA256SUMS   # macOS: shasum -a 256 --check --ignore-missing SHA256SUMS

tar -xzf "thrift-$VERSION-$PLATFORM.tar.gz"
install -m 0755 "thrift-$VERSION-$PLATFORM/thrift" ~/.local/bin/thrift
thrift --version
```

Or with the GitHub CLI:

```sh
gh release download v0.25.0 --repo be-hase/thrift-compiler-binaries \
  --pattern 'thrift-0.25.0-linux-x86_64.tar.gz' --pattern SHA256SUMS
```

## Verifying downloads

### Checksums

Every release has a `SHA256SUMS` file covering all of its assets:

```sh
sha256sum --check --ignore-missing SHA256SUMS
```

### Build provenance

The tarballs carry a [GitHub artifact attestation](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations) showing which workflow run in this repository built them, and from which commit:

```sh
gh attestation verify thrift-0.25.0-linux-x86_64.tar.gz \
  --repo be-hase/thrift-compiler-binaries
```

The mirrored Windows exe was built by upstream, not here, so it has no attestation. Verify it with upstream's signature:

```sh
curl -fsSLO https://downloads.apache.org/thrift/KEYS
gpg --import KEYS
gpg --verify thrift-0.25.0-windows-x86.exe.asc thrift-0.25.0-windows-x86.exe
```

## How the binaries are built

See [`.github/workflows/build.yml`](.github/workflows/build.yml) and [`.github/workflows/release.yml`](.github/workflows/release.yml).

1. Download `thrift-<version>.tar.gz` and its `.asc` from `downloads.apache.org`, falling back to `archive.apache.org` for older versions. Verify the signature against the upstream [KEYS](https://downloads.apache.org/thrift/KEYS) file. The build stops if verification fails.
2. Build only the compiler (CMake target `thrift-compiler`, with `-DBUILD_LIBRARIES=OFF -DBUILD_TESTING=OFF`). The upstream source is not modified.
   - **Linux**: in an Alpine container, linked with `-static`. x86_64 builds on `ubuntu-24.04`, aarch64 on `ubuntu-24.04-arm`.
   - **macOS**: on an arm64 runner with `-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"`, using Homebrew's bison and flex.
3. Smoke-test each binary:
   - check the `thrift --version` output
   - generate Java, Python, Go, C++ and JavaScript code from [`test/smoke.thrift`](test/smoke.thrift)
   - Linux: confirm with `file` and `ldd` that the binary is static, then run it on the Ubuntu host rather than in Alpine
   - macOS: confirm with `lipo` that both slices are present and that only system libraries are linked, then run the x86_64 slice under Rosetta
4. Package each binary with upstream's `LICENSE` and `NOTICE`, generate `SHA256SUMS`, attest build provenance, and publish the GitHub release.

## Maintenance

- **New upstream releases**: [Renovate](https://docs.renovatebot.com/) watches `apache/thrift` releases and opens a PR that bumps [`THRIFT_VERSION`](THRIFT_VERSION). The PR's CI builds and tests the new version. Merging the PR builds it again and publishes the `v<version>` release.
- **A specific version**: run the *Release* workflow manually with `version` (and `revision` when rebuilding an existing release), or push a `v<version>` / `v<version>-<n>` tag.
- Releases of versions older than the newest one are not marked as "latest".
- **Testing without releasing**: the *Test versions* workflow builds and smoke-tests a list of versions (by default, every upstream version from 0.9.2, the first with a CMake build for the compiler, up to `THRIFT_VERSION`, so it follows Renovate's bumps) and publishes nothing. It runs on PRs that change the build, and can be run manually.

The build itself lives in the reusable [`.github/workflows/build.yml`](.github/workflows/build.yml), which both workflows call.

## License

The scripts and workflows in this repository are licensed under the [Apache License 2.0](LICENSE).

The distributed binaries are built from Apache Thrift, which is licensed under the Apache License 2.0. Each archive includes upstream's `LICENSE` and `NOTICE` files.
