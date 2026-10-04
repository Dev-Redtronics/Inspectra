# Contributing to Inspectra

Thank you for your interest in contributing to **Inspectra**! We welcome all contributions that help
improve the project — from bug fixes and new detection rules to documentation.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Standards](#development-standards)
  - [One command before you push](#one-command-before-you-push)
  - [Code style](#code-style)
  - [Package structure](#package-structure)
  - [Testing](#testing)
  - [The contract](#the-contract)
- [Commit Messages](#commit-messages)

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

- **Bugs:** open an issue with a clear title, the steps to reproduce, expected vs. actual behaviour,
  `inspectra --version`, `dart --version` and your operating system.
- **False positives / missed detections:** open an issue with the package name and version, the
  finding (JSON output is ideal) and why you think it is wrong.
- **Security problems:** never in a public issue — see [SECURITY.md](SECURITY.md).
- **Pull requests:** fork the repository and branch from `develop`. `main` carries releases;
  pull requests are merged into `develop`.

## Development Standards

### One command before you push

```bash
dart pub get
dart run tool/verify.dart
```

That is exactly what CI runs on Linux, macOS and Windows: formatting, the analyzer with infos as
errors, the style check and the test suite. CI additionally enforces 90 % line coverage.

### Code style

[AGENTS.md](AGENTS.md) is binding. In short:

- **No `else`.** Return early; switches over enums and sealed types are exhaustive without
  `default` or `_`.
- **No comments** other than the license header and `///` documentation.
- **Documentation on every declaration**, private ones included.
- **One top-level type per file**, named after it.
- **No new runtime dependencies** without a maintainer's approval.

`tool/style_check.dart` enforces these rules on the syntax tree, so a violation fails the build
with the file and line.

### Package structure

| Package | Holds |
|---|---|
| `lib/src/cli` | Command runner, shared options, commands, composition root |
| `lib/src/<feature>` | `audit`, `inspect`, `trust`, `typosquat`, `add`, `hook`, `trivy`, `scan` |
| `lib/src/{model,config,net,io,host,archive,pub,osv,report,policy,util}` | Shared building blocks |

### Testing

- `package:test` with the fakes in `test/support/`: `FakeHttpServer` (a real loopback server),
  `FakeProcessRunner` and `TestHarness`, which runs the whole CLI in-process.
- Tests mirror the production package. New rules need a test for what they report **and** for what
  they leave alone.
- No test may need the internet or an installed external tool.

### The contract

Command names, flags, rule ids, JSON field names and exit codes are what pipelines depend on. Change
them only deliberately, in a major version, with a `CHANGELOG.md` entry.

---

## Commit Messages

Conventional commits with the feature as scope, in the imperative mood:

- `feat(trivy): support Trivy mirrors with custom checksum files`
- `fix(audit): resolve the fix version per affected range`
- `docs(readme): document the configuration file`

---

## License

By contributing, you agree that your contributions will be licensed under the project's
**Apache License 2.0**.
