/*
 * Copyright 2026 Davils
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:inspectra/src/config/config_kind.dart';
import 'package:inspectra/src/config/config_origin.dart';
import 'package:inspectra/src/config/filesystem_scan_config.dart';
import 'package:inspectra/src/config/license_scan_config.dart';
import 'package:inspectra/src/config/secret_scan_config.dart';
import 'package:inspectra/src/config/trivy_mode.dart';
import 'package:inspectra/src/config/vulnerability_scan_config.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// The Trivy integration, the `trivy:` section.
///
/// It combines two concerns:
///
/// * **which scans run**: [enabled] switches the configured secret,
///   license, vulnerability and filesystem scans of `check`, `trivy` and the
///   build_runner builders on;
/// * **how Trivy is provisioned**: Inspectra uses [executable], or an
///   installed Trivy, or a cached one, or downloads [version] when
///   [download] is allowed and the download host is reachable. [mode]
///   decides whether a missing Trivy is skipped with a warning or fails.
final class TrivyConfig {
  /// Creates Trivy settings; every parameter has a sensible default.
  const TrivyConfig({
    this.enabled = false,
    this.mode = TrivyMode.auto,
    this.version = pinnedVersion,
    this.useInstalled = true,
    this.download = true,
    this.executable,
    this.installDirectory,
    this.downloadBaseUrl = defaultDownloadBaseUrl,
    this.latestReleaseUrl = defaultLatestReleaseUrl,
    this.reportDirectory = defaultReportDirectory,
    this.skipDbUpdate = false,
    this.dbRepository,
    this.cacheDirectory,
    this.timeout = const Duration(minutes: 10),
    this.connectivityTimeout = const Duration(seconds: 3),
    this.extraArgs = const <String>[],
    this.secret = SecretScanConfig.defaults,
    this.license = LicenseScanConfig.defaults,
    this.vulnerability = VulnerabilityScanConfig.defaults,
    this.filesystem = FilesystemScanConfig.defaults,
  });

  /// Reads the settings from the `trivy:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory TrivyConfig.fromYaml(YamlReader yaml) {
    final config = TrivyConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      mode: yaml.choice('mode', <String, TrivyMode>{
        for (final mode in TrivyMode.values) mode.id: mode,
      }, fallback: TrivyMode.auto),
      version: yaml.string('version', fallback: pinnedVersion),
      useInstalled: yaml.boolean('use_installed', fallback: true),
      download: yaml.boolean('download', fallback: true),
      executable: _executable(yaml),
      installDirectory: yaml.optionalString('install_directory'),
      downloadBaseUrl: _trimSlash(
        yaml.string('download_base_url', fallback: defaultDownloadBaseUrl),
      ),
      latestReleaseUrl: yaml.string(
        'latest_release_url',
        fallback: defaultLatestReleaseUrl,
      ),
      reportDirectory: yaml.string(
        'report_directory',
        fallback: defaultReportDirectory,
      ),
      skipDbUpdate: yaml.boolean('skip_db_update', fallback: false),
      dbRepository: yaml.optionalString('db_repository'),
      cacheDirectory: yaml.optionalString('cache_directory'),
      timeout: yaml.duration('timeout', fallback: const Duration(minutes: 10)),
      connectivityTimeout: yaml.duration(
        'connectivity_timeout',
        fallback: const Duration(seconds: 3),
      ),
      extraArgs: yaml.strings('extra_args', fallback: const <String>[]),
      secret: SecretScanConfig.fromYaml(yaml.section('secret')),
      license: LicenseScanConfig.fromYaml(yaml.section('license')),
      vulnerability: VulnerabilityScanConfig.fromYaml(
        yaml.section('vulnerability'),
      ),
      filesystem: FilesystemScanConfig.fromYaml(yaml.section('filesystem')),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Reads `executable` from [yaml]: the command line wins, then
  /// [legacyExecutableVariable], then `INSPECTRA_TRIVY_EXECUTABLE`, then the
  /// file. The key is always read, so that it is a known option.
  ///
  /// Returns the executable, or `null` when none is configured.
  static String? _executable(YamlReader yaml) {
    final String? configured = yaml.optionalString('executable');
    final path = yaml.keyPath.isEmpty
        ? 'executable'
        : '${yaml.keyPath}.executable';
    final String? fromCommandLine = yaml.overrides.cli[path]?.trim();
    if (fromCommandLine != null && fromCommandLine.isNotEmpty) {
      return configured;
    }
    final String? legacy = yaml.overrides.environment[legacyExecutableVariable];
    if (legacy == null) {
      return configured;
    }
    yaml.recordValue(
      'executable',
      ConfigKind.string,
      legacy,
      origin: ConfigOrigin.environment,
      variable: legacyExecutableVariable,
    );
    return legacy;
  }

  /// The Trivy release Inspectra downloads unless configured otherwise.
  ///
  /// Pinning a version keeps scans reproducible; updating this constant is
  /// part of the regular release process.
  static const pinnedVersion = '0.75.0';

  /// The special [version] value that resolves the newest Trivy release.
  static const latestVersion = 'latest';

  /// The environment variable that names the Trivy executable, kept for
  /// compatibility; it overrides `trivy.executable` of the file and of
  /// `INSPECTRA_TRIVY_EXECUTABLE`, but not of the command line.
  static const legacyExecutableVariable = 'INSPECTRA_TRIVY';

  /// Where official Trivy release assets are downloaded from.
  static const defaultDownloadBaseUrl =
      'https://github.com/aquasecurity/trivy/releases/download';

  /// The page that redirects to the newest Trivy release.
  static const defaultLatestReleaseUrl =
      'https://github.com/aquasecurity/trivy/releases/latest';

  /// Where `check` and `trivy` write the JSON report of each scan.
  static const defaultReportDirectory = '.dart_tool/inspectra/trivy';

  /// Returns a copy whose file system paths are resolved with [resolve]:
  /// [installDirectory], [cacheDirectory] and an [executable] that contains
  /// a path separator. A bare executable name stays a `PATH` lookup.
  TrivyConfig withResolvedPaths(String Function(String path) resolve) {
    final String? command = executable;
    final bool isPath =
        command != null && (command.contains('/') || command.contains(r'\'));
    final String? install = installDirectory;
    final String? cache = cacheDirectory;
    return TrivyConfig(
      enabled: enabled,
      mode: mode,
      version: version,
      useInstalled: useInstalled,
      download: download,
      executable: isPath ? resolve(command) : command,
      installDirectory: install == null ? null : resolve(install),
      downloadBaseUrl: downloadBaseUrl,
      latestReleaseUrl: latestReleaseUrl,
      reportDirectory: reportDirectory,
      skipDbUpdate: skipDbUpdate,
      dbRepository: dbRepository,
      cacheDirectory: cache == null ? null : resolve(cache),
      timeout: timeout,
      connectivityTimeout: connectivityTimeout,
      extraArgs: extraArgs,
      secret: secret,
      license: license,
      vulnerability: vulnerability,
      filesystem: filesystem,
    );
  }

  /// Removes trailing slashes from [url] so paths can be appended safely.
  ///
  /// Returns the trimmed URL.
  static String _trimSlash(String url) => url.replaceAll(RegExp(r'/+$'), '');

  /// Whether the configured scans of `check`, `trivy` and the builders run.
  /// Off by default; the `scan` command runs Trivy regardless, unless
  /// [mode] is [TrivyMode.disabled].
  final bool enabled;

  /// How strictly Trivy must be available.
  final TrivyMode mode;

  /// The exact Trivy version to download, or [latestVersion].
  final String version;

  /// Whether an already installed Trivy is used even when its version
  /// differs from [version]. Set to `false` to enforce exactly [version].
  final bool useInstalled;

  /// Whether Inspectra may download Trivy when it is not installed. A
  /// download is only attempted when the network is available.
  final bool download;

  /// An explicit Trivy executable; disables every other lookup. The
  /// `INSPECTRA_TRIVY` environment variable overrides it.
  final String? executable;

  /// Where downloaded Trivy binaries are stored. Defaults to
  /// `<user cache>/inspectra/trivy`, one directory per version.
  final String? installDirectory;

  /// The base URL of the release assets, for example an Artifactory mirror
  /// of the GitHub releases. A mirror must provide the archives and the
  /// `trivy_<version>_checksums.txt` file under `<base>/v<version>/`.
  final String downloadBaseUrl;

  /// The URL that redirects to the newest release, used for
  /// `version: latest`.
  final String latestReleaseUrl;

  /// Where the command line writes the JSON report of each scan.
  final String reportDirectory;

  /// Whether Trivy skips updating its vulnerability database, for
  /// air-gapped machines with a pre-seeded cache.
  final bool skipDbUpdate;

  /// An OCI repository mirroring the Trivy database.
  final String? dbRepository;

  /// The Trivy cache directory.
  final String? cacheDirectory;

  /// The maximum run time of one Trivy scan.
  final Duration timeout;

  /// The time allowed to check whether the download host is reachable.
  final Duration connectivityTimeout;

  /// Additional arguments appended verbatim to the `scan` command's Trivy
  /// command line.
  final List<String> extraArgs;

  /// Scanning sources and configuration files for credentials.
  final SecretScanConfig secret;

  /// Checking the licenses of dependencies.
  final LicenseScanConfig license;

  /// Checking dependencies for known vulnerabilities.
  final VulnerabilityScanConfig vulnerability;

  /// A plain `trivy fs` scan of the whole package.
  final FilesystemScanConfig filesystem;
}
