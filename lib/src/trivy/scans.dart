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

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/package_graph.dart';
import 'package:inspectra/src/trivy/trivy.dart';
import 'package:path/path.dart' as p;

/// The secret configuration Trivy picks up by default.
const defaultSecretConfig = 'trivy-secret.yaml';

/// The file names a package's license is read from.
final _licenseFileName = RegExp(
  r'^(LICEN[CS]E|COPYING|UNLICENSE)([.-].*)?$',
  caseSensitive: false,
);

/// Scans [files] - file contents by path relative to the package root - for
/// secrets.
///
/// The files are copied into a temporary directory first, so that Trivy sees
/// exactly the configured selection under the paths it is reported by, in one
/// invocation. [secretConfig] is an absolute path to a Trivy secret
/// configuration, or `null` for Trivy's built-in rules.
Future<ScanResult> scanSecrets({
  required Trivy trivy,
  required SecretScanConfig config,
  required Map<String, List<int>> files,
  String? secretConfig,
}) async {
  const scan = 'secret';
  if (files.isEmpty) {
    return ScanResult.skipped(
      scan: scan,
      reason: 'no files match the configured globs.',
    );
  }

  return _withStagingDirectory((staging) async {
    for (final MapEntry(key: path, value: bytes) in files.entries) {
      final target = File(p.join(staging, path));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes);
    }
    final TrivyReport report = await trivy.scanFilesystem(
      target: staging,
      scanners: const ['secret'],
      severity: config.severity,
      arguments: [
        if (secretConfig != null) ...['--secret-config', secretConfig],
      ],
    );
    return ScanResult(
      scan: scan,
      failOnFindings: config.failOnFindings,
      findings: [
        for (final result in report.results)
          for (final secret in result.secrets)
            _secretFinding(secret, p.posix.normalize(result.target)),
      ],
    );
  });
}

/// Checks the licenses of the dependencies in [graph].
///
/// Pub lock files carry no license information, so the license files of the
/// resolved packages are handed to Trivy's license classifier instead. Only
/// packages fetched from pub.dev or git are checked: path and SDK packages
/// are part of your own repository or of the toolchain. A package whose
/// license Trivy cannot classify is reported as [Severity.unknown].
Future<ScanResult> scanLicenses({
  required Trivy trivy,
  required LicenseScanConfig config,
  required PackageGraph graph,
}) async {
  const scan = 'license';
  final Set<String> ignoredPackages = config.ignoredPackages.toSet();
  final Set<String> ignoredLicenses = config.ignoredLicenses
      .map((license) => license.toLowerCase())
      .toSet();
  final List<LockedPackage> packages = [
    for (final name in graph.reachable(
      includeDev: config.includeDevDependencies,
    ))
      if (graph.lock.packages[name] case final package?
          when package.isExternal && !ignoredPackages.contains(name))
        package,
  ]..sort((a, b) => a.name.compareTo(b.name));
  if (packages.isEmpty) {
    return ScanResult.skipped(
      scan: scan,
      reason: 'no third-party dependencies to check.',
    );
  }

  return _withStagingDirectory((staging) async {
    final findings = <ScanFinding>[];
    final staged = <String, LockedPackage>{};
    for (final package in packages) {
      final String? directory = graph.directoryOf(package.name);
      final bool resolved =
          directory != null && Directory(directory).existsSync();
      final List<File> licenseFiles = !resolved
          ? const <File>[]
          : Directory(directory)
                .listSync()
                .whereType<File>()
                .where(
                  (file) => _licenseFileName.hasMatch(p.basename(file.path)),
                )
                .toList();
      final label = '${package.name} ${package.version}';
      if (licenseFiles.isEmpty) {
        findings.add(
          ScanFinding(
            severity: Severity.unknown,
            target: label,
            id: 'no-license-file',
            title: !resolved
                ? 'package is not resolved locally; run "dart pub get"'
                : 'package ships no license file',
          ),
        );
        continue;
      }
      staged[package.name] = package;
      final Directory target = await Directory(p.join(staging, package.name))
          .create();
      for (final file in licenseFiles) {
        await file.copy(p.join(target.path, p.basename(file.path)));
      }
    }

    final classified = <String>{};
    if (staged.isNotEmpty) {
      final TrivyReport report = await trivy.scanFilesystem(
        target: staging,
        scanners: const ['license'],
        severity: Severity.values,
        arguments: const ['--license-full'],
      );
      for (final TrivyResult result in report.results) {
        for (final Map<String, Object?> license in result.licenses) {
          final String packageName = p
              .split(trivyString(license, 'FilePath'))
              .first;
          final LockedPackage? package = staged[packageName];
          if (package == null) {
            continue;
          }
          classified.add(packageName);
          final String name = trivyString(license, 'Name');
          if (ignoredLicenses.contains(name.toLowerCase())) {
            continue;
          }
          findings.add(
            ScanFinding(
              severity: trivySeverity(license),
              target: '${package.name} ${package.version}',
              id: name,
              title: 'license category "${trivyString(license, 'Category')}"',
            ),
          );
        }
      }
    }
    for (final LockedPackage package in staged.values) {
      if (classified.contains(package.name)) {
        continue;
      }
      findings.add(
        ScanFinding(
          severity: Severity.unknown,
          target: '${package.name} ${package.version}',
          id: 'unclassified',
          title: 'Trivy could not classify the license file',
        ),
      );
    }

    final Set<Severity> reported = config.severity.toSet();
    return ScanResult(
      scan: scan,
      failOnFindings: config.failOnFindings,
      findings: findings
          .where((finding) => reported.contains(finding.severity))
          .toList(),
    );
  });
}

/// Checks the dependencies locked in [graph] for known vulnerabilities.
///
/// [lockContent] is the `pubspec.lock` to scan; it is narrowed to the
/// packages the root actually depends on unless `dev_dependencies` are
/// included, in which case it is scanned as is and [graph] may be `null`.
Future<ScanResult> scanVulnerabilities({
  required Trivy trivy,
  required VulnerabilityScanConfig config,
  required String lockContent,
  PackageGraph? graph,
}) {
  const scan = 'vulnerability';
  final String scanned = _scannedLock(config, lockContent, graph);

  return _withStagingDirectory((staging) async {
    await File(p.join(staging, 'pubspec.lock')).writeAsString(scanned);
    final TrivyReport report = await trivy.scanFilesystem(
      target: staging,
      scanners: const ['vuln'],
      severity: config.severity,
      arguments: [if (config.ignoreUnfixed) '--ignore-unfixed'],
    );
    final Set<String> ignored = config.ignoredVulnerabilities
        .map((id) => id.toUpperCase())
        .toSet();
    return ScanResult(
      scan: scan,
      failOnFindings: config.failOnFindings,
      findings: [
        for (final result in report.results)
          for (final vulnerability in result.vulnerabilities)
            if (!_vulnerabilityIds(vulnerability).any(ignored.contains))
              _vulnerabilityFinding(vulnerability),
      ],
    );
  });
}

/// Runs a plain `trivy fs` over [packageRoot] with the configured scanners.
Future<ScanResult> scanFilesystem({
  required Trivy trivy,
  required FilesystemScanConfig config,
  required String packageRoot,
  String? secretConfig,
}) async {
  final TrivyReport report = await trivy.scanFilesystem(
    target: packageRoot,
    scanners: config.scanners,
    severity: config.severity,
    arguments: [
      for (final directory in config.skipDirectories) ...[
        '--skip-dirs',
        directory,
      ],
      if (secretConfig != null && config.scanners.contains('secret')) ...[
        '--secret-config',
        secretConfig,
      ],
      if (config.scanners.contains('license')) '--license-full',
    ],
  );
  return ScanResult(
    scan: 'filesystem',
    failOnFindings: config.failOnFindings,
    findings: [
      for (final result in report.results) ...[
        for (final vulnerability in result.vulnerabilities)
          _vulnerabilityFinding(vulnerability, file: result.target),
        for (final secret in result.secrets)
          _secretFinding(secret, result.target),
        for (final misconfiguration in result.misconfigurations)
          if (trivyString(misconfiguration, 'Status') != 'PASS')
            ScanFinding(
              severity: trivySeverity(misconfiguration),
              target: result.target,
              id: trivyString(misconfiguration, 'ID'),
              title: trivyString(misconfiguration, 'Title'),
              detail: trivyString(misconfiguration, 'Message'),
            ),
        for (final license in result.licenses)
          ScanFinding(
            severity: trivySeverity(license),
            target:
                [
                  trivyString(license, 'PkgName'),
                  trivyString(license, 'FilePath'),
                ].firstWhere(
                  (value) => value.isNotEmpty,
                  orElse: () => result.target,
                ),
            id: trivyString(license, 'Name'),
            title: 'license category "${trivyString(license, 'Category')}"',
          ),
      ],
    ],
  );
}

/// Converts a Trivy [secret] found in [file] into a finding.
ScanFinding _secretFinding(Map<String, Object?> secret, String file) =>
    ScanFinding(
      severity: trivySeverity(secret),
      target: file,
      id: trivyString(secret, 'RuleID'),
      title: trivyString(secret, 'Title'),
      detail: 'line ${trivyString(secret, 'StartLine')}',
    );

/// Converts a Trivy [vulnerability] into a finding, prefixing the target
/// with the lock [file] it was found in, when given.
ScanFinding _vulnerabilityFinding(
  Map<String, Object?> vulnerability, {
  String? file,
}) {
  final String fixed = trivyString(vulnerability, 'FixedVersion');
  final String url = trivyString(vulnerability, 'PrimaryURL');
  return ScanFinding(
    severity: trivySeverity(vulnerability),
    target: [
      if (file != null) '$file:',
      trivyString(vulnerability, 'PkgName'),
      trivyString(vulnerability, 'InstalledVersion'),
    ].join(' ').trim(),
    id: trivyString(vulnerability, 'VulnerabilityID'),
    title: trivyString(vulnerability, 'Title'),
    detail: [
      if (fixed.isEmpty) 'no fix released',
      if (fixed.isNotEmpty) 'fixed in $fixed',
      if (url.isNotEmpty) url,
    ].join(', '),
  );
}

/// The lock file the vulnerability scan reads: [lockContent] as is, or,
/// without `include_dev_dependencies`, narrowed by [graph] to what the
/// regular dependencies pull in.
///
/// Returns the lock file content.
///
/// Throws an [ArgumentError] when the lock must be narrowed without a
/// [graph].
String _scannedLock(
  VulnerabilityScanConfig config,
  String lockContent,
  PackageGraph? graph,
) {
  if (config.includeDevDependencies) {
    return lockContent;
  }
  if (graph == null) {
    throw ArgumentError.notNull('graph');
  }
  return graph.lock.retain(graph.reachable(includeDev: false));
}

/// Every ID of [vulnerability], upper-cased: its own ID followed by its
/// vendor IDs, so that an ignore rule may name either.
Iterable<String> _vulnerabilityIds(Map<String, Object?> vulnerability) sync* {
  yield trivyString(vulnerability, 'VulnerabilityID').toUpperCase();
  final Object? vendorIds = vulnerability['VendorIDs'];
  if (vendorIds is List) {
    for (final Object? id in vendorIds) {
      yield '$id'.toUpperCase();
    }
  }
}

/// Runs [body] with a fresh temporary directory and deletes the directory
/// afterwards, whether [body] completes or throws.
Future<T> _withStagingDirectory<T>(Future<T> Function(String path) body) async {
  final Directory staging = await Directory.systemTemp.createTemp(
    'inspectra_scan',
  );
  try {
    return await body(staging.path);
  } finally {
    await staging.delete(recursive: true);
  }
}
