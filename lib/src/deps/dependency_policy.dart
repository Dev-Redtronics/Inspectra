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

import 'package:inspectra/src/config/denied_package.dart';
import 'package:inspectra/src/config/dependency_policy_config.dart';
import 'package:inspectra/src/deps/import_collector.dart';
import 'package:inspectra/src/deps/package_imports.dart';
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/deps/version_bounds.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_entry.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';
import 'package:pub_semver/pub_semver.dart';

/// Checks the dependencies of a package against the `dependency_policy:`
/// section of the configuration.
///
/// The rules that need `pubspec.lock` run only for the package the
/// lockfile belongs to, so that the members of a pub workspace do not
/// report the shared lockfile once each.
final class DependencyPolicy {
  /// Creates the policy of [config]; [defaultRegistry] is where hosted
  /// dependencies without a `hosted:` URL come from, and [imports] collects
  /// the imports of a package.
  const DependencyPolicy({
    required this.config,
    required this.defaultRegistry,
    this.imports = const ImportCollector(),
  });

  /// The policy settings.
  final DependencyPolicyConfig config;

  /// The registry of hosted dependencies without a `hosted:` URL, from
  /// `network.pub_hosted_url`.
  final String defaultRegistry;

  /// Collects the imports for the import rules.
  final ImportCollector imports;

  /// The dependency sections a package declares itself.
  static const _sections = <String>['dependencies', 'dev_dependencies'];

  /// Checks the package described by [source].
  ///
  /// Returns the findings of the source [FindingSource.pubspec].
  List<Finding> check(PolicySource source) {
    final Pubspec pubspec = source.pubspec;
    final findings = <Finding>[
      ..._denied(source),
      ..._allowed(source),
      ..._hosts(source),
      ..._upperBounds(source),
      ..._sdk(source),
      ..._devOnly(source),
      ..._publishing(source),
    ];
    final Lockfile? lockfile = source.lockfile;
    if (lockfile != null && source.ownsLockfile) {
      findings
        ..addAll(_lockedPackages(source, lockfile))
        ..addAll(_lockfileSync(source, lockfile))
        ..addAll(_checksums(source, lockfile));
    }
    if (config.checkImports && pubspec.name != null) {
      findings.addAll(_imports(source, imports.collect(source.packageRoot)));
    }
    return findings;
  }

  /// Returns the declarations of [pubspec] in the section [section].
  static Map<String, DependencySpec> _section(
    Pubspec pubspec,
    String section,
  ) => section == 'dependencies'
      ? pubspec.dependencies
      : pubspec.devDependencies;

  /// Reports denied packages declared directly.
  Iterable<Finding> _denied(PolicySource source) sync* {
    for (final DeniedPackage denied in config.denied) {
      for (final section in <String>[..._sections, 'dependency_overrides']) {
        final Map<String, DependencySpec> declared =
            section == 'dependency_overrides'
            ? source.pubspec.dependencyOverrides
            : _section(source.pubspec, section);
        if (declared.containsKey(denied.name)) {
          yield _finding(
            'DENIED_PACKAGE',
            Severity.high,
            'The package ${denied.name} is denied',
            _deniedReason(denied.reason, denied.replacement),
            source.locator.entry(section, denied.name),
            package: denied.name,
          );
        }
      }
    }
  }

  /// Explains why a package is denied and what to use instead.
  ///
  /// Returns the description.
  static String _deniedReason(String reason, String? replacement) =>
      replacement == null ? reason : '$reason Use $replacement instead.';

  /// Reports hosted direct dependencies that `allowed` does not list.
  Iterable<Finding> _allowed(PolicySource source) sync* {
    if (config.allowed.isEmpty) {
      return;
    }
    for (final String section in _sections) {
      for (final MapEntry(key: name, value: spec) in _section(
        source.pubspec,
        section,
      ).entries) {
        final bool listed = config.allowed.contains(name);
        if (spec.kind == DependencyKind.hosted && !listed) {
          yield _finding(
            'PACKAGE_NOT_ALLOWED',
            Severity.high,
            'The package $name is not on the allowed list',
            'dependency_policy.allowed lists the only hosted packages this '
                'organisation approved. Ask for $name to be approved, or use '
                'an approved package.',
            source.locator.entry(section, name),
            package: name,
          );
        }
      }
    }
  }

  /// Reports direct dependencies from registries or Git hosts that are not
  /// allowed.
  Iterable<Finding> _hosts(PolicySource source) sync* {
    for (final String section in _sections) {
      for (final MapEntry(key: name, value: spec) in _section(
        source.pubspec,
        section,
      ).entries) {
        final String? registry = spec.kind == DependencyKind.hosted
            ? spec.hostedUrl ?? defaultRegistry
            : null;
        final String? gitUrl = spec.kind == DependencyKind.git
            ? spec.gitUrl
            : null;
        final SourceLocation location = source.locator.entry(section, name);
        if (registry != null && !_registryAllowed(registry)) {
          yield _hostFinding(name, registry, location);
        }
        if (gitUrl != null && !_gitHostAllowed(gitUrl)) {
          yield _gitFinding(name, gitUrl, location);
        }
      }
    }
  }

  /// Returns the finding of [name] from the registry [registry] at
  /// [location].
  Finding _hostFinding(String name, String registry, SourceLocation location) =>
      _finding(
        'DISALLOWED_HOST',
        Severity.high,
        '$name comes from the registry $registry, which is not allowed',
        'dependency_policy.allowed_hosts lists the registries packages may '
            'come from: ${config.allowedHosts.join(', ')}.',
        location,
        package: name,
      );

  /// Returns the finding of [name] from the Git repository [url] at
  /// [location].
  Finding _gitFinding(String name, String url, SourceLocation location) =>
      _finding(
        'DISALLOWED_HOST',
        Severity.high,
        '$name comes from the Git host ${gitHost(url)}, which is not allowed',
        'dependency_policy.allowed_git_hosts lists the hosts Git '
            'dependencies may come from: '
            '${config.allowedGitHosts.join(', ')}.',
        location,
        package: name,
      );

  /// Returns whether packages may come from [registry].
  bool _registryAllowed(String registry) {
    if (config.allowedHosts.isEmpty) {
      return true;
    }
    final String normalised = registry.replaceAll(RegExp(r'/+$'), '');
    final bool isPublic = Lockfile.publicRegistries.contains(normalised);
    return config.allowedHosts.any(
      (allowed) =>
          allowed == normalised ||
          isPublic && Lockfile.publicRegistries.contains(allowed),
    );
  }

  /// Returns whether Git dependencies may come from the repository [url].
  bool _gitHostAllowed(String url) =>
      config.allowedGitHosts.isEmpty ||
      config.allowedGitHosts.contains(gitHost(url));

  /// Returns the host of the Git repository [url], which is a URL or an
  /// scp-like `git@host:org/repo` address.
  static String gitHost(String url) {
    final RegExpMatch? scp = RegExp('^[^/@:]+@([^:/]+):').firstMatch(url);
    if (scp != null) {
      return scp.group(1) ?? url;
    }
    final Uri? parsed = Uri.tryParse(url);
    final String? host = parsed?.host;
    return host == null || host.isEmpty ? url : host;
  }

  /// Reports hosted constraints without an upper bound.
  Iterable<Finding> _upperBounds(PolicySource source) sync* {
    if (!config.requireUpperBound) {
      return;
    }
    for (final String section in _sections) {
      for (final MapEntry(key: name, value: spec) in _section(
        source.pubspec,
        section,
      ).entries) {
        final String? bounded = spec.kind == DependencyKind.hosted
            ? boundedConstraint(spec.constraint)
            : null;
        if (bounded != null) {
          yield _finding(
            'MISSING_UPPER_BOUND',
            Severity.medium,
            '$name allows every future version (${spec.constraint})',
            'Without an upper bound, the next breaking release is picked up '
                'by the next "dart pub upgrade". Use "$bounded"; '
                '"inspectra deps --fix" applies it.',
            source.locator.entry(section, name),
            package: name,
            fix: bounded,
          );
        }
      }
    }
  }

  /// Reports SDK constraints that allow SDKs below the minimum.
  Iterable<Finding> _sdk(PolicySource source) sync* {
    final Pubspec pubspec = source.pubspec;
    final checks = <(String, String, Version?, String?, bool)>[
      ('sdk', 'Dart', config.minSdk, pubspec.sdkConstraint, true),
      (
        'flutter',
        'Flutter',
        config.minFlutter,
        pubspec.flutterConstraint,
        pubspec.isFlutterProject,
      ),
    ];
    for (final (key, sdk, minimum, constraint, applies) in checks) {
      if (minimum == null || !applies) {
        continue;
      }
      final Version? lower = lowerBound(constraint);
      if (lower == null || lower < minimum) {
        yield _finding(
          'SDK_BELOW_POLICY',
          Severity.medium,
          'The $sdk SDK constraint allows versions below $minimum',
          'dependency_policy.min_${key == 'sdk' ? 'sdk' : 'flutter'} is '
              '$minimum; environment.$key is '
              '${constraint ?? 'not set'}. Raise its lower bound to $minimum.',
          source.locator.entry('environment', key),
        );
      }
    }
  }

  /// Reports packages for development that are runtime dependencies.
  Iterable<Finding> _devOnly(PolicySource source) sync* {
    for (final String name in config.devOnly) {
      if (source.pubspec.dependencies.containsKey(name)) {
        yield _finding(
          'DEV_ONLY_DEPENDENCY',
          Severity.medium,
          '$name belongs in dev_dependencies',
          'Every user of this package downloads and resolves its runtime '
              'dependencies; $name is only needed for development. '
              '"inspectra deps --fix" moves it.',
          source.locator.entry('dependencies', name),
          package: name,
          fix: 'dev_dependencies',
        );
      }
    }
  }

  /// Reports missing `publish_to` and missing metadata.
  Iterable<Finding> _publishing(PolicySource source) sync* {
    final Pubspec pubspec = source.pubspec;
    final String? name = pubspec.name;
    if (name == null) {
      return;
    }
    final bool published = config.publishedPackages.contains(name);
    if (config.requirePublishTo && pubspec.publishTo == null && !published) {
      yield _finding(
        'MISSING_PUBLISH_TO',
        Severity.medium,
        'The package $name can be published to pub.dev by accident',
        'Without publish_to, "dart pub publish" uploads the package to '
            'pub.dev. Add "publish_to: none", or name your registry; '
            '"inspectra deps --fix" adds "publish_to: none". List packages '
            'meant for pub.dev in dependency_policy.published_packages.',
        source.locator.topLevel('name'),
        package: name,
        fix: 'none',
      );
    }
    if (!pubspec.isPublishable) {
      return;
    }
    for (final String field in config.requiredMetadata) {
      if (!_declares(pubspec, field)) {
        yield _finding(
          'MISSING_METADATA',
          Severity.low,
          'The publishable package $name declares no $field',
          'dependency_policy.required_metadata requires $field in every '
              'package that can be published.',
          source.locator.topLevel('name'),
          package: name,
        );
      }
    }
  }

  /// Returns whether [pubspec] declares the metadata [field].
  static bool _declares(Pubspec pubspec, String field) => switch (field) {
    'description' => pubspec.description != null,
    'repository' => pubspec.repository != null,
    'homepage' => pubspec.homepage != null,
    'issue_tracker' => pubspec.issueTracker != null,
    'documentation' => pubspec.documentation != null,
    'topics' => pubspec.topics.isNotEmpty,
    String() => true,
  };

  /// Reports denied packages and disallowed hosts among every package of
  /// [lockfile], which includes the transitive ones.
  Iterable<Finding> _lockedPackages(
    PolicySource source,
    Lockfile lockfile,
  ) sync* {
    for (final LockfileEntry entry in lockfile.packages) {
      final SourceLocation location = source.lockLocator.entry(
        'packages',
        entry.name,
      );
      final bool direct = _declaredDirectly(source.pubspec, entry.name);
      for (final DeniedPackage denied in config.denied) {
        if (denied.name == entry.name && !direct) {
          yield _finding(
            'DENIED_PACKAGE',
            Severity.high,
            'The denied package ${entry.name} ${entry.version} is a '
                'transitive dependency',
            '${_deniedReason(denied.reason, denied.replacement)} Find the '
                'dependency that pulls it in with "dart pub deps".',
            location,
            package: entry.name,
          );
        }
      }
      final String? registry = entry.isHosted ? entry.hostedUrl : null;
      if (!direct && registry != null && !_registryAllowed(registry)) {
        yield _hostFinding(entry.name, registry, location);
      }
      final String? gitUrl = entry.gitUrl;
      if (!direct && gitUrl != null && !_gitHostAllowed(gitUrl)) {
        yield _gitFinding(entry.name, gitUrl, location);
      }
    }
  }

  /// Returns whether [pubspec] declares [name] in a dependency section.
  static bool _declaredDirectly(Pubspec pubspec, String name) =>
      pubspec.dependencies.containsKey(name) ||
      pubspec.devDependencies.containsKey(name) ||
      pubspec.dependencyOverrides.containsKey(name);

  /// Reports a [lockfile] that does not match the direct dependencies.
  Iterable<Finding> _lockfileSync(
    PolicySource source,
    Lockfile lockfile,
  ) sync* {
    if (!config.lockfileInSync) {
      return;
    }
    final Pubspec pubspec = source.pubspec;
    final locked = <String, LockfileEntry>{
      for (final LockfileEntry entry in lockfile.packages) entry.name: entry,
    };
    for (final String section in _sections) {
      for (final MapEntry(key: name, value: spec) in _section(
        pubspec,
        section,
      ).entries) {
        final LockfileEntry? entry = locked[name];
        final SourceLocation location = source.locator.entry(section, name);
        if (entry == null) {
          yield _syncFinding(
            name,
            '$name is declared but missing from pubspec.lock',
            location,
          );
          continue;
        }
        final VersionConstraint? constraint = spec.kind == DependencyKind.hosted
            ? parseConstraint(spec.constraint)
            : null;
        final Version? version = _version(entry.version);
        final bool overridden = pubspec.dependencyOverrides.containsKey(name);
        final bool outside =
            constraint != null &&
            version != null &&
            !overridden &&
            !constraint.allows(version);
        if (outside) {
          yield _syncFinding(
            name,
            'pubspec.lock pins $name ${entry.version}, which '
            '${spec.constraint} does not allow',
            location,
          );
        }
      }
    }
    if (pubspec.workspace.isNotEmpty) {
      return;
    }
    for (final LockfileEntry entry in lockfile.packages) {
      final bool stale =
          entry.isDirect &&
          entry.dependency != 'direct overridden' &&
          !_declaredDirectly(pubspec, entry.name);
      if (stale) {
        yield _syncFinding(
          entry.name,
          'pubspec.lock lists ${entry.name} as a direct dependency, but '
          'pubspec.yaml no longer declares it',
          source.lockLocator.entry('packages', entry.name),
        );
      }
    }
  }

  /// Returns the finding that [name] is out of sync, explained by [title],
  /// at [location].
  Finding _syncFinding(String name, String title, SourceLocation location) =>
      _finding(
        'LOCKFILE_OUT_OF_SYNC',
        Severity.high,
        title,
        'pubspec.lock no longer matches pubspec.yaml, so what was tested is '
            'not what is declared. Run "dart pub get" and commit both '
            'files.',
        location,
        package: name,
      );

  /// Parses the locked [version].
  ///
  /// Returns the version, or `null` when it is malformed.
  static Version? _version(String version) {
    try {
      return Version.parse(version);
    } on FormatException {
      return null;
    }
  }

  /// Reports hosted packages of [lockfile] without a checksum.
  Iterable<Finding> _checksums(PolicySource source, Lockfile lockfile) sync* {
    if (!config.lockfileChecksums) {
      return;
    }
    for (final LockfileEntry entry in lockfile.packages) {
      if (entry.isHosted && entry.sha256 == null) {
        yield _finding(
          'MISSING_CHECKSUM',
          Severity.medium,
          'pubspec.lock records no checksum for ${entry.name} '
              '${entry.version}',
          'With a sha256 per package, "dart pub get --enforce-lockfile" '
              'rejects an archive that changed after it was locked. A recent '
              'Dart SDK records it on the next "dart pub get".',
          source.lockLocator.entry('packages', entry.name),
          package: entry.name,
        );
      }
    }
  }

  /// Reports unused runtime dependencies and development dependencies that
  /// runtime code imports, judged by [used].
  Iterable<Finding> _imports(PolicySource source, PackageImports used) sync* {
    final Pubspec pubspec = source.pubspec;
    for (final MapEntry(key: name, value: spec)
        in pubspec.dependencies.entries) {
      final bool skipped =
          spec.kind == DependencyKind.sdk ||
          config.unusedAllow.contains(name) ||
          used.runtime.contains(name);
      if (skipped) {
        continue;
      }
      final hint = used.development.contains(name)
          ? ' Only tests or tools import it; move it to dev_dependencies.'
          : ' Remove it, or list it in dependency_policy.unused_allow when it '
                'is used without an import, such as a font or a plugin.';
      yield _finding(
        'UNUSED_DEPENDENCY',
        Severity.low,
        'No file in lib/ or bin/ imports $name',
        'Every user of this package resolves its runtime dependencies.$hint',
        source.locator.entry('dependencies', name),
        package: name,
      );
    }
    for (final String name in pubspec.devDependencies.keys) {
      final bool runtime =
          used.runtime.contains(name) &&
          !pubspec.dependencies.containsKey(name);
      if (runtime) {
        yield _finding(
          'DEV_DEPENDENCY_IN_LIB',
          Severity.high,
          'lib/ or bin/ imports the development dependency $name',
          'Users of this package do not get its development dependencies, '
              'so the import fails for them. Move $name to dependencies.',
          source.locator.entry('dev_dependencies', name),
          package: name,
        );
      }
    }
  }

  /// Builds a finding of [ruleId]; [fix] is what `deps --fix` would apply.
  ///
  /// Returns the finding of the source [FindingSource.pubspec].
  static Finding _finding(
    String ruleId,
    Severity severity,
    String title,
    String description,
    SourceLocation location, {
    String? package,
    String? fix,
  }) => Finding(
    ruleId: ruleId,
    source: FindingSource.pubspec,
    severity: severity,
    title: SnippetSanitizer.sanitize(title),
    description: SnippetSanitizer.escape(description),
    location: location,
    packageName: package,
    attributes: <String, Object?>{'policy': true, 'fix': ?fix},
  );
}
