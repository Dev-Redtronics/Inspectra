# AGENTS.md

Binding rules for every agent and every person working in this repository. Inspectra is a
supply-chain security scanner and package quality gate for Dart and Flutter, and it is built to the
standard it checks.

## Repository

| Path | Purpose |
|---|---|
| `bin/inspectra.dart` | Entry point; only starts `InspectraCommandRunner` and exits with its code |
| `lib/inspectra.dart` | The public API: runner, configuration, checks and finding model |
| `lib/builder.dart` | The build_runner builders declared in `build.yaml` |
| `lib/style.dart` | The API for custom style rules: `StyleRule`, `StyleChecker`, `runStyleHost` |
| `lib/lints/strict.yaml` | The lint preset consumers include; this repository includes it too |
| `lib/src/` | Everything else; private to the package |
| `api/inspectra.api` | The recorded public API; `inspectra api check` compares against it |
| `docs/` | The Writerside documentation |
| `test/` | Unit tests, mostly mirroring `lib/src/` (the quality-gate, builder and Trivy scan tests sit at the top level); `test/e2e/` drives the whole CLI in-process |
| `tool/` | `verify.dart` and `license_header.txt`, the header template of the style check |

## Verify

```bash
dart run tool/verify.dart
```

Runs, in order: `dart format --set-exit-if-changed`, `dart analyze --fatal-infos`,
`inspectra style` and `dart test`. Nothing is done until it is green. CI runs exactly this on
Linux, macOS and Windows, and then Inspectra on itself:

```bash
dart run build_runner build --only-check
dart run inspectra check
```

`check` runs the format, lint, style, API and changelog checks, every Trivy scan and the 90 %
coverage gate configured in the `inspectra:` section of `pubspec.yaml`. After a deliberate API change, record it with
`dart run inspectra api dump`.

## Architecture

- `cli/`: `InspectraCommandRunner` registers one `InspectraCommand` per command in `cli/command/`.
  The base class owns the life cycle: shared options, configuration, rendering, exit code.
  `CommandSession` is the composition root that wires every service.
- Each security feature is a package below `lib/src/`: `audit`, `inspect`, `trust`,
  `typosquat`, `add`, `hook`, `trivy`, `scan`. A feature returns a `CommandReport` with its own
  text and JSON layout.
- `baseline` records accepted findings in `inspectra-baseline.json` (`baseline create|prune`) and
  matches current findings against it: `FindingFilter` for the supply-chain commands,
  `baseline_gates.dart` for the lint, style and Trivy scan results of the commands, `check` and the
  builders. Keys leave out line numbers and package versions; counts make each further occurrence
  new.
- The package checks `check`, `format`, `lint`, `api`, `coverage` and `changelog check` extend
  `PackageCheckCommand`; their logic lives in `quality`, `api`, `coverage` and `changelog`, and
  `builders` runs the same checks and the Trivy scans from build_runner. `style` is an
  `InspectraCommand`, so that its findings can be rendered as SARIF.
- `style` runs structural rules on the syntax tree: the built-in rules in `style/rules`, selected by
  presets and switches, and custom rules of a package, which a generated program runs with `dart run`
  (`StyleHost`). Inspectra holds itself to the `strict` preset.
- `changelog` generates the changelog from Conventional Commits (`changelog generate`), validates it
  (`changelog check`) and prints release notes (`changelog notes`). It reads the history with the
  `git` command line through `ProcessRunner` (`GitHistory`); it has no dependency of its own.
- Shared building blocks: `model` (`Finding`, `Severity`, `InspectraException`), `config`
  (`loadConfig`, `InspectraConfig` with one class per section, `ConfigOverrides` for `--set` and
  `INSPECTRA_*`), `net` (`HttpTransport`), `io` (`Console`, `ProcessRunner`, `Environment`,
  `Clock`), `host`, `archive`, `pub`, `osv`, `report`, `policy`, `util`.
- Every side effect goes through an injected abstraction: `HttpTransport`, `ProcessRunner`,
  `Environment`, `Clock`, the sinks of `CommandContext`. No global state, no `print`.
- Expected failures are `InspectraException` subtypes; `ExitCode.of` maps them exhaustively:
  usage `64`, input `65`, unavailable `69`. Anything else is an internal error, `70`.
- Command names, flags, rule ids, JSON field names and exit codes are the consumer contract and
  change only in a major version. The `dart_audit` compatible names must never change.

## Code rules

Enforced by `dart analyze --fatal-infos` with the rules in `analysis_options.yaml` and by
`inspectra style` with the `strict` preset (`style:` in `pubspec.yaml`), without exceptions or ignore
comments.

- No `else`. Return early. A `switch` over an enum or sealed type is exhaustive and has neither
  `default` nor a wildcard `_` case.
- No comments: no `//`, no `/* */`. The license header is the only exception.
- A `///` documentation comment on **every** declaration, including private ones: classes, enums
  and their values, constructors, fields, methods, getters, top level functions and variables.
  Document purpose, parameters, the return value (`Returns ...`) and failures (`Throws ...`).
- Every file starts with the Apache-2.0 license header of `tool/license_header.txt`.
- One top level type per file, named after it in snake case. A sealed class and its direct subtypes
  share one file. A file of functions is named after its role.
- `strict-casts`, `strict-inference` and `strict-raw-types` are on. No `dynamic` calls, no `!`
  unless the value is provably present, no broad `catch` without `on`.
- Name intermediate results and computed conditions instead of nesting calls.
- Runtime dependencies are limited to `args`, `yaml`, `crypto`, `path`, `pub_semver` and
  `archive` for the security command line, and `analyzer`, `build`, `coverage` and `glob` for the
  quality gates and the builders. HTTP uses `dart:io`. Adding a dependency needs a maintainer's
  approval.

## Security rules

- Never execute or install anything that was not verified: package archives are checked against
  `archive_sha256`, Trivy downloads against the official `checksums.txt`. These checks are not
  configurable.
- Package archives are read in memory within `ArchiveLimits` and never extracted to disk.
- Untrusted text is passed through `SnippetSanitizer` before it reaches a terminal or report.
- An incomplete verification is never reported as clean and is never hidden by `--exit-zero`.

## Tests

`package:test` only, with hand written fakes from `test/support/` (`FakeProcessRunner`, `FakeGit`,
the loopback `FakeHttpServer`, `TestHarness`). No mocking library and no real network. Unit tests
use fakes instead of real external tools; the only exceptions are the integration test tagged
`trivy` (`@Tags(['trivy'])`), which runs the real Trivy and is skipped when Trivy is not installed,
the tests tagged `slow` (a generated package under `dart test`, a real Git repository, skipped
without Git, custom style rules run through `dart run`), and the quality tests that run the real `dart format` and `dart analyze` in
temporary packages. Tests follow the production packages where practical. Every change ships with
its tests; every fixed bug gets a regression test.

## Public API

`lib/inspectra.dart` is the contract. A deliberate change to an exported declaration, a command,
a flag, a rule id or a JSON field gets a `CHANGELOG.md` entry.

## Git

Work on `develop`, release from `main`. Conventional commits with the feature as scope
(`feat(trivy): ...`, `fix(audit): ...`). Commit only when asked. No agent co-author trailers.
