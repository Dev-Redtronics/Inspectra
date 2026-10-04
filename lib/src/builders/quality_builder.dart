import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/builders/build_step_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/quality/format_check.dart';
import 'package:inspectra/src/quality/lint.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:path/path.dart' as p;

/// Checks formatting or runs the static analysis as part of
/// `dart run build_runner build`, when the check's `run_on_build` is set.
///
/// Both builders declare `.dart` as a required input in `build.yaml`, so
/// they run after every builder that generates Dart code: the check sees the
/// package as it is after the build. Every Dart file is read through the
/// build step, so the check reruns when one of them changes.
sealed class QualityBuilder implements Builder {
  const QualityBuilder._(this._name, this._inPackage);

  /// The builder of the format check.
  ///
  /// [inPackage] decides whether a build source is a file of the package,
  /// rather than an output another builder keeps in the build cache.
  const factory QualityBuilder.format({bool Function(AssetId id) inPackage}) =
      _FormatBuilder;

  /// The builder of the lint check.
  const factory QualityBuilder.lint({bool Function(AssetId id) inPackage}) =
      _LintBuilder;

  final String _name;

  final bool Function(AssetId id) _inPackage;

  String get _report => 'inspectra/$_name.json';

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': [_report],
  };

  /// Whether the check is enabled to run on build in [config].
  bool _runsOnBuild(InspectraConfig config);

  /// Runs the check.
  Future<_Outcome> _run(
    BuildStep buildStep,
    InspectraConfig config,
    String packageRoot,
  );

  @override
  Future<void> build(BuildStep buildStep) async {
    try {
      final InspectraConfig config = await readConfig(buildStep);
      if (!_runsOnBuild(config)) {
        return;
      }
      final _Outcome outcome = await _run(
        buildStep,
        config,
        Directory.current.path,
      );
      await buildStep.writeAsString(
        AssetId(buildStep.inputId.package, _report),
        const JsonEncoder.withIndent('  ').convert(outcome.report),
      );
      if (outcome.failed) {
        log.severe(outcome.rendered);
      } else if (outcome.hasFindings) {
        log.warning(outcome.rendered);
      } else {
        log.fine(outcome.rendered);
      }
    } on InspectraConfigException catch (error) {
      log.severe('$error');
    } on DartToolException catch (error) {
      log.severe('$error');
    }
  }

  /// Reads every build source matching [include] and none of [exclude]
  /// through the build step, and returns their paths.
  Future<List<String>> _track(
    BuildStep buildStep,
    List<String> include,
    List<String> exclude,
  ) async {
    final List<Glob> excludes = [
      for (final pattern in exclude) Glob(pattern, context: p.posix),
    ];
    final paths = <String>{};
    for (final pattern in include) {
      await for (final AssetId id in buildStep.findAssets(
        Glob(pattern, context: p.posix),
      )) {
        if (id.package != buildStep.inputId.package ||
            !_inPackage(id) ||
            excludes.any((glob) => glob.matches(id.path)) ||
            !paths.add(id.path)) {
          continue;
        }
        await buildStep.readAsBytes(id);
      }
    }
    return paths.toList()..sort();
  }
}

final class _FormatBuilder extends QualityBuilder {
  const _FormatBuilder({bool Function(AssetId id) inPackage = isInPackage})
    : super._('format', inPackage);

  @override
  bool _runsOnBuild(InspectraConfig config) =>
      config.format.enabled && config.format.runOnBuild;

  @override
  Future<_Outcome> _run(
    BuildStep buildStep,
    InspectraConfig config,
    String packageRoot,
  ) async {
    final FormatConfig format = config.format;
    final FormatResult result = await checkFormat(
      config: format,
      packageRoot: packageRoot,
      files: await _track(buildStep, format.include, format.exclude),
    );
    return _Outcome(
      report: result.toJson(),
      rendered: result.render(),
      failed: result.failed,
      hasFindings: result.unformatted.isNotEmpty,
    );
  }
}

final class _LintBuilder extends QualityBuilder {
  const _LintBuilder({bool Function(AssetId id) inPackage = isInPackage})
    : super._('lint', inPackage);

  @override
  bool _runsOnBuild(InspectraConfig config) =>
      config.lint.enabled && config.lint.runOnBuild;

  @override
  Future<_Outcome> _run(
    BuildStep buildStep,
    InspectraConfig config,
    String packageRoot,
  ) async {
    await _track(buildStep, const ['**.dart'], const []);
    // Read through the build step when it is a source, so that a changed
    // rule set reruns the analysis.
    final analysisOptions = AssetId(
      buildStep.inputId.package,
      'analysis_options.yaml',
    );
    if (await buildStep.canRead(analysisOptions)) {
      await buildStep.readAsBytes(analysisOptions);
    }
    final LintResult result = await runLint(
      config: config.lint,
      packageRoot: packageRoot,
    );
    return _Outcome(
      report: result.toJson(),
      rendered: result.render(),
      failed: result.failed,
      hasFindings: result.issues.isNotEmpty,
    );
  }
}

/// What a check produced, independent of which check it was.
class _Outcome {
  const _Outcome({
    required this.report,
    required this.rendered,
    required this.failed,
    required this.hasFindings,
  });

  final Map<String, Object?> report;
  final String rendered;
  final bool failed;
  final bool hasFindings;
}
