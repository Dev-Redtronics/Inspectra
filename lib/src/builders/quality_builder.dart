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

import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/builders/build_step_config.dart';
import 'package:inspectra/src/builders/log_build_outcome.dart';
import 'package:inspectra/src/builders/quality_outcome.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/quality/format_check.dart';
import 'package:inspectra/src/quality/lint.dart';
import 'package:inspectra/src/style/style_check.dart';
import 'package:inspectra/src/style/style_result.dart';
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
  /// Creates the builder of the check [_name], which reads only the build
  /// sources [_inPackage] accepts.
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

  /// The builder of the style check.
  const factory QualityBuilder.style({bool Function(AssetId id) inPackage}) =
      _StyleBuilder;

  /// The name of the check, which names its report as well.
  final String _name;

  /// Decides whether a build source is a file of the package, rather than an
  /// output another builder keeps in the build cache.
  final bool Function(AssetId id) _inPackage;

  /// The report the check writes, relative to the package root.
  String get _report => 'inspectra/$_name.json';

  /// Writes the [_report] once per package.
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': [_report],
  };

  /// Whether the check is enabled to run on build in [config].
  bool _runsOnBuild(InspectraConfig config);

  /// Runs the check.
  Future<QualityOutcome> _run(
    BuildStep buildStep,
    InspectraConfig config,
    String packageRoot,
  );

  /// Runs the check when it is enabled to run on build, writes its JSON report
  /// and logs its outcome; configuration and tool errors are logged as severe
  /// instead of failing the build with a stack trace.
  @override
  Future<void> build(BuildStep buildStep) async {
    try {
      final InspectraConfig config = await readConfig(buildStep);
      if (!_runsOnBuild(config)) {
        return;
      }
      final QualityOutcome outcome = await _run(
        buildStep,
        config,
        Directory.current.path,
      );
      await buildStep.writeAsString(
        AssetId(buildStep.inputId.package, _report),
        const JsonEncoder.withIndent('  ').convert(outcome.report),
      );
      logBuildOutcome(
        outcome.rendered,
        failed: outcome.failed,
        findings: outcome.hasFindings,
      );
    } on InspectraConfigException catch (error) {
      log.severe('$error');
    } on DartToolException catch (error) {
      log.severe('$error');
    } on InspectraException catch (error) {
      log.severe(error.message);
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

/// Checks that the configured Dart files are formatted.
final class _FormatBuilder extends QualityBuilder {
  /// Creates the format builder; [inPackage] decides which build sources are
  /// files of the package.
  const _FormatBuilder({bool Function(AssetId id) inPackage = isInPackage})
    : super._('format', inPackage);

  /// The format check runs on build when it is enabled and its `run_on_build`
  /// is set.
  @override
  bool _runsOnBuild(InspectraConfig config) =>
      config.format.enabled && config.format.runOnBuild;

  /// Runs `dart format` over the configured files, which are read through
  /// [buildStep] first so that changing one of them reruns the check.
  @override
  Future<QualityOutcome> _run(
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
    return QualityOutcome(
      report: result.toJson(),
      rendered: result.render(),
      failed: result.failed,
      hasFindings: result.unformatted.isNotEmpty,
    );
  }
}

/// Runs the static analysis of the package.
final class _LintBuilder extends QualityBuilder {
  /// Creates the lint builder; [inPackage] decides which build sources are
  /// files of the package.
  const _LintBuilder({bool Function(AssetId id) inPackage = isInPackage})
    : super._('lint', inPackage);

  /// The lint check runs on build when it is enabled and its `run_on_build`
  /// is set.
  @override
  bool _runsOnBuild(InspectraConfig config) =>
      config.lint.enabled && config.lint.runOnBuild;

  /// Runs `dart analyze` over the package, after reading every Dart file and
  /// `analysis_options.yaml` through [buildStep] so that a change reruns it.
  @override
  Future<QualityOutcome> _run(
    BuildStep buildStep,
    InspectraConfig config,
    String packageRoot,
  ) async {
    await _track(buildStep, const ['**.dart'], const []);
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
    return QualityOutcome(
      report: result.toJson(),
      rendered: result.render(),
      failed: result.failed,
      hasFindings: result.issues.isNotEmpty,
    );
  }
}

/// Runs the style check on build.
final class _StyleBuilder extends QualityBuilder {
  /// Creates the style builder; [inPackage] decides which build sources are
  /// files of the package.
  const _StyleBuilder({bool Function(AssetId id) inPackage = isInPackage})
    : super._('style', inPackage);

  /// The style check runs on build when it is enabled and its
  /// `run_on_build` is set.
  @override
  bool _runsOnBuild(InspectraConfig config) =>
      config.style.enabled && config.style.runOnBuild;

  /// Reads [id] through [buildStep]; a file of the package that is not a
  /// build source, such as a header template outside the default source
  /// directories, is read from disk with a warning that editing it does not
  /// rerun the check.
  ///
  /// Returns the text, or `null` when the file does not exist.
  static Future<String?> _readSource(BuildStep buildStep, AssetId id) async {
    if (await buildStep.canRead(id)) {
      return buildStep.readAsString(id);
    }
    final file = File(id.path);
    if (!file.existsSync()) {
      return null;
    }
    log.warning(
      '${id.path} is not a build_runner source, so editing it does not rerun '
      'the style check. Add it to the sources in build.yaml.',
    );
    return file.readAsString();
  }

  /// Checks the selected files, reading them and the license header
  /// template through [buildStep], and tracks the custom rule files, so
  /// that a change to any of them reruns the check.
  @override
  Future<QualityOutcome> _run(
    BuildStep buildStep,
    InspectraConfig config,
    String packageRoot,
  ) async {
    final StyleConfig style = config.style;
    final List<String> files = await _track(
      buildStep,
      style.include,
      style.exclude,
    );
    await _track(buildStep, style.customRules, const []);
    final String package = buildStep.inputId.package;
    final StyleResult result = await checkStyle(
      config: style,
      packageRoot: packageRoot,
      files: files,
      read: (path) => _readSource(buildStep, AssetId(package, path)),
    );
    return QualityOutcome(
      report: result.toJson(),
      rendered: result.render(),
      failed: result.failed,
      hasFindings: result.violations.isNotEmpty,
    );
  }
}
