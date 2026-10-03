## 1.0.0

- Trivy scans for secrets, dependency licenses, dependency vulnerabilities and a plain filesystem
  scan, configurable per scan and runnable from `build_runner` or the `inspectra` command line.
- Public API dump of every public library, written by the `inspectra:api` builder and checked with
  `build_runner build --only-check` or `inspectra api check`.
- Coverage gate on top of `package:coverage` with an optional line coverage threshold.
- One configuration, in the `inspectra:` section of `pubspec.yaml` or in `inspectra.yaml`, with
  strict validation of every key.
- The API dump records the values of constants and `const` primary constructors of extension types,
  and changes are shown as a unified diff of the changed lines with context.
- Configuration errors name the line and column of a YAML syntax error; empty lists of severities
  or scanners are rejected.
- An unresolved package reports `run "dart pub get"` instead of a stack trace.
- Files marked `// coverage:ignore-file` are not listed as untested.
- Writerside documentation in `docs/`, published to GitHub Pages.
- Format check (`dart format`) and lint check (`dart analyze`, `fail_on: error|warning|info|none`)
  from `dart run inspectra format|lint`, with `--fix`, as the first steps of `check`, and as
  `build_runner` builders that run after every code generator.
- A strict lint preset, `package:inspectra/lints/strict.yaml`.
