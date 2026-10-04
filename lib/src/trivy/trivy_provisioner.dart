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

import '../config/trivy_config.dart';
import '../config/trivy_mode.dart';
import '../host/host_platform.dart';
import '../model/inspectra_exception.dart';
import '../net/http_transport.dart';
import 'trivy_installer.dart';
import 'trivy_locator.dart';
import 'trivy_origin.dart';
import 'trivy_provision.dart';
import 'trivy_release_asset.dart';

/// Decides which Trivy executable a scan uses, downloading one if needed.
///
/// Resolution order:
///
/// 1. `trivy.mode: disabled` → unavailable;
/// 2. `trivy.executable` → that executable, nothing else;
/// 3. with `useInstalled: true`, an installed Trivy on the `PATH` or in a
///    well-known directory, whatever its version;
/// 4. the configured version in Inspectra's cache;
/// 5. with `useInstalled: false`, an installed Trivy of exactly the
///    configured version;
/// 6. a download of the configured version — only when `download: true`,
///    not in offline mode, the download host is reachable and Trivy
///    publishes a build for this platform.
///
/// `version: latest` is resolved through the release redirect when online
/// and falls back to the newest cached version when offline.
final class TrivyProvisioner {
  /// Creates a provisioner.
  const TrivyProvisioner({
    required this.config,
    required this.locator,
    required this.installer,
    required this.transport,
    required this.host,
  });

  /// The Trivy configuration.
  final TrivyConfig config;

  /// Finds existing executables.
  final TrivyLocator locator;

  /// Downloads new executables.
  final TrivyInstaller installer;

  /// The HTTP transport, used for the connectivity probe.
  final HttpTransport transport;

  /// The host platform.
  final HostPlatform host;

  /// Makes Trivy available; [onStatus] receives progress messages.
  ///
  /// Returns the provision outcome; failures to download are reported as
  /// [TrivyUnavailable] so that the caller can apply the configured mode.
  Future<TrivyProvision> provision({
    required void Function(String message) onStatus,
  }) async {
    if (config.mode == TrivyMode.disabled) {
      return const TrivyUnavailable('Trivy is disabled (trivy.mode).');
    }
    final executable = config.executable;
    if (executable != null) {
      final configured = await locator.configured(executable);
      return configured ??
          TrivyUnavailable(
            'The configured Trivy executable "$executable" '
            '(trivy.executable) cannot be run.',
          );
    }
    if (config.useInstalled) {
      final installed = await locator.installed();
      if (installed != null) {
        return installed;
      }
    }
    final online = await _isOnline();
    final version = await _desiredVersion(online);
    if (version == null) {
      return const TrivyUnavailable(
        'Trivy is not installed and the latest '
        'version cannot be resolved without an internet connection.',
      );
    }
    final cached = await locator.cached(version);
    if (cached != null) {
      return cached;
    }
    final exactInstalled = await _installedOfVersion(version);
    if (exactInstalled != null) {
      return exactInstalled;
    }
    return _download(version, online: online, onStatus: onStatus);
  }

  /// Checks whether the download host can be reached.
  ///
  /// Returns `false` in offline mode, when downloads are disabled or when
  /// the host does not answer within the connectivity timeout.
  Future<bool> _isOnline() async {
    if (!config.download || transport.isOffline) {
      return false;
    }
    final uri = Uri.parse(config.downloadBaseUrl);
    final root = uri.replace(path: '/', query: '');
    return transport.probe(root, config.connectivityTimeout);
  }

  /// Resolves the version to use.
  ///
  /// Returns the exact version, or `null` when `latest` cannot be resolved.
  Future<String?> _desiredVersion(bool online) async {
    if (config.version != TrivyConfig.latestVersion) {
      return TrivyReleaseAsset.normaliseVersion(config.version);
    }
    if (!online) {
      return locator.newestCachedVersion();
    }
    try {
      return await installer.resolveLatest(config.latestReleaseUrl);
    } on UnavailableException {
      return locator.newestCachedVersion();
    }
  }

  /// Finds an installed Trivy of exactly [version], used when installed
  /// executables of other versions are not accepted.
  ///
  /// Returns the executable, or `null`.
  Future<TrivyAvailable?> _installedOfVersion(String version) async {
    if (config.useInstalled) {
      return null;
    }
    final installed = await locator.installed();
    if (installed == null || installed.version != version) {
      return null;
    }
    return installed;
  }

  /// Downloads [version] when allowed and possible.
  ///
  /// Returns the downloaded executable or the reason why it is unavailable.
  Future<TrivyProvision> _download(
    String version, {
    required bool online,
    required void Function(String message) onStatus,
  }) async {
    if (!config.download) {
      return const TrivyUnavailable(
        'Trivy is not installed and downloading '
        'is disabled (trivy.download: false).',
      );
    }
    if (transport.isOffline) {
      return const TrivyUnavailable(
        'Trivy is not installed and cannot be '
        'downloaded in offline mode.',
      );
    }
    if (!online) {
      return TrivyUnavailable(
        'Trivy is not installed and '
        '${Uri.parse(config.downloadBaseUrl).host} is not reachable, so it '
        'was not downloaded.',
      );
    }
    final asset = TrivyReleaseAsset.forHost(host, version);
    if (asset == null) {
      return TrivyUnavailable(
        'Trivy publishes no build for $host; install '
        'it manually and set trivy.executable.',
      );
    }
    onStatus('Downloading Trivy $version (${asset.archiveName})...');
    try {
      final path = await installer.install(
        asset,
        config.downloadBaseUrl,
        locator.cachedPath(version),
      );
      return TrivyAvailable(
        executable: path,
        version: version,
        origin: TrivyOrigin.downloaded,
      );
    } on UnavailableException catch (error) {
      return TrivyUnavailable(error.message);
    } on InvalidInputException catch (error) {
      return TrivyUnavailable(error.message);
    }
  }
}
