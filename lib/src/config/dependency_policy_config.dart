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

import 'package:inspectra/src/config/allowed_override.dart';
import 'package:inspectra/src/config/constraint_style.dart';
import 'package:inspectra/src/config/denied_package.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/libyear_scope.dart';
import 'package:inspectra/src/config/lockfile_policy.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:pub_semver/pub_semver.dart';

/// The rules for the dependencies of a package, the `dependency_policy:`
/// section of `inspectra.yaml`.
///
/// Every rule is off until configured, and nothing is checked unless
/// [enabled] is set; `scan`, `deps` and `check` then apply the policy.
final class DependencyPolicyConfig {
  /// Creates dependency policy settings.
  const DependencyPolicyConfig({
    this.enabled = false,
    this.denied = const <DeniedPackage>[],
    this.allowed = const <String>[],
    this.allowedHosts = const <String>[],
    this.allowedGitHosts = const <String>[],
    this.requireUpperBound = false,
    this.minSdk,
    this.minFlutter,
    this.devOnly = const <String>[],
    this.requirePublishTo = false,
    this.publishedPackages = const <String>[],
    this.requiredMetadata = const <String>[],
    this.lockfileInSync = false,
    this.lockfileChecksums = false,
    this.checkImports = false,
    this.unusedAllow = defaultUnusedAllow,
    this.constraintStyle = ConstraintStyle.any,
    this.overridesRequireReason = false,
    this.allowedOverrides = const <AllowedOverride>[],
    this.lockfilePolicy = LockfilePolicy.any,
    this.maxMajorBehind,
    this.maxLibyear,
    this.libyearScope = LibyearScope.direct,
  });

  /// Reads the settings from the `dependency_policy:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an [InspectraConfigException] for unknown keys or invalid
  /// values, such as a minimum SDK that is no version.
  factory DependencyPolicyConfig.fromYaml(YamlReader yaml) {
    final YamlReader overrides = yaml.section('overrides');
    final config = DependencyPolicyConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      denied: DeniedPackage.listFromYaml(yaml),
      allowed: yaml.strings('allowed', fallback: const <String>[]),
      allowedHosts: yaml
          .strings('allowed_hosts', fallback: const <String>[])
          .map(_trimSlash)
          .toList(),
      allowedGitHosts: yaml.strings(
        'allowed_git_hosts',
        fallback: const <String>[],
      ),
      requireUpperBound: yaml.boolean('require_upper_bound', fallback: false),
      minSdk: _version(yaml, 'min_sdk'),
      minFlutter: _version(yaml, 'min_flutter'),
      devOnly: yaml.strings('dev_only', fallback: const <String>[]),
      requirePublishTo: yaml.boolean('require_publish_to', fallback: false),
      publishedPackages: yaml.strings(
        'published_packages',
        fallback: const <String>[],
      ),
      requiredMetadata: yaml.enums(
        'required_metadata',
        fallback: const <String>[],
        parse: (value) {
          final String field = value.toLowerCase();
          return metadataFields.contains(field) ? field : null;
        },
        options: metadataFields,
        name: (field) => field,
        allowEmpty: true,
      ),
      lockfileInSync: yaml.boolean('lockfile_in_sync', fallback: false),
      lockfileChecksums: yaml.boolean('lockfile_checksums', fallback: false),
      checkImports: yaml.boolean('check_imports', fallback: false),
      unusedAllow: yaml.strings('unused_allow', fallback: defaultUnusedAllow),
      constraintStyle:
          yaml.choice<ConstraintStyle?>(
            'constraint_style',
            <String, ConstraintStyle?>{
              for (final style in ConstraintStyle.values) style.id: style,
            },
            fallback: ConstraintStyle.any,
          ) ??
          ConstraintStyle.any,
      overridesRequireReason: overrides.boolean(
        'require_reason',
        fallback: false,
      ),
      allowedOverrides: AllowedOverride.listFromYaml(overrides),
      lockfilePolicy:
          yaml.choice<LockfilePolicy?>(
            'lockfile_policy',
            <String, LockfilePolicy?>{
              for (final policy in LockfilePolicy.values) policy.id: policy,
            },
            fallback: LockfilePolicy.any,
          ) ??
          LockfilePolicy.any,
      maxMajorBehind: yaml.optionalInt('max_major_behind', min: 0, max: 100),
      maxLibyear: yaml.optionalNumber('max_libyear', min: 0, max: 1000),
      libyearScope:
          yaml.choice<LibyearScope?>('libyear_scope', <String, LibyearScope?>{
            for (final scope in LibyearScope.values) scope.id: scope,
          }, fallback: LibyearScope.direct) ??
          LibyearScope.direct,
    );
    overrides.ensureFullyRead();
    yaml.ensureFullyRead();
    return config;
  }

  /// The pubspec fields `required_metadata` may name.
  static const metadataFields = <String>[
    'description',
    'repository',
    'homepage',
    'issue_tracker',
    'documentation',
    'topics',
  ];

  /// The packages never reported as unused by default: `cupertino_icons`
  /// is used through its font, not through an import.
  static const defaultUnusedAllow = <String>['cupertino_icons'];

  /// Whether `scan`, `deps` and `check` apply the policy.
  final bool enabled;

  /// The forbidden packages, direct or transitive.
  final List<DeniedPackage> denied;

  /// When not empty, the only hosted packages a pubspec may depend on.
  final List<String> allowed;

  /// When not empty, the only package registries hosted packages may come
  /// from, without a trailing slash; pub.dev is `https://pub.dev`.
  final List<String> allowedHosts;

  /// When not empty, the only hosts Git dependencies may come from.
  final List<String> allowedGitHosts;

  /// Whether every hosted constraint needs an upper bound.
  final bool requireUpperBound;

  /// The lowest Dart SDK the `environment.sdk` constraint may allow.
  final Version? minSdk;

  /// The lowest Flutter SDK the `environment.flutter` constraint may allow.
  final Version? minFlutter;

  /// Packages that belong in `dev_dependencies` only.
  final List<String> devOnly;

  /// Whether every package needs `publish_to`, unless it is one of the
  /// [publishedPackages].
  final bool requirePublishTo;

  /// Packages meant to be published, which need no `publish_to`.
  final List<String> publishedPackages;

  /// The pubspec fields a publishable package must declare.
  final List<String> requiredMetadata;

  /// Whether `pubspec.lock` must match the direct dependencies.
  final bool lockfileInSync;

  /// Whether every hosted package of `pubspec.lock` needs a checksum.
  final bool lockfileChecksums;

  /// Whether the imports are checked for unused dependencies and
  /// development dependencies used by `lib/` or `bin/`.
  final bool checkImports;

  /// Packages never reported as unused.
  final List<String> unusedAllow;

  /// How hosted constraints must be written.
  final ConstraintStyle constraintStyle;

  /// Whether every entry of `dependency_overrides` needs a justification
  /// in [allowedOverrides].
  final bool overridesRequireReason;

  /// The justified dependency overrides, collected from every layer.
  final List<AllowedOverride> allowedOverrides;

  /// Whether `pubspec.lock` must be committed.
  final LockfilePolicy lockfilePolicy;

  /// The most breaking releases a direct dependency may be behind its
  /// latest version, or `null` for no limit; checking it needs the network.
  final int? maxMajorBehind;

  /// The most libyears the dependencies may add up to, or `null` for no
  /// limit; checking it needs the network.
  final double? maxLibyear;

  /// Which packages count towards [maxLibyear].
  final LibyearScope libyearScope;

  /// Whether a rule that needs the package registry is configured.
  bool get hasOutdatedRules => maxMajorBehind != null || maxLibyear != null;

  /// Reads the version at [key] of [yaml].
  ///
  /// Returns the version, or `null` when absent.
  ///
  /// Throws an [InspectraConfigException] when it is no version.
  static Version? _version(YamlReader yaml, String key) {
    final String? text = yaml.optionalString(key);
    if (text == null) {
      return null;
    }
    try {
      return Version.parse(text);
    } on FormatException {
      final path = yaml.path.isEmpty ? key : '${yaml.path}.$key';
      throw InspectraConfigException(
        path,
        'expected a version such as 3.6.0, got "$text".',
      );
    }
  }

  /// Returns [url] without trailing slashes.
  static String _trimSlash(String url) => url.replaceAll(RegExp(r'/+$'), '');
}
