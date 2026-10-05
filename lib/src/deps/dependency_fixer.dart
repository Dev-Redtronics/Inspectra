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

import 'package:inspectra/src/config/dependency_policy_config.dart';
import 'package:inspectra/src/deps/pubspec_fix.dart';
import 'package:inspectra/src/deps/version_bounds.dart';
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_locator.dart';
import 'package:inspectra/src/util/yaml_plain.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Applies the fixes of the dependency policy to a `pubspec.yaml`, keeping
/// its comments, order and formatting.
///
/// It bounds constraints without an upper bound (`MISSING_UPPER_BOUND`),
/// moves development packages to `dev_dependencies`
/// (`DEV_ONLY_DEPENDENCY`) and adds `publish_to: none` below the name
/// (`MISSING_PUBLISH_TO`). Every other rule needs a decision a tool cannot
/// make.
final class DependencyFixer {
  /// Creates the fixer of the policy [config].
  const DependencyFixer(this.config);

  /// The policy settings.
  final DependencyPolicyConfig config;

  /// Fixes the [content] of a pubspec that parses to [pubspec].
  ///
  /// Returns the fixed content with a description of every change; fixing
  /// the result again changes nothing.
  PubspecFix fix(String content, Pubspec pubspec) {
    final editor = YamlEditor(content);
    final applied = <String>[
      if (config.requireUpperBound) ..._bound(editor, pubspec),
      ..._moveDevOnly(editor, pubspec),
    ];
    final edited = editor.toString();
    final String? publishTo = _publishTo(edited, pubspec);
    if (publishTo == null) {
      return PubspecFix(content: edited, applied: applied);
    }
    return PubspecFix(
      content: publishTo,
      applied: <String>[...applied, 'publish_to: none'],
    );
  }

  /// Bounds the hosted constraints without an upper bound in [editor].
  ///
  /// Returns a description per change.
  List<String> _bound(YamlEditor editor, Pubspec pubspec) {
    final applied = <String>[];
    final sections = <String, Map<String, DependencySpec>>{
      'dependencies': pubspec.dependencies,
      'dev_dependencies': pubspec.devDependencies,
    };
    for (final MapEntry(key: section, value: declared) in sections.entries) {
      for (final MapEntry(key: name, value: spec) in declared.entries) {
        final String? bounded = spec.kind == DependencyKind.hosted
            ? boundedConstraint(spec.constraint)
            : null;
        if (bounded == null) {
          continue;
        }
        final YamlNode node = editor.parseAt(<Object>[section, name]);
        final path = node is YamlMap
            ? <Object>[section, name, 'version']
            : <Object>[section, name];
        editor.update(path, bounded);
        applied.add('$name: ${spec.constraint} -> $bounded');
      }
    }
    return applied;
  }

  /// Moves the packages of `dev_only` from `dependencies` to
  /// `dev_dependencies` in [editor].
  ///
  /// Returns a description per change.
  List<String> _moveDevOnly(YamlEditor editor, Pubspec pubspec) {
    final applied = <String>[];
    for (final String name in config.devOnly) {
      if (!pubspec.dependencies.containsKey(name)) {
        continue;
      }
      final Object? declaration = toPlainValue(
        editor.parseAt(<Object>['dependencies', name]).value,
      );
      final YamlNode dev = editor.parseAt(<Object>[
        'dev_dependencies',
      ], orElse: () => wrapAsYamlNode(null));
      final bool alreadyDev = pubspec.devDependencies.containsKey(name);
      if (dev.value is YamlMap && !alreadyDev) {
        editor.update(<Object>['dev_dependencies', name], declaration);
      }
      if (dev.value is! YamlMap) {
        editor.update(
          <Object>['dev_dependencies'],
          <String, Object?>{name: declaration},
        );
      }
      editor.remove(<Object>['dependencies', name]);
      applied.add('$name: dependencies -> dev_dependencies');
    }
    return applied;
  }

  /// Adds `publish_to: none` below the `name:` line of [content] when the
  /// policy requires it.
  ///
  /// Returns the new content, or `null` when nothing is added.
  String? _publishTo(String content, Pubspec pubspec) {
    final String? name = pubspec.name;
    final bool needed =
        config.requirePublishTo &&
        pubspec.publishTo == null &&
        name != null &&
        !config.publishedPackages.contains(name);
    if (!needed) {
      return null;
    }
    final int? line = PubspecLocator.parse(
      content,
      pubspec.path,
    ).topLevel('name').line;
    if (line == null) {
      return null;
    }
    final newline = content.contains('\r\n') ? '\r\n' : '\n';
    final List<String> lines = content.split(newline)
      ..insert(line, 'publish_to: none');
    return lines.join(newline);
  }
}
