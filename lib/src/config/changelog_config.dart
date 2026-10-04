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

import 'package:inspectra/src/changelog/changelog_section.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// Changelog generation and validation, the `changelog:` section.
final class ChangelogConfig {
  /// Creates the changelog settings.
  const ChangelogConfig({
    this.enabled = false,
    this.file = defaultFile,
    this.tagPrefix = defaultTagPrefix,
    this.types = defaultTypes,
    this.unconventional = ChangelogSection.hidden,
    this.repository,
    this.commitUrl = defaultCommitUrl,
    this.compareUrl = defaultCompareUrl,
  });

  /// Reads the settings from the `changelog:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an [InspectraConfigException] for unknown keys, unknown
  /// sections and URL templates without their placeholder.
  factory ChangelogConfig.fromYaml(YamlReader yaml) {
    final YamlReader typesYaml = yaml.section('types');
    final types = <String, ChangelogSection>{...defaultTypes};
    final typeNames = <String>{...defaultTypes.keys, ...typesYaml.fileKeys};
    for (final type in typeNames) {
      final ChangelogSection fallback =
          defaultTypes[type] ?? ChangelogSection.hidden;
      types[type.toLowerCase()] = typesYaml.choice(
        type,
        ChangelogSection.byId,
        fallback: fallback,
      );
    }
    typesYaml.ensureFullyRead();
    final config = ChangelogConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      file: yaml.string('file', fallback: defaultFile),
      tagPrefix: _tagPrefix(yaml),
      types: Map<String, ChangelogSection>.unmodifiable(types),
      unconventional: yaml.choice(
        'unconventional',
        ChangelogSection.byId,
        fallback: ChangelogSection.hidden,
      ),
      repository: yaml.optionalString('repository'),
      commitUrl: _template(yaml, 'commit_url', defaultCommitUrl, '{hash}'),
      compareUrl: _template(yaml, 'compare_url', defaultCompareUrl, '{to}'),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Reads `tag_prefix`, which, unlike other strings, may be empty for
  /// tags without a prefix.
  ///
  /// Returns the prefix.
  static String _tagPrefix(YamlReader yaml) {
    final emptyInFile = yaml.structured('tag_prefix') == '';
    final overridden =
        yaml.overrides.lookup(
          yaml.keyPath.isEmpty ? 'tag_prefix' : '${yaml.keyPath}.tag_prefix',
        ) !=
        null;
    if (emptyInFile && !overridden) {
      return '';
    }
    return yaml.optionalString('tag_prefix') ?? defaultTagPrefix;
  }

  /// Reads the URL template at [key], which must contain [placeholder].
  ///
  /// Returns the template, or [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] when [placeholder] is missing.
  static String _template(
    YamlReader yaml,
    String key,
    String fallback,
    String placeholder,
  ) {
    final String template = yaml.string(key, fallback: fallback);
    if (template.contains(placeholder)) {
      return template;
    }
    final path = yaml.path.isEmpty ? key : '${yaml.path}.$key';
    throw InspectraConfigException(
      path,
      'the URL template must contain $placeholder, got "$template".',
    );
  }

  /// The changelog file used by default.
  static const defaultFile = 'CHANGELOG.md';

  /// The prefix of release tags used by default, as in `v1.2.3`.
  static const defaultTagPrefix = 'v';

  /// The commit link used by default, in the form GitHub, Gitea and
  /// Bitbucket understand.
  static const defaultCommitUrl = '{repository}/commit/{hash}';

  /// The comparison link used by default, in the form GitHub and Gitea
  /// understand.
  static const defaultCompareUrl = '{repository}/compare/{from}...{to}';

  /// The section of every Conventional Commits type known by default.
  static const defaultTypes = <String, ChangelogSection>{
    'feat': ChangelogSection.added,
    'fix': ChangelogSection.fixed,
    'perf': ChangelogSection.changed,
    'refactor': ChangelogSection.changed,
    'revert': ChangelogSection.changed,
    'deprecate': ChangelogSection.deprecated,
    'remove': ChangelogSection.removed,
    'security': ChangelogSection.security,
    'docs': ChangelogSection.hidden,
    'style': ChangelogSection.hidden,
    'test': ChangelogSection.hidden,
    'build': ChangelogSection.hidden,
    'ci': ChangelogSection.hidden,
    'chore': ChangelogSection.hidden,
  };

  /// Whether `inspectra check` validates the changelog. Off by default.
  final bool enabled;

  /// The changelog file, relative to the package root.
  final String file;

  /// The text in front of the version in release tags, empty for tags
  /// such as `1.2.3`.
  final String tagPrefix;

  /// The section of each Conventional Commits type, keyed by the lower
  /// case type. Types that are not listed are hidden.
  final Map<String, ChangelogSection> types;

  /// The section of commits that do not follow Conventional Commits.
  final ChangelogSection unconventional;

  /// The repository URL the links point to, or `null` for the
  /// `repository` of `pubspec.yaml`.
  final String? repository;

  /// The commit link with the placeholders `{repository}` and `{hash}`.
  final String commitUrl;

  /// The comparison link with the placeholders `{repository}`, `{from}`
  /// and `{to}`.
  final String compareUrl;

  /// Returns the section of commits of the Conventional Commits [type].
  ChangelogSection sectionOf(String type) =>
      types[type.toLowerCase()] ?? ChangelogSection.hidden;
}
