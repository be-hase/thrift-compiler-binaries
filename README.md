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
| `thrift-<version>-linux-aarch_64.tar.gz` | Linux aarch64 | Fully static (musl), runs on any distribution |
| `thrift-<version>-osx-aarch_64.tar.gz` | macOS 11+ arm64 | Apple silicon |
| `thrift-<version>-osx-x86_64.tar.gz` | macOS 11+ x86_64 | Intel |
| `thrift-<version>-windows-x86_32.exe` | Windows | Upstream's official 32-bit exe, mirrored as-is with upstream's `.asc` signature, for versions where upstream publishes one |
| `checksums.txt` | | SHA-256 of every asset above |

The platform part of each name is the classifier that [os-maven-plugin](https://github.com/trustin/os-maven-plugin) and [osdetector-gradle-plugin](https://github.com/google/osdetector-gradle-plugin) detect (`${os.detected.classifier}`), the same scheme protoc uses, so Maven and Gradle builds can pick the right asset without any mapping.

Each tarball holds the `thrift` binary and the upstream `LICENSE` and `NOTICE` files at its root:

```
thrift-0.25.0-linux-x86_64.tar.gz
├── LICENSE
├── NOTICE
└── thrift
```

Release tags match the upstream version (`v0.25.0`). If a version has to be rebuilt, the new release gets a suffix (`v0.25.0-1`, `v0.25.0-2`, …); the asset names stay the same.

## Install

```sh
VERSION=0.25.0
PLATFORM=linux-x86_64   # linux-x86_64 | linux-aarch_64 | osx-x86_64 | osx-aarch_64
BASE=https://github.com/be-hase/thrift-compiler-binaries/releases/download/v$VERSION

curl -fsSLO "$BASE/thrift-$VERSION-$PLATFORM.tar.gz"
curl -fsSLO "$BASE/checksums.txt"
sha256sum --check --ignore-missing checksums.txt   # macOS: shasum -a 256 --check --ignore-missing checksums.txt

tar -xzf "thrift-$VERSION-$PLATFORM.tar.gz" thrift
install -m 0755 thrift ~/.local/bin/thrift
thrift --version
```

Or with the GitHub CLI:

```sh
gh release download v0.25.0 --repo be-hase/thrift-compiler-binaries \
  --pattern 'thrift-0.25.0-linux-x86_64.tar.gz' --pattern checksums.txt
```

## Verifying downloads

### Checksums

Every release has a `checksums.txt` file with the SHA-256 of all of its assets:

```sh
sha256sum --check --ignore-missing checksums.txt
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
gpg --verify thrift-0.25.0-windows-x86_32.exe.asc thrift-0.25.0-windows-x86_32.exe
```

## How the binaries are built

- GitHub Actions in this repository builds each version from the upstream source release, after verifying its PGP signature against the upstream [KEYS](https://downloads.apache.org/thrift/KEYS). The upstream source is not modified.
- Only the compiler is built. Linux binaries are fully static (Alpine, musl); macOS binaries target macOS 11 and later.
- Before release, every binary is smoke-tested: its version, code generation for several languages, and how it is linked.

For the details, and for how releases are made, see [docs/maintenance.md](docs/maintenance.md).

## License

The scripts and workflows in this repository are licensed under the [Apache License 2.0](LICENSE).

The distributed binaries are built from Apache Thrift, which is licensed under the Apache License 2.0. Each archive includes upstream's `LICENSE` and `NOTICE` files.
