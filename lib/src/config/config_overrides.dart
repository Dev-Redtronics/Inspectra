import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/io/environment.dart';

/// The configuration values given outside of the configuration file.
///
/// A key such as `trivy.version` is looked up, in order of precedence, in:
///
/// 1. the command line overrides, `--set trivy.version=0.74.0` or a
///    dedicated flag such as `--trivy-version`;
/// 2. the environment variable derived from the key: `INSPECTRA_` followed by
///    the upper case path with dots turned into underscores, here
///    `INSPECTRA_TRIVY_VERSION`.
///
/// Only when neither defines the key is the configuration file consulted.
/// Command line overrides that no option consumed are reported by
/// [ensureAllConsumed], so a typo never goes unnoticed.
final class ConfigOverrides {
  /// Creates overrides from the command line values [cli], keyed by dotted
  /// path, and the [environment].
  ConfigOverrides({
    this.cli = const <String, String>{},
    this.environment = const Environment(<String, String>{}),
  });

  /// Overrides that define nothing.
  factory ConfigOverrides.none() => ConfigOverrides();

  /// The command line values keyed by dotted configuration path.
  final Map<String, String> cli;

  /// The environment providing `INSPECTRA_*` variables.
  final Environment environment;

  /// The command line keys that a configuration option has read.
  final Set<String> _consumed = <String>{};

  /// Returns the environment variable name of the dotted [path], for example
  /// `INSPECTRA_TRIVY_DOWNLOAD_BASE_URL` for `trivy.download_base_url`.
  static String environmentName(String path) =>
      'INSPECTRA_${path.toUpperCase().replaceAll('.', '_')}';

  /// Looks up the override of the option at the dotted [path].
  ///
  /// Returns the raw text and a description of its origin, or `null` when
  /// the option is not overridden.
  (String, String)? lookup(String path) {
    final fromCli = cli[path];
    if (fromCli != null) {
      _consumed.add(path);
      return (fromCli, 'the command line');
    }
    final variable = environmentName(path);
    final fromEnvironment = environment[variable];
    if (fromEnvironment == null) {
      return null;
    }
    return (fromEnvironment, 'the environment variable $variable');
  }

  /// Rejects command line overrides of options that do not exist.
  ///
  /// Throws an [InspectraConfigException] naming the first unknown key.
  void ensureAllConsumed() {
    for (final key in cli.keys) {
      if (!_consumed.contains(key)) {
        throw InspectraConfigException(
          key,
          'unknown option given on the command line.',
        );
      }
    }
  }
}
