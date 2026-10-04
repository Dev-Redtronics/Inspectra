/*
 * Copyright 2026 Redtronics
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

import 'trivy_mode.dart';

/// Settings of the Trivy integration, the `trivy:` section of
/// `inspectra.yaml`.
///
/// Every value can also be set through `INSPECTRA_TRIVY_<KEY>` environment
/// variables (for example `INSPECTRA_TRIVY_VERSION=0.75.0`) or
/// `--set trivy.<key>=<value>`.
final class TrivyConfig {
  /// Creates Trivy settings; every parameter has a sensible default.
  const TrivyConfig({
    this.mode = TrivyMode.auto,
    this.version = pinnedVersion,
    this.useInstalled = true,
    this.download = true,
    this.executable,
    this.installDirectory,
    this.downloadBaseUrl = defaultDownloadBaseUrl,
    this.latestReleaseUrl = defaultLatestReleaseUrl,
    this.scanners = defaultScanners,
    this.severities = defaultSeverities,
    this.skipDbUpdate = false,
    this.dbRepository,
    this.cacheDirectory,
    this.timeout = const Duration(minutes: 10),
    this.connectivityTimeout = const Duration(seconds: 3),
    this.extraArgs = const <String>[],
  });

  /// The Trivy release Inspectra downloads unless configured otherwise.
  ///
  /// Pinning a version keeps scans reproducible; Dependabot style updates of
  /// this constant are part of the regular release process.
  static const String pinnedVersion = '0.75.0';

  /// The special [version] value that resolves the newest Trivy release.
  static const String latestVersion = 'latest';

  /// Where official Trivy release assets are downloaded from.
  static const String defaultDownloadBaseUrl =
      'https://github.com/aquasecurity/trivy/releases/download';

  /// The page that redirects to the newest Trivy release.
  static const String defaultLatestReleaseUrl =
      'https://github.com/aquasecurity/trivy/releases/latest';

  /// The scanners enabled by default.
  ///
  /// License scanning is opt-in because Trivy reports every detected
  /// license, including permissive ones, as a finding.
  static const List<String> defaultScanners = <String>[
    'vuln',
    'secret',
    'misconfig',
  ];

  /// Every scanner Trivy offers for file system targets.
  static const Set<String> supportedScanners = <String>{
    'vuln',
    'secret',
    'misconfig',
    'license',
  };

  /// The severities reported by default: all of them.
  static const List<String> defaultSeverities = <String>[
    'UNKNOWN',
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
  ];

  /// Whether Trivy is used at all and how strictly.
  final TrivyMode mode;

  /// The exact Trivy version to download, or [latestVersion].
  final String version;

  /// Whether an already installed Trivy is used even when its version
  /// differs from [version].
  ///
  /// Set to `false` to enforce exactly [version]; an installed binary of a
  /// different version is then ignored and the pinned one is downloaded.
  final bool useInstalled;

  /// Whether Inspectra may download Trivy when it is not installed.
  ///
  /// A download is only attempted when the network is available; offline
  /// mode and an unreachable download host skip it.
  final bool download;

  /// An explicit Trivy executable; disables every other lookup.
  final String? executable;

  /// Where downloaded Trivy binaries are stored. Defaults to
  /// `<user cache>/inspectra/trivy/<version>`.
  final String? installDirectory;

  /// The base URL of the release assets, for example an Artifactory mirror
  /// of the GitHub releases. A mirror must provide the archives and the
  /// `trivy_<version>_checksums.txt` file under `<base>/v<version>/`.
  final String downloadBaseUrl;

  /// The URL that redirects to the newest release, used for
  /// `version: latest`.
  final String latestReleaseUrl;

  /// The Trivy scanners to run (`--scanners`).
  final List<String> scanners;

  /// The Trivy severities to report (`--severity`).
  final List<String> severities;

  /// Whether Trivy should skip updating its vulnerability database
  /// (`--skip-db-update`), for air-gapped machines with a pre-seeded cache.
  final bool skipDbUpdate;

  /// An OCI repository mirroring the Trivy database (`--db-repository`).
  final String? dbRepository;

  /// The Trivy cache directory (`--cache-dir`).
  final String? cacheDirectory;

  /// The maximum run time of one Trivy scan.
  final Duration timeout;

  /// The time allowed to check whether the download host is reachable.
  final Duration connectivityTimeout;

  /// Additional arguments appended verbatim to the Trivy command line.
  final List<String> extraArgs;
}
