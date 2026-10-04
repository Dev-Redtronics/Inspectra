import 'package:inspectra/src/config/lint_level.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// The static analysis check, done by `dart analyze`, the `lint:` section.
final class LintConfig {
  /// Creates the static analysis settings.
  const LintConfig({
    required this.enabled,
    required this.runOnBuild,
    required this.failOn,
  });

  /// Reads the settings from the `lint:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory LintConfig.fromYaml(YamlReader yaml) {
    final config = LintConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOn: yaml.choice('fail_on', <String, LintLevel>{
        for (final level in LintLevel.values) level.name: level,
      }, fallback: LintLevel.info),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether the package is analyzed. Off by default.
  final bool enabled;

  /// Whether `dart run build_runner build` analyzes it too.
  final bool runOnBuild;

  /// The lowest severity that fails the check.
  final LintLevel failOn;
}
