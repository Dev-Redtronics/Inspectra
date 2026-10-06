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

import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/version_alignment.dart';
import 'package:inspectra/src/config/workspace_layer.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// The rules for the packages of a pub workspace, the `workspace_policy:`
/// section of the configuration of the workspace root.
///
/// Nothing is checked unless [enabled] is set; `deps -r` and `check` then
/// apply the rules to the workspace.
final class WorkspacePolicyConfig {
  /// Creates workspace policy settings.
  const WorkspacePolicyConfig({
    this.enabled = false,
    this.alignVersions = VersionAlignment.compatible,
    this.requireMembership = true,
    this.sameSdk = false,
    this.forbidCycles = true,
    this.includeDevDependencies = false,
    this.layers = const <WorkspaceLayer>[],
  });

  /// Reads the settings from the `workspace_policy:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an [InspectraConfigException] for unknown keys or invalid
  /// values.
  factory WorkspacePolicyConfig.fromYaml(YamlReader yaml) {
    final config = WorkspacePolicyConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      alignVersions:
          yaml.choice<VersionAlignment?>(
            'align_versions',
            <String, VersionAlignment?>{
              for (final alignment in VersionAlignment.values)
                alignment.id: alignment,
            },
            fallback: VersionAlignment.compatible,
          ) ??
          VersionAlignment.compatible,
      requireMembership: yaml.boolean('require_membership', fallback: true),
      sameSdk: yaml.boolean('same_sdk', fallback: false),
      forbidCycles: yaml.boolean('forbid_cycles', fallback: true),
      includeDevDependencies: yaml.boolean(
        'include_dev_dependencies',
        fallback: false,
      ),
      layers: WorkspaceLayer.listFromYaml(yaml),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether `deps -r` and `check` apply the rules.
  final bool enabled;

  /// How alike the constraints of an external dependency must be.
  final VersionAlignment alignVersions;

  /// Whether every package of the workspace must be listed in it and
  /// resolved by it.
  final bool requireMembership;

  /// Whether every package must have the SDK constraint of the root.
  final bool sameSdk;

  /// Whether dependency cycles between the packages are reported.
  final bool forbidCycles;

  /// Whether `dev_dependencies` count for cycles and layers.
  final bool includeDevDependencies;

  /// The layers of the architecture, empty for none.
  final List<WorkspaceLayer> layers;
}
