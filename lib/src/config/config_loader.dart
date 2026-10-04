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

import 'dart:io';

import 'package:path/path.dart' as p;

import '../io/environment.dart';
import '../model/inspectra_exception.dart';
import '../model/severity.dart';
import 'config_source.dart';
import 'ignore_rule.dart';
import 'inspect_config.dart';
import 'inspectra_config.dart';
import 'network_config.dart';
import 'trivy_config.dart';
import 'trivy_mode.dart';
import 'trust_thresholds.dart';
import 'typosquat_config.dart';

/// Assembles the [InspectraConfig] of a run from all configuration inputs.
///
/// The configuration file is chosen as follows: the `--config` flag, then the
/// `INSPECTRA_CONFIG` environment variable, then `inspectra.yaml` in the
/// working directory if it exists. An explicitly named file that does not
/// exist is an error; an absent default file is not.
final class ConfigLoader {
  /// Creates a loader reading variables from [environment] and resolving
  /// relative paths against [workingDirectory].
  const ConfigLoader({
    required this.environment,
    required this.workingDirectory,
  });

  /// The name of the configuration file looked up by default.
  static const String defaultFileName = 'inspectra.yaml';

  /// The environment providing `INSPECTRA_*` variables.
  final Environment environment;

  /// The directory relative paths are resolved against.
  final String workingDirectory;

  /// The severity spellings accepted in the configuration.
  static final Map<String, Severity> _severities = <String, Severity>{
    for (final severity in Severity.values) severity.name: severity,
  };

  /// The Trivy mode spellings accepted in the configuration.
  static final Map<String, TrivyMode> _trivyModes = <String, TrivyMode>{
    for (final mode in TrivyMode.values) mode.id: mode,
  };

  /// Loads the configuration.
  ///
  /// [explicitPath] is the value of `--config`, [overrides] are the command
  /// line overrides keyed by dotted path.
  ///
  /// Returns the validated configuration.
  ///
  /// Throws an [InvalidInputException] for missing explicit files, malformed
  /// YAML, unknown keys and invalid values.
  InspectraConfig load({
    required Map<String, String> overrides,
    String? explicitPath,
  }) {
    final source = _openSource(explicitPath, overrides);
    final config = InspectraConfig(
      failOn: source.choice('failOn', _severities),
      minSeverity:
          source.choice('minSeverity', _severities) ?? Severity.unknown,
      ignore: _readIgnoreRules(source),
      network: _readNetwork(source),
      inspect: _readInspect(source),
      trust: _readTrust(source),
      typosquat: _readTyposquat(source),
      trivy: _readTrivy(source),
    );
    source.ensureNoUnknownKeys();
    return config;
  }

  /// Opens the configuration file, or an empty document when there is none.
  ///
  /// Returns the layered source.
  ConfigSource _openSource(
    String? explicitPath,
    Map<String, String> overrides,
  ) {
    final named = explicitPath ?? environment['INSPECTRA_CONFIG'];
    final path = p.normalize(
      p.join(workingDirectory, named ?? defaultFileName),
    );
    final file = File(path);
    final exists = file.existsSync();
    if (named != null && !exists) {
      throw InvalidInputException(
        'The configuration file "$named" does not '
        'exist.',
      );
    }
    final content = exists ? file.readAsStringSync() : '';
    return ConfigSource.fromYaml(
      content,
      documentName: exists ? p.basename(path) : defaultFileName,
      environment: environment,
      overrides: overrides,
    );
  }

  /// Reads the `network:` section.
  ///
  /// Returns the network settings.
  NetworkConfig _readNetwork(ConfigSource source) {
    const defaults = NetworkConfig();
    final pubHostedUrl = environment['PUB_HOSTED_URL'] ?? defaults.pubHostedUrl;
    return NetworkConfig(
      offline: source.boolean('network.offline') ?? defaults.offline,
      timeout: source.duration('network.timeout') ?? defaults.timeout,
      maxAttempts:
          source.integer('network.maxAttempts', min: 1) ?? defaults.maxAttempts,
      retryBaseDelay:
          source.duration('network.retryBaseDelay') ?? defaults.retryBaseDelay,
      concurrency:
          source.integer('network.concurrency', min: 1) ?? defaults.concurrency,
      proxy: source.string('network.proxy'),
      caCertificates: _resolvePath(source.string('network.caCertificates')),
      osvUrl: _trimSlash(source.string('network.osvUrl') ?? defaults.osvUrl),
      pubHostedUrl: _trimSlash(
        source.string('network.pubHostedUrl') ?? pubHostedUrl,
      ),
    );
  }

  /// Reads the `inspect:` section.
  ///
  /// Returns the inspector settings.
  InspectConfig _readInspect(ConfigSource source) {
    const defaults = InspectConfig();
    return InspectConfig(
      failScore:
          source.integer('inspect.failScore', min: 1) ?? defaults.failScore,
      maxArchiveBytes:
          source.integer('inspect.maxArchiveBytes', min: 1) ??
          defaults.maxArchiveBytes,
      maxExtractedBytes:
          source.integer('inspect.maxExtractedBytes', min: 1) ??
          defaults.maxExtractedBytes,
      maxEntries:
          source.integer('inspect.maxEntries', min: 1) ?? defaults.maxEntries,
      entropyExcludes:
          source.stringList('inspect.entropyExcludes') ??
          defaults.entropyExcludes,
      excludeDirectories:
          source.stringList('inspect.excludeDirectories') ??
          defaults.excludeDirectories,
      trustedHosts:
          source.stringList('inspect.trustedHosts') ?? defaults.trustedHosts,
    );
  }

  /// Reads the `trust:` section.
  ///
  /// Returns the trust thresholds.
  TrustThresholds _readTrust(ConfigSource source) {
    const defaults = TrustThresholds();
    return TrustThresholds(
      freshPackageDays:
          source.integer('trust.freshPackageDays') ?? defaults.freshPackageDays,
      youngPackageDays:
          source.integer('trust.youngPackageDays') ?? defaults.youngPackageDays,
      freshReleaseHours:
          source.integer('trust.freshReleaseHours') ??
          defaults.freshReleaseHours,
      minLikes: source.integer('trust.minLikes') ?? defaults.minLikes,
      minDownloads:
          source.integer('trust.minDownloads') ?? defaults.minDownloads,
      minPointsRatio:
          source.decimal('trust.minPointsRatio') ?? defaults.minPointsRatio,
    );
  }

  /// Reads the `typosquat:` section.
  ///
  /// Returns the typosquat settings.
  TyposquatConfig _readTyposquat(ConfigSource source) {
    return TyposquatConfig(
      allow: source.stringList('typosquat.allow') ?? const <String>[],
      popular: source.stringList('typosquat.popular') ?? const <String>[],
    );
  }

  /// Reads the `trivy:` section and validates scanner names and severities.
  ///
  /// Returns the Trivy settings.
  ///
  /// Throws an [InvalidInputException] for unsupported scanners or
  /// severities.
  TrivyConfig _readTrivy(ConfigSource source) {
    const defaults = TrivyConfig();
    final scanners = source.stringList('trivy.scanners') ?? defaults.scanners;
    final unsupported = scanners.where(
      (scanner) => !TrivyConfig.supportedScanners.contains(scanner),
    );
    if (unsupported.isNotEmpty) {
      throw InvalidInputException(
        'Unsupported Trivy scanner "${unsupported.first}"; supported are '
        '${TrivyConfig.supportedScanners.join(', ')}.',
      );
    }
    final severities =
        (source.stringList('trivy.severities') ?? defaults.severities)
            .map((severity) => severity.toUpperCase())
            .toList();
    final invalid = severities.where((s) => Severity.tryParseStrict(s) == null);
    if (invalid.isNotEmpty) {
      throw InvalidInputException(
        'Unsupported Trivy severity "${invalid.first}".',
      );
    }
    return TrivyConfig(
      mode: source.choice('trivy.mode', _trivyModes) ?? defaults.mode,
      version: source.string('trivy.version') ?? defaults.version,
      useInstalled:
          source.boolean('trivy.useInstalled') ?? defaults.useInstalled,
      download: source.boolean('trivy.download') ?? defaults.download,
      executable: _resolvePath(source.string('trivy.executable')),
      installDirectory: _resolvePath(source.string('trivy.installDirectory')),
      downloadBaseUrl: _trimSlash(
        source.string('trivy.downloadBaseUrl') ?? defaults.downloadBaseUrl,
      ),
      latestReleaseUrl:
          source.string('trivy.latestReleaseUrl') ?? defaults.latestReleaseUrl,
      scanners: scanners,
      severities: severities,
      skipDbUpdate:
          source.boolean('trivy.skipDbUpdate') ?? defaults.skipDbUpdate,
      dbRepository: source.string('trivy.dbRepository'),
      cacheDirectory: _resolvePath(source.string('trivy.cacheDirectory')),
      timeout: source.duration('trivy.timeout') ?? defaults.timeout,
      connectivityTimeout:
          source.duration('trivy.connectivityTimeout') ??
          defaults.connectivityTimeout,
      extraArgs: source.stringList('trivy.extraArgs') ?? defaults.extraArgs,
    );
  }

  /// Reads the `ignore:` list, which only the configuration file can hold.
  ///
  /// Returns the parsed rules.
  ///
  /// Throws an [InvalidInputException] for malformed entries.
  List<IgnoreRule> _readIgnoreRules(ConfigSource source) {
    final raw = source.structured('ignore');
    if (raw == null) {
      return const <IgnoreRule>[];
    }
    if (raw is! List<Object?>) {
      throw const InvalidInputException(
        '"ignore" must be a list of entries with id and reason.',
      );
    }
    return <IgnoreRule>[
      for (var index = 0; index < raw.length; index++)
        _readIgnoreRule(raw[index], index),
    ];
  }

  /// Parses one entry of the `ignore:` list at position [index].
  ///
  /// Returns the rule.
  ///
  /// Throws an [InvalidInputException] for unknown keys, missing ids or
  /// reasons and malformed expiry dates.
  IgnoreRule _readIgnoreRule(Object? entry, int index) {
    final label = 'ignore[$index]';
    if (entry is! Map<String, Object?>) {
      throw InvalidInputException(
        '$label must be a mapping with id and '
        'reason.',
      );
    }
    const allowed = <String>{'id', 'reason', 'package', 'expires'};
    final unknown = entry.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw InvalidInputException('Unknown key "$label.${unknown.first}".');
    }
    final id = _nonBlank(entry['id']);
    final reason = _nonBlank(entry['reason']);
    if (id == null || reason == null) {
      throw InvalidInputException(
        '$label requires both "id" and "reason"; '
        'every suppression must be justified.',
      );
    }
    final expiresText = _nonBlank(entry['expires']);
    final expires = expiresText == null ? null : DateTime.tryParse(expiresText);
    if (expiresText != null && expires == null) {
      throw InvalidInputException(
        '$label.expires must be a date in the '
        'form YYYY-MM-DD but is "$expiresText".',
      );
    }
    return IgnoreRule(
      id: id,
      reason: reason,
      package: _nonBlank(entry['package']),
      expires: expires,
    );
  }

  /// Returns [value] as a trimmed string, or `null` when absent or blank.
  String? _nonBlank(Object? value) {
    if (value == null) {
      return null;
    }
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  /// Resolves a configured [path] against the working directory.
  ///
  /// Returns the absolute path, or `null` when [path] is `null`.
  String? _resolvePath(String? path) {
    if (path == null) {
      return null;
    }
    return p.normalize(p.join(workingDirectory, path));
  }

  /// Removes trailing slashes from [url] so paths can be appended safely.
  ///
  /// Returns the trimmed URL.
  String _trimSlash(String url) => url.replaceAll(RegExp(r'/+$'), '');
}
