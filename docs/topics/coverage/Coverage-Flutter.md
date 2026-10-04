# Flutter

<primary-label ref="cli"/>
<secondary-label ref="cli-only"/>
<secondary-label ref="opt-in"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Using the coverage gate in Flutter apps and packages, and what differs from plain Dart.</link-summary>

<card-summary>runner: flutter runs flutter test --coverage and gates its lcov.</card-summary>

<tldr>
<p><b>Configure</b>: <code>coverage: { enabled: true, runner: flutter }</code></p>
<p><b>Runs</b>: <code>flutter test --coverage --coverage-path coverage/raw/lcov.info</code></p>
<p><b>Requires</b>: <code>flutter</code> on the <code>PATH</code></p>
</tldr>

Flutter widget tests need the Flutter test environment, which `dart test` does not provide. With `runner: flutter`,
%product% runs `flutter test` instead and reads the lcov report Flutter writes.

```yaml
inspectra:
  coverage:
    enabled: true
    runner: flutter
    min_line_coverage: 70
```

## What happens

1. `flutter test --coverage --coverage-path <output_directory>/raw/lcov.info <test_arguments>` runs, with its output
   shown.
2. %product% reads the lcov file: each `SF:` entry, with relative paths resolved against the package root, and its
   `DA:` line counts. Repeated entries for the same file are summed.
3. From there on it is the same as for Dart: `report_on` and `exclude` filter the files, `coverage/lcov.info` is
   written, the table printed and the threshold checked.

## Differences from runner: dart

| | `dart` | `flutter` |
|:--|:--|:--|
| Runs | `dart test --coverage=…` | `flutter test --coverage --coverage-path …` |
| Raw output | JSON hit maps per test file | One `lcov.info` |
| `coverage:ignore` comments | Applied by %product% through `package:coverage` | Applied by Flutter's collector, as supported by your Flutter version |
| Integration tests | `integration_test/` is not run unless passed in `test_arguments` | `integration_test/` needs a device and is not run by `flutter test` by default |

## Everything else works the same

Packages in the same repository can mix runners: a `core` package with `runner: dart` and the app with
`runner: flutter`, each with its own threshold:

```bash
dart run inspectra -C packages/core coverage
dart run inspectra -C app coverage
```

The rest of %product% - API dump, Trivy scans - does not depend on the runner. In a Flutter package, use
`flutter pub run build_runner build` or `dart run build_runner build` as you do for other builders, and
`dart run %package% …` for the command line.

<note>
SDK packages such as <code>flutter</code> and <code>sky_engine</code> are never checked by the license scan: they come
with the toolchain, not from pub.dev.
</note>

<seealso>
    <category ref="coverage">
        <a href="Coverage-Overview.md">Coverage</a>
        <a href="Coverage-Configuration.md">Configuration</a>
    </category>
    <category ref="external">
        <a href="https://docs.flutter.dev/testing/code-coverage">Flutter code coverage</a>
    </category>
</seealso>
