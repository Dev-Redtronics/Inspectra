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

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/doctor/doctor_check.dart';
import 'package:inspectra/src/doctor/doctor_status.dart';
import 'package:inspectra/src/host/host_platform.dart';
import 'package:inspectra/src/io/environment.dart';
import 'package:inspectra/src/io/executable_resolver.dart';
import 'package:inspectra/src/io/process_outcome.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/trivy/trivy_locator.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Checks what Inspectra needs on this machine and in this project: the
/// configuration, the Dart and Flutter SDKs, Git, Trivy, the network and
/// the cache - the usual causes of support tickets in corporate networks.
final class Doctor {
  /// Creates the doctor of the package in [packageRoot], running tools
  /// with [processRunner] - the Dart SDK as [dartExecutable] - in
  /// [environment] on [host], with the cache in [cacheRoot]; with
  /// [offline], no connection is opened.
  const Doctor({
    required this.packageRoot,
    required this.processRunner,
    required this.environment,
    required this.host,
    required this.cacheRoot,
    required this.dartExecutable,
    this.offline = false,
  });

  /// The package to check.
  final String packageRoot;

  /// Runs the tools.
  final ProcessRunner processRunner;

  /// The environment variables.
  final Environment environment;

  /// The operating system and architecture.
  final HostPlatform host;

  /// The Inspectra cache directory.
  final String cacheRoot;

  /// The `dart` executable.
  final String dartExecutable;

  /// Whether no connection may be opened.
  final bool offline;

  /// The oldest Git that every feature supports.
  static final _minimumGit = Version(2, 15, 0);

  /// How long a tool may take to report its version.
  static const _timeout = Duration(seconds: 30);

  /// Runs every check.
  ///
  /// Returns the results in a fixed order.
  Future<List<DoctorCheck>> run() async {
    final (InspectraConfig config, DoctorCheck configCheck) = _config();
    final Pubspec? pubspec = _pubspec();
    final bool online = !offline && !config.network.offline;
    return <DoctorCheck>[
      configCheck,
      await _dart(pubspec),
      if (pubspec?.isFlutterProject ?? false) await _flutter(pubspec),
      await _git(),
      await _trivy(config),
      ..._networkSettings(config),
      if (online) ...await _reachability(config),
      if (!online)
        const DoctorCheck(
          'Network',
          DoctorStatus.skipped,
          'offline; the services were not contacted.',
        ),
      if (online) await _pubToken(config),
      _cache(),
    ];
  }

  /// Loads the configuration of the package.
  ///
  /// Returns the configuration - the defaults with the environment when it
  /// is invalid - and the check.
  (InspectraConfig, DoctorCheck) _config() {
    try {
      final recorder = ConfigRecorder();
      final InspectraConfig config = loadConfig(
        packageRoot,
        overrides: ConfigOverrides(environment: environment),
        requirePubspec: false,
        recorder: recorder,
        cacheRoot: cacheRoot,
      );
      final int bases = recorder.layers.isEmpty ? 1 : recorder.layers.length;
      final String source = recorder.source ?? 'the built-in defaults';
      return (
        config,
        DoctorCheck(
          'Configuration',
          DoctorStatus.ok,
          bases > 1
              ? '$source with ${bases - 1} base(s) is valid.'
              : '$source is valid.',
        ),
      );
    } on InspectraConfigException catch (error) {
      return (
        _defaults(),
        DoctorCheck('Configuration', DoctorStatus.fail, '$error'),
      );
    }
  }

  /// The built-in defaults with the `INSPECTRA_*` variables on top, for a
  /// configuration that cannot be read; invalid variables fall back to the
  /// defaults alone.
  ///
  /// Returns the configuration.
  InspectraConfig _defaults() {
    try {
      return InspectraConfig.parse(
        null,
        packageName: 'package',
        overrides: ConfigOverrides(environment: environment),
      );
    } on InspectraConfigException {
      return InspectraConfig.defaults('package');
    }
  }

  /// Reads the pubspec of the package.
  ///
  /// Returns the pubspec, or `null` without a readable one.
  Pubspec? _pubspec() {
    final file = File(p.join(packageRoot, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return null;
    }
    try {
      return const PubspecParser().parse(
        file.readAsStringSync(),
        path: 'pubspec.yaml',
      );
    } on InvalidInputException {
      return null;
    }
  }

  /// Checks the Dart SDK against the `environment.sdk` of [pubspec].
  ///
  /// Returns the check.
  Future<DoctorCheck> _dart(Pubspec? pubspec) async {
    final String? output = await _version(dartExecutable, <String>[
      '--version',
    ]);
    final Version? version = _firstVersion(output);
    if (version == null) {
      return const DoctorCheck(
        'Dart SDK',
        DoctorStatus.fail,
        'dart --version did not run; install the Dart SDK.',
      );
    }
    return _against('Dart SDK', version, pubspec?.sdkConstraint, 'sdk');
  }

  /// Checks the Flutter SDK against the `environment.flutter` of
  /// [pubspec] and the version `.fvmrc` pins.
  ///
  /// Returns the check.
  Future<DoctorCheck> _flutter(Pubspec? pubspec) async {
    final String? output = await _version('flutter', <String>[
      '--version',
      '--machine',
    ]);
    final Version? version = _parse(_jsonField(output, 'frameworkVersion'));
    if (version == null) {
      return const DoctorCheck(
        'Flutter SDK',
        DoctorStatus.fail,
        'flutter --version did not run; install Flutter or put it on the '
            'PATH.',
      );
    }
    final String? pinned = _fvmVersion();
    if (pinned != null && pinned != '$version') {
      return DoctorCheck(
        'Flutter SDK',
        DoctorStatus.warn,
        '$version is installed, but .fvmrc pins $pinned; run "fvm use".',
      );
    }
    return _against(
      'Flutter SDK',
      version,
      pubspec?.flutterConstraint,
      'flutter',
    );
  }

  /// Compares [version] of the SDK [name] with the [constraint] of
  /// `environment.[key]`.
  ///
  /// Returns the check.
  static DoctorCheck _against(
    String name,
    Version version,
    String? constraint,
    String key,
  ) {
    if (constraint == null) {
      return DoctorCheck(name, DoctorStatus.ok, '$version.');
    }
    final VersionConstraint? parsed = _constraint(constraint);
    if (parsed == null || parsed.allows(version)) {
      return DoctorCheck(
        name,
        DoctorStatus.ok,
        '$version satisfies environment.$key $constraint.',
      );
    }
    return DoctorCheck(
      name,
      DoctorStatus.fail,
      '$version does not satisfy environment.$key $constraint.',
    );
  }

  /// Reads the Flutter version `.fvmrc` pins.
  ///
  /// Returns the version, or `null` without the file.
  String? _fvmVersion() {
    final file = File(p.join(packageRoot, '.fvmrc'));
    return file.existsSync()
        ? _jsonField(file.readAsStringSync(), 'flutter')
        : null;
  }

  /// Checks that Git is installed and recent enough.
  ///
  /// Returns the check.
  Future<DoctorCheck> _git() async {
    final Version? version = _firstVersion(
      await _version('git', <String>['--version']),
    );
    if (version == null) {
      return const DoctorCheck(
        'Git',
        DoctorStatus.warn,
        'git is not installed; changelog, api semver, the lockfile policy '
            'and workspace affected need it.',
      );
    }
    return version < _minimumGit
        ? DoctorCheck(
            'Git',
            DoctorStatus.warn,
            '$version is older than $_minimumGit; upgrade Git.',
          )
        : DoctorCheck('Git', DoctorStatus.ok, '$version.');
  }

  /// Finds the Trivy that [config] would use.
  ///
  /// Returns the check.
  Future<DoctorCheck> _trivy(InspectraConfig config) async {
    final TrivyConfig trivy = config.trivy;
    if (trivy.mode == TrivyMode.disabled) {
      return const DoctorCheck(
        'Trivy',
        DoctorStatus.skipped,
        'trivy.mode is disabled.',
      );
    }
    final binaryName = host.isWindows ? 'trivy.exe' : 'trivy';
    final locator = TrivyLocator(
      resolver: ExecutableResolver(environment: environment, host: host),
      processRunner: processRunner,
      environment: environment,
      installRoot: trivy.installDirectory ?? p.join(cacheRoot, 'trivy'),
      binaryName: binaryName,
    );
    final String? executable = trivy.executable;
    final TrivyAvailable? found = executable != null
        ? await locator.configured(executable)
        : await locator.cached(trivy.version) ?? await locator.installed();
    if (found != null) {
      return DoctorCheck(
        'Trivy',
        DoctorStatus.ok,
        '${found.version} at ${found.executable}.',
      );
    }
    if (trivy.download && executable == null) {
      return DoctorCheck(
        'Trivy',
        DoctorStatus.warn,
        'not installed; ${trivy.version} is downloaded on first use while '
            'online.',
      );
    }
    return DoctorCheck(
      'Trivy',
      trivy.mode == TrivyMode.required ? DoctorStatus.fail : DoctorStatus.warn,
      'not found; install it or set trivy.executable.',
    );
  }

  /// Describes the proxy and the CA bundle the network uses.
  ///
  /// Returns the checks.
  List<DoctorCheck> _networkSettings(InspectraConfig config) {
    final NetworkConfig network = config.network;
    final String? proxy =
        network.proxy ??
        environment['HTTPS_PROXY'] ??
        environment['https_proxy'];
    final String? bundle = network.caCertificates;
    return <DoctorCheck>[
      DoctorCheck(
        'Proxy',
        DoctorStatus.ok,
        proxy == null ? 'none.' : '${_withoutCredentials(proxy)}.',
      ),
      if (bundle != null) _caBundle(p.normalize(p.join(packageRoot, bundle))),
    ];
  }

  /// Checks that the CA bundle at [path] can be loaded.
  ///
  /// Returns the check.
  static DoctorCheck _caBundle(String path) {
    try {
      SecurityContext().setTrustedCertificates(path);
      return DoctorCheck('CA bundle', DoctorStatus.ok, '$path loads.');
    } on Exception catch (error) {
      return DoctorCheck(
        'CA bundle',
        DoctorStatus.fail,
        '$path cannot be loaded: $error',
      );
    }
  }

  /// Contacts OSV.dev, the package registry and, with Trivy, its releases.
  ///
  /// Returns one check per service.
  Future<List<DoctorCheck>> _reachability(InspectraConfig config) async {
    final HttpTransport transport;
    try {
      transport = HttpTransport(
        config: config.network.withResolvedPaths(
          (path) => p.normalize(p.join(packageRoot, path)),
        ),
        environment: environment,
      );
    } on InspectraException catch (error) {
      return <DoctorCheck>[
        DoctorCheck('Network', DoctorStatus.fail, error.message),
      ];
    }
    try {
      final services = <(String, String)>[
        ('OSV.dev', config.network.osvUrl),
        ('Package registry', config.network.pubHostedUrl),
        if (config.trivy.enabled && config.trivy.download)
          ('Trivy releases', config.trivy.downloadBaseUrl),
      ];
      final checks = <DoctorCheck>[];
      for (final (String name, String url) in services) {
        final bool reachable = await transport.probe(
          Uri.parse(url),
          config.network.timeout,
        );
        checks.add(
          reachable
              ? DoctorCheck(name, DoctorStatus.ok, '$url is reachable.')
              : DoctorCheck(
                  name,
                  DoctorStatus.fail,
                  '$url is not reachable; check the proxy, the CA bundle and '
                  'the firewall.',
                ),
        );
      }
      return checks;
    } finally {
      transport.close();
    }
  }

  /// Checks that `dart pub` has a token for a private registry.
  ///
  /// Returns the check.
  Future<DoctorCheck> _pubToken(InspectraConfig config) async {
    final String registry = config.network.pubHostedUrl;
    if (Lockfile.isPublicRegistry(registry, Lockfile.publicRegistries.first)) {
      return const DoctorCheck(
        'Pub token',
        DoctorStatus.skipped,
        'the registry is public.',
      );
    }
    final String? tokens = await _version(dartExecutable, <String>[
      'pub',
      'token',
      'list',
    ]);
    final String host = Uri.parse(registry).host;
    return tokens != null && tokens.contains(host)
        ? DoctorCheck(
            'Pub token',
            DoctorStatus.ok,
            'dart pub has a token for $host.',
          )
        : DoctorCheck(
            'Pub token',
            DoctorStatus.warn,
            'dart pub has no token for $host; run "dart pub token add '
                '$registry".',
          );
  }

  /// Checks that the cache directory can be written.
  ///
  /// Returns the check.
  DoctorCheck _cache() {
    try {
      final directory = Directory(cacheRoot)..createSync(recursive: true);
      File(p.join(directory.path, '.doctor'))
        ..writeAsStringSync('ok')
        ..deleteSync();
      return DoctorCheck('Cache', DoctorStatus.ok, '$cacheRoot is writable.');
    } on FileSystemException catch (error) {
      return DoctorCheck(
        'Cache',
        DoctorStatus.fail,
        '$cacheRoot is not writable: ${error.message}; set '
            'INSPECTRA_CACHE_DIR.',
      );
    }
  }

  /// Runs [executable] with [arguments] to read its version.
  ///
  /// Returns the standard output, or `null` when it cannot run.
  Future<String?> _version(String executable, List<String> arguments) async {
    try {
      final ProcessOutcome outcome = await processRunner.run(
        executable,
        arguments,
        workingDirectory: packageRoot,
        runInShell: host.isWindows,
        timeout: _timeout,
      );
      return outcome.succeeded ? '${outcome.stdout}${outcome.stderr}' : null;
    } on ProcessException {
      return null;
    }
  }

  /// Finds the first version number in [output].
  ///
  /// Returns the version, or `null`.
  static Version? _firstVersion(String? output) =>
      _parse(RegExp(r'\d+\.\d+\.\d+').firstMatch(output ?? '')?.group(0));

  /// Reads the text field [key] of the JSON object [text].
  ///
  /// Returns the value, or `null` when there is none.
  static String? _jsonField(String? text, String key) {
    try {
      final Object? decoded = jsonDecode(text ?? '');
      final Object? value = decoded is Map ? decoded[key] : null;
      return value is String ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// Parses [text] as a version.
  ///
  /// Returns the version, or `null`.
  static Version? _parse(String? text) {
    try {
      return text == null ? null : Version.parse(text);
    } on FormatException {
      return null;
    }
  }

  /// Parses [text] as a version constraint.
  ///
  /// Returns the constraint, or `null`.
  static VersionConstraint? _constraint(String text) {
    try {
      return VersionConstraint.parse(text);
    } on FormatException {
      return null;
    }
  }

  /// Removes user and password from the proxy [url], which may hold a
  /// secret.
  ///
  /// Returns the URL without credentials.
  static String _withoutCredentials(String url) =>
      url.replaceFirst(RegExp('//[^/@]*@'), '//');
}
