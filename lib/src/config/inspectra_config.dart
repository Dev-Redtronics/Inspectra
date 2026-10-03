import 'package:inspectra/src/config/config_exception.dart';
import 'package:inspectra/src/config/severity.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:yaml/yaml.dart';

/// The name of the dedicated configuration file in the package root.
const configFileName = 'inspectra.yaml';

/// The key of the configuration section inside `pubspec.yaml`.
const pubspecSectionKey = 'inspectra';

/// The complete Inspectra configuration of one package.
///
/// It is read from `inspectra.yaml` in the package root when that file exists,
/// and otherwise from the `inspectra:` section of `pubspec.yaml`. Both hold the
/// same keys. Every feature is opt-in: a package that configures nothing gets
/// no format or lint check, no scans, no API dump and no coverage gate.
class InspectraConfig {
  /// Creates a configuration from its parts.
  const InspectraConfig({
    required this.packageName,
    required this.format,
    required this.lint,
    required this.trivy,
    required this.api,
    required this.coverage,
  });

  /// The configuration with every default, for the package [packageName].
  factory InspectraConfig.defaults(String packageName) =>
      InspectraConfig.parse(null, packageName: packageName);

  /// Parses the configuration mapping [node], which lives at [path].
  ///
  /// Throws an [InspectraConfigException] for an unknown key or a value of
  /// the wrong type.
  factory InspectraConfig.parse(
    Object? node, {
    required String packageName,
    String path = '',
  }) {
    final root = YamlReader(node, path);
    final config = InspectraConfig(
      packageName: packageName,
      format: FormatConfig._parse(root.section('format')),
      lint: LintConfig._parse(root.section('lint')),
      trivy: TrivyConfig._parse(root.section('trivy')),
      api: ApiConfig._parse(root.section('api'), packageName),
      coverage: CoverageConfig._parse(root.section('coverage')),
    );
    root.ensureFullyRead();
    return config;
  }

  /// Reads the configuration from the text of the package's files.
  ///
  /// [pubspec] is the content of `pubspec.yaml`; [configFile] that of
  /// `inspectra.yaml`, or `null` when the package has none. [configFile]
  /// wins when both are present.
  factory InspectraConfig.fromSources({
    required String pubspec,
    String? configFile,
  }) {
    final Object? pubspecYaml = _load(pubspec, 'pubspec.yaml');
    final Object? packageName = pubspecYaml is Map ? pubspecYaml['name'] : null;
    if (packageName is! String) {
      throw const InspectraConfigException(
        'pubspec.yaml',
        'the package has no name.',
      );
    }
    if (configFile != null) {
      return InspectraConfig.parse(
        _load(configFile, configFileName),
        packageName: packageName,
      );
    }
    final Object? section = pubspecYaml is Map
        ? pubspecYaml[pubspecSectionKey]
        : null;
    return InspectraConfig.parse(
      section,
      packageName: packageName,
      path: pubspecSectionKey,
    );
  }

  static Object? _load(String text, String source) {
    try {
      return loadYaml(text, sourceUrl: Uri.file(source));
    } on YamlException catch (error) {
      final int? line = error.span?.start.line;
      final int? column = error.span?.start.column;
      final location = line == null || column == null
          ? ''
          : 'line ${line + 1}, column ${column + 1}: ';
      throw InspectraConfigException(source, '$location${error.message}');
    }
  }

  /// The name of the package this configuration belongs to.
  final String packageName;

  /// The formatting check.
  final FormatConfig format;

  /// The static analysis check.
  final LintConfig lint;

  /// The security and compliance scans.
  final TrivyConfig trivy;

  /// Public API validation.
  final ApiConfig api;

  /// The test coverage gate.
  final CoverageConfig coverage;
}

/// The generated files left out of the format check and the coverage report
/// by default: code generators write them, and their formatting and coverage
/// are the generator's business.
const _generatedFiles = <String>[
  '**.g.dart',
  '**.freezed.dart',
  '**.mocks.dart',
];

/// The formatting check, done by `dart format`.
class FormatConfig {
  /// Creates the formatting settings.
  const FormatConfig({
    required this.enabled,
    required this.runOnBuild,
    required this.failOnFindings,
    required this.include,
    required this.exclude,
    required this.pageWidth,
  });

  factory FormatConfig._parse(YamlReader yaml) {
    final config = FormatConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      include: yaml.strings('include', fallback: defaultInclude),
      exclude: yaml.strings('exclude', fallback: defaultExclude),
      pageWidth: yaml.optionalInt('page_width', min: 1, max: 1000),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The Dart files checked by default.
  static const defaultInclude = <String>['**.dart'];

  /// The files never checked by default: tool caches, build output and the
  /// output of the common code generators.
  static const List<String> defaultExclude = [
    '**/.dart_tool/**',
    '**/build/**',
    ..._generatedFiles,
  ];

  /// Whether the formatting is checked. Off by default.
  final bool enabled;

  /// Whether `dart run build_runner build` checks it too.
  final bool runOnBuild;

  /// Whether unformatted files fail the build or the command.
  final bool failOnFindings;

  /// Globs of the files to check, relative to the package root.
  final List<String> include;

  /// Globs of the files to leave out, relative to the package root.
  final List<String> exclude;

  /// The line length, or `null` for the `formatter: page_width` of
  /// `analysis_options.yaml`, and 80 without one.
  final int? pageWidth;
}

/// The lowest severity of a `dart analyze` diagnostic that fails the check.
enum LintLevel {
  /// Only errors fail.
  error,

  /// Errors and warnings fail.
  warning,

  /// Errors, warnings and infos - including every lint - fail, like
  /// `dart analyze --fatal-infos`.
  info,

  /// Nothing fails; diagnostics are only reported.
  none,
}

/// The static analysis check, done by `dart analyze`.
class LintConfig {
  /// Creates the static analysis settings.
  const LintConfig({
    required this.enabled,
    required this.runOnBuild,
    required this.failOn,
  });

  factory LintConfig._parse(YamlReader yaml) {
    final String failOn = yaml.string('fail_on', fallback: LintLevel.info.name);
    final config = LintConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOn: LintLevel.values.firstWhere(
        (level) => level.name == failOn,
        orElse: () => throw InspectraConfigException(
          '${yaml.path.isEmpty ? '' : '${yaml.path}.'}fail_on',
          'expected one of '
              '${LintLevel.values.map((level) => level.name).join(', ')}, '
              'got "$failOn".',
        ),
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether the package is analyzed. Off by default.
  final bool enabled;

  /// Whether `dart run build_runner build` analyzes it too.
  final bool runOnBuild;

  /// The lowest severity that fails the check.
  final LintLevel failOn;
}

/// The Trivy scans.
class TrivyConfig {
  /// Creates a Trivy configuration from its parts.
  const TrivyConfig({
    required this.enabled,
    required this.executable,
    required this.reportDirectory,
    required this.secret,
    required this.license,
    required this.vulnerability,
    required this.filesystem,
  });

  factory TrivyConfig._parse(YamlReader yaml) {
    final config = TrivyConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      executable: yaml.optionalString('executable'),
      reportDirectory: yaml.string(
        'report_directory',
        fallback: '.dart_tool/inspectra/trivy',
      ),
      secret: SecretScanConfig._parse(yaml.section('secret')),
      license: LicenseScanConfig._parse(yaml.section('license')),
      vulnerability: VulnerabilityScanConfig._parse(
        yaml.section('vulnerability'),
      ),
      filesystem: FilesystemScanConfig._parse(yaml.section('filesystem')),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether any scan runs at all. Off by default.
  final bool enabled;

  /// The Trivy executable; `null` looks it up on the `PATH`.
  ///
  /// The environment variable `INSPECTRA_TRIVY` overrides it, which lets a CI
  /// image point at its own binary without editing the configuration.
  final String? executable;

  /// Where the command line writes the JSON report of each scan.
  final String reportDirectory;

  /// Scanning sources and configuration files for credentials.
  final SecretScanConfig secret;

  /// Checking the licenses of dependencies.
  final LicenseScanConfig license;

  /// Checking dependencies for known vulnerabilities.
  final VulnerabilityScanConfig vulnerability;

  /// A plain `trivy fs` scan of the whole package.
  final FilesystemScanConfig filesystem;
}

/// Settings shared by every Trivy scan.
abstract class ScanConfig {
  /// Creates the shared settings.
  const ScanConfig({
    required this.enabled,
    required this.failOnFindings,
    required this.severity,
  });

  /// Whether this scan runs when Trivy is enabled.
  final bool enabled;

  /// Whether findings fail the build or the command.
  final bool failOnFindings;

  /// The severities that are reported; anything else is ignored.
  final List<Severity> severity;
}

List<Severity> _severities(YamlReader yaml, List<Severity> fallback) =>
    yaml.enums(
      'severity',
      fallback: fallback,
      parse: Severity.tryParse,
      expected: Severity.expected,
    );

/// Settings of a scan that `build_runner` can run as well.
abstract class BuildScanConfig extends ScanConfig {
  /// Creates the settings.
  const BuildScanConfig({
    required super.enabled,
    required this.runOnBuild,
    required super.failOnFindings,
    required super.severity,
  });

  /// Whether `dart run build_runner build` runs this scan too.
  ///
  /// Only the secret scan does by default: it reads files that are already
  /// on disk and costs a second. The vulnerability scan downloads Trivy's
  /// database, and the license scan reads the license file of every
  /// dependency, so both run from the command line or in CI unless enabled
  /// here.
  final bool runOnBuild;
}

/// The secret scan.
class SecretScanConfig extends BuildScanConfig {
  /// Creates the secret scan settings.
  const SecretScanConfig({
    required super.enabled,
    required super.runOnBuild,
    required super.failOnFindings,
    required super.severity,
    required this.config,
    required this.include,
    required this.exclude,
  });

  factory SecretScanConfig._parse(YamlReader yaml) {
    final config = SecretScanConfig(
      enabled: yaml.boolean('enabled', fallback: true),
      runOnBuild: yaml.boolean('run_on_build', fallback: true),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      severity: _severities(yaml, const [
        Severity.critical,
        Severity.high,
        Severity.medium,
        Severity.low,
      ]),
      config: yaml.optionalString('config'),
      include: yaml.strings('include', fallback: defaultInclude),
      exclude: yaml.strings('exclude', fallback: defaultExclude),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The files scanned by default: the Dart sources and the configuration
  /// files a credential is actually pasted into.
  static const defaultInclude = <String>[
    '**.dart',
    '**.yaml',
    '**.yml',
    '**.json',
    '**.env',
    '**.properties',
  ];

  /// The files never scanned by default: generated output and tool caches.
  /// A secret there is a copy of one in a file this scan already reads.
  static const defaultExclude = <String>[
    '**/.dart_tool/**',
    '**/build/**',
    '**/.git/**',
  ];

  /// The Trivy secret configuration file, relative to the package root.
  ///
  /// When `null`, `trivy-secret.yaml` is used if it exists; a file that is
  /// named explicitly must exist.
  final String? config;

  /// Globs of the files to scan, relative to the package root.
  final List<String> include;

  /// Globs of the files to leave out, relative to the package root.
  final List<String> exclude;
}

/// The license scan.
class LicenseScanConfig extends BuildScanConfig {
  /// Creates the license scan settings.
  const LicenseScanConfig({
    required super.enabled,
    required super.runOnBuild,
    required super.failOnFindings,
    required super.severity,
    required this.ignoredLicenses,
    required this.ignoredPackages,
    required this.includeDevDependencies,
  });

  factory LicenseScanConfig._parse(YamlReader yaml) {
    final config = LicenseScanConfig(
      enabled: yaml.boolean('enabled', fallback: true),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      severity: _severities(yaml, const [
        Severity.critical,
        Severity.high,
        Severity.unknown,
      ]),
      ignoredLicenses: yaml.strings('ignored_licenses', fallback: const []),
      ignoredPackages: yaml.strings('ignored_packages', fallback: const []),
      includeDevDependencies: yaml.boolean(
        'include_dev_dependencies',
        fallback: false,
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// SPDX identifiers of licenses that are never reported.
  final List<String> ignoredLicenses;

  /// Names of packages whose license is never reported.
  final List<String> ignoredPackages;

  /// Whether `dev_dependencies` are checked too.
  ///
  /// Off by default: a license binds what is shipped, and a package that only
  /// your tests or your build use never reaches a consumer.
  final bool includeDevDependencies;
}

/// The vulnerability scan.
class VulnerabilityScanConfig extends BuildScanConfig {
  /// Creates the vulnerability scan settings.
  const VulnerabilityScanConfig({
    required super.enabled,
    required super.runOnBuild,
    required super.failOnFindings,
    required super.severity,
    required this.includeDevDependencies,
    required this.ignoreUnfixed,
    required this.ignoredVulnerabilities,
  });

  factory VulnerabilityScanConfig._parse(YamlReader yaml) {
    final config = VulnerabilityScanConfig(
      enabled: yaml.boolean('enabled', fallback: true),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      severity: _severities(yaml, const [
        Severity.critical,
        Severity.high,
        Severity.medium,
        Severity.low,
      ]),
      includeDevDependencies: yaml.boolean(
        'include_dev_dependencies',
        fallback: true,
      ),
      ignoreUnfixed: yaml.boolean('ignore_unfixed', fallback: false),
      ignoredVulnerabilities: yaml.strings(
        'ignored_vulnerabilities',
        fallback: const [],
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether `dev_dependencies` are checked too.
  ///
  /// On by default: a vulnerable build tool or test helper runs on developer
  /// machines and CI runners, which is attack surface as well.
  final bool includeDevDependencies;

  /// Whether vulnerabilities without a released fix are left out.
  final bool ignoreUnfixed;

  /// Vulnerability IDs (CVE or GHSA) that are never reported.
  final List<String> ignoredVulnerabilities;
}

/// A plain `trivy fs` scan of the package directory.
class FilesystemScanConfig extends ScanConfig {
  /// Creates the filesystem scan settings.
  const FilesystemScanConfig({
    required super.enabled,
    required super.failOnFindings,
    required super.severity,
    required this.scanners,
    required this.skipDirectories,
  });

  factory FilesystemScanConfig._parse(YamlReader yaml) {
    final config = FilesystemScanConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      severity: _severities(yaml, const [
        Severity.critical,
        Severity.high,
        Severity.medium,
        Severity.low,
      ]),
      scanners: yaml.enums(
        'scanners',
        fallback: const ['vuln', 'secret', 'misconfig'],
        parse: (value) => _trivyScanners.contains(value) ? value : null,
        expected: _trivyScanners.join(', '),
      ),
      skipDirectories: yaml.strings(
        'skip_dirs',
        fallback: const ['.dart_tool', 'build', '.git'],
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  static const _trivyScanners = <String>[
    'vuln',
    'secret',
    'misconfig',
    'license',
  ];

  /// The Trivy scanners to run: `vuln`, `secret`, `misconfig` and `license`.
  ///
  /// `misconfig` is the one only this scan offers: it checks Dockerfiles,
  /// Kubernetes manifests, Terraform and CI definitions in the package.
  final List<String> scanners;

  /// Directories Trivy skips, relative to the package root.
  final List<String> skipDirectories;
}

/// Public API validation.
class ApiConfig {
  /// Creates the API validation settings.
  const ApiConfig({
    required this.enabled,
    required this.output,
    required this.ignoredLibraries,
    required this.nonPublicAnnotations,
  });

  factory ApiConfig._parse(YamlReader yaml, String packageName) {
    final config = ApiConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      output: yaml.string('output', fallback: 'api/$packageName.api'),
      ignoredLibraries: yaml.strings('ignored_libraries', fallback: const []),
      nonPublicAnnotations: yaml.strings(
        'non_public_annotations',
        fallback: const ['internal', 'visibleForTesting'],
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether the API dump is written and checked. Off by default.
  final bool enabled;

  /// The dump file, relative to the package root.
  final String output;

  /// Globs of public libraries left out of the dump, relative to the package
  /// root, for example `lib/testing.dart`.
  final List<String> ignoredLibraries;

  /// Names of annotations that keep a declaration out of the dump.
  ///
  /// Either the name of a constant (`internal`, `visibleForTesting`) or of the
  /// annotation class (`Internal`).
  final List<String> nonPublicAnnotations;
}

/// The test runner the coverage gate uses.
enum CoverageRunner {
  /// `dart test --coverage`.
  dart,

  /// `flutter test --coverage`.
  flutter,
}

/// The test coverage gate.
class CoverageConfig {
  /// Creates the coverage settings.
  const CoverageConfig({
    required this.enabled,
    required this.runner,
    required this.outputDirectory,
    required this.reportOn,
    required this.exclude,
    required this.minLineCoverage,
    required this.testArguments,
  });

  factory CoverageConfig._parse(YamlReader yaml) {
    final String runner =
        yaml.optionalString('runner') ?? CoverageRunner.dart.name;
    final config = CoverageConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runner: CoverageRunner.values.firstWhere(
        (value) => value.name == runner,
        orElse: () => throw InspectraConfigException(
          '${yaml.path.isEmpty ? '' : '${yaml.path}.'}runner',
          'expected one of '
              '${CoverageRunner.values.map((value) => value.name).join(', ')}, '
              'got "$runner".',
        ),
      ),
      outputDirectory: yaml.string('output_directory', fallback: 'coverage'),
      reportOn: yaml.strings('report_on', fallback: const ['lib']),
      exclude: yaml.strings('exclude', fallback: _generatedFiles),
      minLineCoverage: yaml.optionalNumber(
        'min_line_coverage',
        min: 0,
        max: 100,
      ),
      testArguments: yaml.strings('test_arguments', fallback: const []),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether the coverage command does anything. Off by default.
  final bool enabled;

  /// Which test runner collects the coverage.
  final CoverageRunner runner;

  /// Where the raw coverage and `lcov.info` are written.
  final String outputDirectory;

  /// Directories whose files are reported, relative to the package root.
  final List<String> reportOn;

  /// Globs of files left out of the report, relative to the package root.
  final List<String> exclude;

  /// The line coverage in percent below which the gate fails.
  ///
  /// Unset by default on purpose: measure first, then set a threshold.
  final double? minLineCoverage;

  /// Extra arguments passed to the test runner, for example
  /// `['--exclude-tags', 'slow']`.
  final List<String> testArguments;
}
