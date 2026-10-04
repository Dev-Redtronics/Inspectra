import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/api/api_diff.dart';
import 'package:inspectra/src/api/api_renderer.dart';
import 'package:inspectra/src/builders/build_step_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:path/path.dart' as p;

/// Writes the public API of the root package to its committed dump.
///
/// `dart run build_runner build` keeps the dump up to date, so an API change
/// shows up as a diff in review. `dart run build_runner build --only-check`
/// writes nothing and fails when the committed dump is out of date, which is
/// the check to run in CI.
class ApiBuilder implements Builder {
  /// Creates a builder writing the dump to [output], relative to the package
  /// root.
  ApiBuilder(this.output);

  /// Reads the dump location from the package's configuration on disk, since
  /// build_runner needs to know it before any build step runs.
  factory ApiBuilder.fromOptions(BuilderOptions options) {
    final Object? configured = options.config['output'];
    if (configured is String) {
      return ApiBuilder(configured);
    }
    try {
      return ApiBuilder(loadConfig(Directory.current.path).api.output);
    } on Object {
      // The build step reports a broken configuration with its location.
      return ApiBuilder('api/${p.basename(Directory.current.path)}.api');
    }
  }

  /// The dump file, relative to the package root.
  final String output;

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': [output],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final InspectraConfig config;
    try {
      config = await readConfig(buildStep);
    } on InspectraConfigException catch (error) {
      log.severe('$error');
      return;
    }
    final ApiConfig api = config.api;
    if (!api.enabled) {
      return;
    }
    if (api.output != output) {
      log.severe(
        'api.output changed from "$output" to "${api.output}". '
        'Restart build_runner so that it picks up the new location.',
      );
      return;
    }

    final List<Glob> ignored = [
      for (final pattern in api.ignoredLibraries)
        Glob(pattern, context: p.posix),
    ];
    final libraries = <LibraryElement>[];
    final List<AssetId> ids =
        await buildStep.findAssets(Glob('lib/**.dart')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final id in ids) {
      if (id.path.startsWith('lib/src/')) {
        continue;
      }
      if (ignored.any((glob) => glob.matches(id.path))) {
        continue;
      }
      if (!await buildStep.resolver.isLibrary(id)) {
        continue;
      }
      libraries.add(await buildStep.resolver.libraryFor(id));
    }

    final String rendered = renderApi(
      libraries,
      nonPublicAnnotations: api.nonPublicAnnotations,
    );
    _reportChange(rendered);
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, output),
      rendered,
    );
  }

  /// Logs how the API differs from the dump on disk, so that the change is
  /// visible in the build output - and in the failure of `--only-check`.
  void _reportChange(String rendered) {
    final committed = File(output);
    if (!committed.existsSync()) {
      log.info('Recording the public API in $output for the first time.');
      return;
    }
    final String? diff = diffApi(
      expected: committed.readAsStringSync(),
      actual: rendered,
    );
    if (diff == null) {
      return;
    }
    log.warning('The public API changed; review and commit $output:\n$diff');
  }
}
