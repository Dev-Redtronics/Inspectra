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

import 'package:inspectra/src/config/format_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/style/built_in_style_rules.dart';
import 'package:inspectra/src/style/style_preset.dart';

/// The style check, Inspectra's own rules on the syntax tree, the `style:`
/// section.
final class StyleConfig {
  /// Creates the style settings.
  const StyleConfig({
    this.enabled = false,
    this.runOnBuild = false,
    this.failOnFindings = true,
    this.preset = StylePreset.recommended,
    this.rules = const <String, bool>{},
    this.licenseHeader,
    this.customRules = const <String>[],
    this.include = FormatConfig.defaultInclude,
    this.exclude = FormatConfig.defaultExclude,
  });

  /// Reads the settings from the `style:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an [InspectraConfigException] for unknown keys, invalid values,
  /// rule ids that are not lower snake case, unknown rules without custom
  /// rules, and `license_header: true` without a header template.
  factory StyleConfig.fromYaml(YamlReader yaml) {
    final List<String> customRules = yaml.strings(
      'custom_rules',
      fallback: const <String>[],
    );
    final String? licenseHeader = yaml.optionalString('license_header');
    final YamlReader rulesYaml = yaml.section('rules');
    final rules = <String, bool>{};
    final prefix = '${rulesYaml.keyPath}.';
    final ids = <String>{
      ...builtInStyleRuleIds,
      ...rulesYaml.fileKeys,
      for (final String key in rulesYaml.overrides.cli.keys)
        if (key.startsWith(prefix)) key.substring(prefix.length),
    };
    for (final id in ids) {
      final bool? value = _optionalBoolean(rulesYaml, id);
      if (value == null) {
        continue;
      }
      _validateRule(rulesYaml, id, customRules: customRules);
      rules[id] = value;
    }
    rulesYaml.ensureFullyRead();
    if (rules['license_header'] == true && licenseHeader == null) {
      throw InspectraConfigException(
        _child(rulesYaml, 'license_header'),
        'the rule needs a header template; set style.license_header to its '
        'file.',
      );
    }
    final config = StyleConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      preset: yaml.choice(
        'preset',
        StylePreset.byId,
        fallback: StylePreset.recommended,
      ),
      rules: Map<String, bool>.unmodifiable(rules),
      licenseHeader: licenseHeader,
      customRules: customRules,
      include: yaml.strings('include', fallback: FormatConfig.defaultInclude),
      exclude: yaml.strings('exclude', fallback: FormatConfig.defaultExclude),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Reads the switch of the rule [id], which is absent from most files.
  ///
  /// Returns the switch, or `null` when the rule is not mentioned.
  static bool? _optionalBoolean(YamlReader rules, String id) {
    final bool on = rules.boolean(id, fallback: true);
    final bool off = rules.boolean(id, fallback: false);
    return on == off ? on : null;
  }

  /// Checks the rule [id] given under `rules`.
  ///
  /// Throws an [InspectraConfigException] when [id] is not lower snake
  /// case, or is neither built in nor possibly one of the [customRules].
  static void _validateRule(
    YamlReader rules,
    String id, {
    required List<String> customRules,
  }) {
    if (!styleRuleIdPattern.hasMatch(id)) {
      throw InspectraConfigException(
        _child(rules, id),
        'rule ids are lower snake case, such as no_else.',
      );
    }
    final bool known = builtInStyleRuleIds.contains(id);
    if (known || customRules.isNotEmpty) {
      return;
    }
    throw InspectraConfigException(
      _child(rules, id),
      'unknown rule. Built-in rules: ${builtInStyleRuleIds.join(', ')}.',
    );
  }

  /// Returns the dotted path of [key] below [yaml].
  static String _child(YamlReader yaml, String key) =>
      yaml.path.isEmpty ? key : '${yaml.path}.$key';

  /// Whether `inspectra check` runs the style check. Off by default.
  final bool enabled;

  /// Whether `dart run build_runner build` runs it too.
  final bool runOnBuild;

  /// Whether violations fail the build or the command.
  final bool failOnFindings;

  /// The built-in rules that run unless [rules] says otherwise.
  final StylePreset preset;

  /// Rules switched on (`true`) or off (`false`) by id, built-in and
  /// custom; they win over the [preset]. `--set style.rules.<id>=false`
  /// works for every rule, `INSPECTRA_STYLE_RULES_<ID>` for the built-in
  /// rules and those listed in the file.
  final Map<String, bool> rules;

  /// The license header template, relative to the package root, or `null`
  /// to leave out the `license_header` rule.
  final String? licenseHeader;

  /// Dart files of the package that declare custom rules in a top level
  /// `styleRules`, relative to the package root.
  final List<String> customRules;

  /// Globs of the files to check, relative to the package root.
  final List<String> include;

  /// Globs of the files to leave out, relative to the package root.
  final List<String> exclude;

  /// Whether the rule [id], built-in or custom, runs.
  bool runs(String id) =>
      isStyleRuleEnabled(id, preset: preset, overrides: rules);
}
