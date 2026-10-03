# Library API

<primary-label ref="library"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Running the checks from your own Dart tooling with package:inspectra.</link-summary>

<card-summary>The configuration, the scans, the API renderer and the coverage gate as Dart functions.</card-summary>

Most packages need %product% only as a dev dependency, its configuration, and the command line. For your own tooling -
a custom release script, a monorepo runner, a bot - everything the command line does is available as Dart API in
`package:inspectra/inspectra.dart`. Inspectra's public API is recorded in its own
[`api/inspectra.api`](%repo%/blob/main/api/inspectra.api), and changes to it follow semantic versioning.

```dart
import 'package:inspectra/inspectra.dart';
```

## Loading the configuration

```dart
final InspectraConfig config = loadConfig('/path/to/package');

print(config.packageName);               // from pubspec.yaml
print(config.trivy.secret.severity);     // [Severity.critical, Severity.high, ...]
```

| API | Description |
|:--|:--|
| `loadConfig(packageRoot)` | Reads `%config_file%` or the `%pubspec_key%:` section of `pubspec.yaml` from disk. Throws `InspectraConfigException` or `FileSystemException`. |
| `InspectraConfig.fromSources(pubspec:, configFile:)` | The same from strings. |
| `InspectraConfig.parse(node, packageName:)` | From a parsed YAML or plain map. |
| `InspectraConfig.defaults(packageName)` | Every default; every feature off. |
| `configFileName`, `pubspecSectionKey` | `'%config_file%'`, `'%pubspec_key%'` |

The configuration classes - `TrivyConfig`, `SecretScanConfig`, `LicenseScanConfig`, `VulnerabilityScanConfig`,
`FilesystemScanConfig`, `ApiConfig`, `CoverageConfig` - are immutable and have `const` constructors, so tooling can also
build a configuration without YAML.

## Running the Trivy scans

<tabs group="scans">
    <tab title="All enabled scans" group-key="all">
        <code-block lang="dart"><![CDATA[
final List<ScanResult> results = await runTrivyScans(config, packageRoot);
for (final result in results) {
  print(result.render());
}
final bool failed = results.any((result) => result.failed);
]]></code-block>
        <p>Exactly what <code>dart run inspectra trivy</code> does, including the JSON reports. Pass
            <code>only: {TrivyScan.secret}</code> to choose scans.</p>
    </tab>
    <tab title="One scan" group-key="one">
        <code-block lang="dart"><![CDATA[
final trivy = Trivy(workingDirectory: packageRoot);

final ScanResult secrets = await scanSecrets(
  trivy: trivy,
  config: config.trivy.secret,
  files: {'lib/config.dart': await File('lib/config.dart').readAsBytes()},
  secretConfig: resolveSecretConfig(packageRoot, config.trivy.secret.config),
);

final ScanResult licenses = await scanLicenses(
  trivy: trivy,
  config: config.trivy.license,
  graph: await PackageGraph.load(packageRoot),
);
]]></code-block>
    </tab>
</tabs>

| API | Description |
|:--|:--|
| `runTrivyScans(config, root, {only})` | Every enabled scan, or the ones in `only`; writes the reports. |
| `scanSecrets`, `scanLicenses`, `scanVulnerabilities`, `scanFilesystem` | One scan each, on explicit inputs. |
| `Trivy({executable, environment, workingDirectory})` | The Trivy runner; `scanFilesystem` returns a parsed `TrivyReport`. |
| `ScanResult` | `scan`, `findings`, `failed`, `skipped`, `render()`, `toJson()`. |
| `Finding` | `severity`, `target`, `id`, `title`, `detail`. |
| `Severity` | `critical`, `high`, `medium`, `low`, `unknown`; `trivyName`, `tryParse`. |
| `TrivyScan` | `secret`, `license`, `vulnerability`, `filesystem`; `isEnabled(config)`. |
| `PackageGraph.load(root)` | The dependency graph; `reachable(includeDev:)`, `directoryOf(name)`, `lock`. |
| `PubspecLock.parse(text)` | A parsed lock file; `retain(names)` writes a narrowed one. |
| `collectFiles(root, include, exclude)` | The files the secret scan would read. |
| `resolveSecretConfig(root, configured)` | The secret rules file in use, or `null`. |
| `TrivyException` | Trivy is missing or failed. |

## Rendering and checking the API

```dart
final ApiCheckResult result = await checkApi(config, packageRoot);
if (result.failed) {
  print(result.render());
}

final String dump = await renderPackageApi(config, packageRoot);
final String? diff = diffApi(expected: oldDump, actual: dump);
```

| API | Description |
|:--|:--|
| `renderPackageApi(config, root)` | The dump, rendered with the analyzer. |
| `dumpApi(config, root)` | Renders and writes it; returns the path. |
| `checkApi(config, root)` | Compares with the committed dump; `ApiCheckResult` has `failed`, `missing`, `diff`, `render()`. |
| `renderApi(libraries, {nonPublicAnnotations})` | The dump of analyzer `LibraryElement`s you resolved yourself. |
| `diffApi(expected:, actual:)` | The unified diff of two dumps, or `null`. |
| `apiDumpHeader` | The two comment lines every dump starts with. |

## Running the coverage gate

```dart
final CoverageReport report = await runCoverage(
  config.coverage,
  packageRoot,
  minLineCoverage: 85,
);
print('${report.percent.toStringAsFixed(2)}% of ${report.linesFound} lines');
for (final file in report.files) {
  print('${file.path}: ${file.percent}');
}
```

| API | Description |
|:--|:--|
| `runCoverage(config, root, {minLineCoverage})` | Runs the tests, writes `lcov.info`, returns the report. Throws `CoverageException` when the tests fail. |
| `CoverageReport` | `files`, `untested`, `linesFound`, `linesHit`, `percent`, `failed`, `lcovPath`, `render()`. |
| `FileCoverage` | `path`, `linesFound`, `linesHit`, `percent`. |
| `parseLcov(text, root)` | Hit maps from an lcov report, as used for Flutter. |

## The builders

`package:inspectra/builder.dart` exports the four builder factories - `apiBuilder`, `secretScanBuilder`,
`licenseScanBuilder`, `vulnerabilityScanBuilder`. They are referenced from %product%'s `build.yaml`; you do not call
them yourself.

<seealso>
    <category ref="reference">
        <a href="CLI-Reference.md">Command line reference</a>
        <a href="Builder-Reference.md">Builder reference</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md">Configuration reference</a>
    </category>
</seealso>
