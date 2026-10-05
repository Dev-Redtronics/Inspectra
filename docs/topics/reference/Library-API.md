# Library API

<primary-label ref="library"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Running the checks from your own Dart tooling with package:inspectra.</link-summary>

<card-summary>The configuration, the scans, the API renderer, the coverage gate and the changelog check as Dart functions.</card-summary>

Most packages need %product% only as a dev dependency, its configuration, and the command line. For your own tooling -
a custom release script, a monorepo runner, a bot - everything the command line does is available as Dart API in
`package:inspectra/inspectra.dart`. Inspectra's public API is recorded in its own
[`api/inspectra.api`](%repo%/blob/main/api/inspectra.api), and changes to it follow semantic versioning.

```dart
import 'package:inspectra/inspectra.dart';
```

## Running the command line in-process {id="in-process"}

`InspectraCommandRunner` is the whole command line. `bin/inspectra.dart` does nothing but run it with
`CommandContext.system()` and exit with the code it returns:

```dart
final runner = InspectraCommandRunner(CommandContext.system());
final int code = await runner.run(['audit', '--format', 'json']);
```

Every side effect goes through the `CommandContext`, so tooling and tests can capture the output, change the working
directory or replace the environment, the clock and the processes %product% starts:

```dart
final out = StringBuffer();
final context = CommandContext(
  environment: Environment({'INSPECTRA_TRIVY_MODE': 'disabled'}),
  clock: const Clock.system(),
  processRunner: const SystemProcessRunner(),
  host: HostPlatform.current(),
  workingDirectory: '/path/to/package',
  out: out,
  err: StringBuffer(),
);
final int code = await InspectraCommandRunner(context).run(['scan', '--offline']);
```

| API | Description |
|:--|:--|
| `InspectraCommandRunner(context)` | The `inspectra` command line; `run(args)` returns the exit code and never calls `exit`. |
| `CommandContext({environment:, clock:, processRunner:, host:, workingDirectory:, out:, err:, outIsTerminal, supportsAnsi, sleep})` | Everything a command reads from or writes to its process. `CommandContext.system()` is the real process. |
| `ExitCode` | `success` `0`, `findings` `1`, `usage` `64`, `dataError` `65`, `unavailable` `69`, `software` `70`; `code`, and `ExitCode.of(error)` for an `InspectraException`. |
| `Environment(variables)`, `Environment.current()` | The environment variables; `homeDirectory`, `pathEntries(separator)`. |
| `Clock(now)`, `Clock.system()` | The current time, replaceable in tests. |
| `ProcessRunner` | Starts external processes: `run(executable, arguments, {workingDirectory, environment, runInShell, timeout})`. |
| `SystemProcessRunner` | The `dart:io` implementation; a timed-out process reports `timedOutExitCode`. |
| `ProcessOutcome` | `exitCode`, `stdout`, `stderr`, `succeeded`. |
| `HostPlatform` | Operating system and CPU architecture: `HostPlatform.current()`, `isWindows`, `pathListSeparator`. |
| `ConfigOverrides({cli, environment})` | The `--set` values and `INSPECTRA_*` variables applied on top of the configuration file; `ConfigOverrides.none()`, `environmentName(path)`. |
| `inspectraVersion` | The version of %product%, as printed by `inspectra --version`. |

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
| `loadConfig(root, {overrides, configFile, requirePubspec})` | With `ConfigOverrides` for `--set` values and `INSPECTRA_*` variables, and another configuration file. |
| `loadConfig(root, {recorder})`, `parse(…, recorder:)`, `fromSources(…, recorder:)` | With a `ConfigRecorder`, which afterwards holds a `ConfigEntry` per option: `key`, `kind` (`ConfigKind`), `value`, `defaultValue`, `origin` (`ConfigOrigin`: `defaults`, `file`, `environment`, `commandLine`), `variable`, `line`, `options`, `minimum`, `maximum`; `recorder.source` names the file. This is what `config show --explain` prints. |
| `loadConfig(root, {cacheRoot})`, `fromSources(…, packageRoot:, cacheRoot:, configDirectory:)` | Follow `extends`: relative paths, `package:` bases and remote bases from the cache. `entry.file` names the base of each value and `recorder.layers` lists the `ConfigLayer`s (`label`, `kind`: `ConfigLayerKind.project`, `file`, `package` or `remote`). |
| `InspectraConfig.fromLayers(stack, packageName:)` | From a `ConfigLayerStack` of layers, enforcing their `ConfigPolicy` (`locked`, `minimum`, ordered by `ConfigStrictness`). |
| `ConfigOverrides.resolve(path)` | The override of an option as a `ConfigOverride` with `value`, `origin` and `variable`; `knownPaths` lists every option that can be overridden. |
| `configFileName`, `pubspecSectionKey` | `'%config_file%'`, `'%pubspec_key%'` |

The configuration classes - `FormatConfig`, `LintConfig`, `TrivyConfig`, `SecretScanConfig`, `LicenseScanConfig`,
`VulnerabilityScanConfig`, `FilesystemScanConfig`, `ApiConfig`, `CoverageConfig`, and for the supply-chain commands
`NetworkConfig`, `InspectConfig`, `TrustThresholds`, `TyposquatConfig`, `IgnoreRule`, `BaselineConfig`,
`DependencyPolicyConfig` and `DeniedPackage` - are immutable and have
`const` constructors, so tooling can also build a configuration without YAML.

## Running the format and lint checks

```dart
final FormatResult format = await runFormatCheck(config, packageRoot);
final LintResult lint = await runLintCheck(config, packageRoot, fix: true);

for (final issue in lint.failing) {
  print('${issue.path}:${issue.line} ${issue.code}');
}
```

| API | Description |
|:--|:--|
| `runFormatCheck(config, root, {fix})` | What `dart run inspectra format` does, including the JSON report. |
| `runLintCheck(config, root, {fix})` | What `dart run inspectra lint` does, including the JSON report, but without applying the [baseline](Baseline.md). |
| `checkFormat(config:, packageRoot:, files:, {fix})` | `dart format` on an explicit list of files. |
| `runLint(config:, packageRoot:, {fix})` | `dart analyze`, optionally after `dart fix --apply`. |
| `parseAnalyzerOutput(output, root)` | The diagnostics of `dart analyze --format=machine`. |
| `FormatResult` | `checked`, `unformatted`, `fixed`, `failed`, `render()`, `toJson()`. |
| `LintResult` | `issues`, `failing`, `failOn`, `failed`, `baseline`, `render()`, `toJson()`. |
| `LintIssue` | `severity`, `type`, `code`, `path`, `line`, `column`, `message`. |
| `LintLevel` | `error`, `warning`, `info`, `none`. |
| `DartToolException` | `dart format`, `dart analyze` or `dart fix` could not run or failed. |

## Running the style check {id="style"}

```dart
final StyleResult result = await runStyleCheck(config, packageRoot);
for (final StyleViolation violation in result.violations) {
  print(violation); // lib/a.dart:3:5: No else: return early instead. [no_else]
}
```

| API | Description |
|:--|:--|
| `runStyleCheck(config, root)` | What `dart run inspectra style` does, including the JSON report, but without applying the [baseline](Baseline.md). |
| `checkStyle(config:, packageRoot:, files:, {read})` | The style check of an explicit list of files; `read` replaces reading from disk. |
| `StyleResult` | `checked`, `rules`, `violations`, `failed`, `affectedFiles`, `baseline`, `render()`, `toJson()`. |
| `StyleViolation` | `ruleId`, `path`, `line`, `column`, `message`. |
| `StyleConfig`, `StylePreset` | The `style:` section; `runs(id)` tells whether a rule runs. |

Custom rules are written against the separate library `package:inspectra/style.dart`: `StyleRule`, `StyleFile`,
`StyleReporter`, `StyleViolation`, `StyleChecker` and `runStyleHost`. See
[Custom style rules](Style-Custom-Rules.md#api).

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
        <p>The configured scans of <code>dart run inspectra trivy</code>, including the JSON reports. Pass
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
| `runTrivyScans(config, root, {only, executable})` | Every enabled scan, or the ones in `only`; writes the reports. With `network.offline`, Trivy runs offline. |
| `scanSecrets`, `scanLicenses`, `scanVulnerabilities`, `scanFilesystem` | One scan each, on explicit inputs. |
| `Trivy({executable, environment, workingDirectory, offline})` | The Trivy runner; `scanFilesystem` returns a parsed `TrivyReport`. `offline: true` adds `--skip-db-update --offline-scan` to every `trivy fs` call. |
| `ScanResult` | `scan`, `findings`, `failed`, `skipped`, `baseline`, `render()`, `toJson()`. |
| `BaselineSummary` | What a baseline did to a check result: `covered`, `stale`, `failOnStale`, `failed`. |
| `ScanFinding` | One finding of a scan: `severity`, `target`, `id`, `title`, `detail`. |
| `TrivyScan` | `secret`, `license`, `vulnerability`, `filesystem`; `isEnabled(config)`. |
| `PackageGraph.load(root)` | The dependency graph; `reachable(includeDev:)`, `directoryOf(name)`, `lock`. |
| `PubspecLock.parse(text)` | A parsed lock file; `retain(names)` writes a narrowed one. |
| `collectFiles(root, include, exclude)` | The files the secret scan would read. |
| `resolveSecretConfig(root, configured)` | The secret rules file in use, or `null`. |
| `TrivyException` | Trivy is missing or failed. |

`runTrivyScans` does not provision Trivy. It starts the executable named by `%trivy_env%` when that is set, else
`executable`, else `trivy.executable`, else `trivy` on the `PATH`. The command line provisions Trivy first - an
installed one, a cached download or a verified download, see [Installing Trivy](Trivy-Installation.md#provisioning) -
and passes the result as `executable`. It also calls `runTrivyScans` only for named scans or with `trivy.enabled: true`;
otherwise `inspectra trivy` runs a plain `trivy fs` scan of the package instead. With `network.offline: true`,
`runTrivyScans` starts Trivy with `--skip-db-update --offline-scan`, so without a cached database the vulnerability
scan fails with a `TrivyException`.

## Checking the changelog {id="changelog"}

```dart
final ChangelogCheckResult result = checkChangelog(config, '/path/to/package');
if (result.failed) {
  for (final ChangelogProblem problem in result.problems) {
    print('${result.path}:${problem.line ?? '-'}: ${problem.message}');
  }
}
```

| API | Description |
|:--|:--|
| `checkChangelog(config, packageRoot)` | Validates `changelog.file` against the version of `pubspec.yaml`, as `changelog check` does. Throws `InvalidInputException` for a malformed `pubspec.yaml`. |
| `ChangelogCheckResult` | `path`, `version` (of `pubspec.yaml`, or `null`), `problems`, `failed`, `render()`. |
| `ChangelogProblem` | `message` and the one-based `line`, `null` for problems of the whole file. |
| `ChangelogConfig`, `ChangelogSection` | The `changelog:` section, part of `InspectraConfig`; `sectionOf(type)` maps a commit type to its section. |

Generating a changelog reads the Git history; run it through the command line, in-process if you like:
`InspectraCommandRunner(context).run(['changelog', 'generate', '-f', 'json'])`.

## The finding model {id="findings"}

The supply-chain commands - `scan`, `audit`, `inspect`, `trust`, `typosquat`, `add`, `hook` and `trivy` without
configured scans - report the normalised `Finding`, which the JSON, SARIF, Markdown and CI reports serialise.

| API | Description |
|:--|:--|
| `Finding` | `ruleId`, `source`, `severity`, `title`, `description`, `location`, `packageName`, `packageVersion`, `fixedVersion`, `aliases`, `url`, `snippet`, `attributes`; `identifiers`, `fingerprint` (a stable SHA-256), `toJson()`. |
| `FindingSource` | The scanner: `osv`, `trivy`, `regex`, `entropy`, `unicode`, `archive`, `pubspec`, `trust`, `typosquat`, `confusion`, `style`, `config`, `quality`; `id`, `tryParse`. |
| `SourceLocation(path, {line})` | The file and line a finding refers to. |
| `Severity` | `critical`, `high`, `medium`, `low`, `unknown`; `label`, `trivyName`, `isAtLeast(threshold)`, `parse`, `tryParse`, `fromCvssScore`. Shared by `Finding` and `ScanFinding`. |
| `IgnoreRule({id:, reason:, package, expires})` | An `ignore:` entry; `matches(finding)`, `isExpired(now)`. |

## Errors {id="errors"}

| API | Description |
|:--|:--|
| `InspectraException` | The sealed base of the expected failures; `message`. `ExitCode.of` maps each subtype to its exit code. |
| `InvalidUsageException` | An invalid command line, exit code `64`. |
| `InvalidInputException` | An invalid lock file, pubspec or configuration, exit code `65`. |
| `UnavailableException` | A service, tool or Trivy is unavailable or failed, exit code `69`. |
| `InspectraConfigException` | Invalid configuration; `path` names the offending key. |

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

## Checking semantic versioning {id="semver"}

```dart
final SemverResult result = await checkSemver(
  config,
  packageRoot,
  GitHistory(processRunner: const SystemProcessRunner(), workingDirectory: packageRoot),
);
print(result.render());

final List<ApiChange> changes = classifyApiChanges(
  ApiSurface.parse(oldDump),
  ApiSurface.parse(newDump),
);
```

| API | Description |
|:--|:--|
| `checkSemver(config, root, history, {from})` | Compares the dump at the last release tag, or at `from`, with the rendered API and checks the version, as `api semver` does. |
| `evaluateSemver(before:, after:, baseline:, baselineVersion:, version:, commits:)` | The same comparison for two dumps you already have, without Git. |
| `SemverResult` | `changes`, `breaking`, `additive`, `bump`, `required`, `violated`, `undeclaredBreaking`, `skipped`, `findings`, `render()`, `toJson()`. |
| `classifyApiChanges(before, after)` | Every `ApiChange` between two `ApiSurface`s, with its `ApiChangeKind` and reason. |
| `ApiSurface.parse(dump)` | The libraries, declarations, members and enum values of a dump. |

## Running the coverage gate

```dart
final CoverageReport report = await runCoverage(
  config.coverage,
  packageRoot,
  minLineCoverage: 90,
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

`package:inspectra/builder.dart` exports the six builder factories - `formatBuilder`, `lintBuilder`, `apiBuilder`,
`secretScanBuilder`, `licenseScanBuilder`, `vulnerabilityScanBuilder`. They are referenced from %product%'s `build.yaml`; you do not call
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
