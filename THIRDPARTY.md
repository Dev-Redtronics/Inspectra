# Third-Party Software

This document lists the third-party software Inspectra uses or integrates with.

---

- [args](https://pub.dev/packages/args) - command line parsing, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/core/blob/main/pkgs/args/LICENSE).
- [yaml](https://pub.dev/packages/yaml) - YAML parsing, licensed under the
  [MIT License](https://github.com/dart-lang/yaml/blob/main/LICENSE).
- [crypto](https://pub.dev/packages/crypto) - SHA-256 checksums, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/core/blob/main/pkgs/crypto/LICENSE).
- [path](https://pub.dev/packages/path) - cross-platform paths, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/core/blob/main/pkgs/path/LICENSE).
- [pub_semver](https://pub.dev/packages/pub_semver) - version ranges, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/tools/blob/main/pkgs/pub_semver/LICENSE).
- [archive](https://pub.dev/packages/archive) - tar and zip decoding, licensed under the
  [MIT License](https://github.com/brendan-duncan/archive/blob/main/LICENSE); it bundles code under the
  licenses listed in its [LICENSE-other.md](https://github.com/brendan-duncan/archive/blob/main/LICENSE-other.md),
  among them the permissive bzip2-1.0.6 license that Trivy reports as unknown and the repository ignores.
- [analyzer](https://pub.dev/packages/analyzer) - the API dump and the style check, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/sdk/blob/main/pkg/analyzer/LICENSE).
- [build](https://pub.dev/packages/build) - the build_runner builders, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/build/blob/master/build/LICENSE).
- [coverage](https://pub.dev/packages/coverage) - collecting and formatting line coverage, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/tools/blob/main/pkgs/coverage/LICENSE).
- [glob](https://pub.dev/packages/glob) - include and exclude patterns, licensed under the
  [BSD 3-Clause License](https://github.com/dart-lang/tools/blob/main/pkgs/glob/LICENSE).
- [Trivy](https://github.com/aquasecurity/trivy) - vulnerability, secret, misconfiguration and
  license scanner, licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
  Inspectra downloads and runs the unmodified official release.
- [OSV.dev](https://osv.dev) - the open source vulnerability database queried by `audit`.
