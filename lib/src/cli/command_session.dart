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

import 'dart:io';

import 'package:inspectra/src/add/safe_package_adder.dart';
import 'package:inspectra/src/audit/audit_service.dart';
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/deps/dependency_fixer.dart';
import 'package:inspectra/src/deps/dependency_policy.dart';
import 'package:inspectra/src/deps/outdated_policy.dart';
import 'package:inspectra/src/deps/tracked_files.dart';
import 'package:inspectra/src/host/cache_directory.dart';
import 'package:inspectra/src/inspect/package_inspector.dart';
import 'package:inspectra/src/io/console.dart';
import 'package:inspectra/src/io/executable_resolver.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/osv/osv_cache.dart';
import 'package:inspectra/src/osv/osv_client.dart';
import 'package:inspectra/src/policy/finding_filter.dart';
import 'package:inspectra/src/pub/package_archive_downloader.dart';
import 'package:inspectra/src/pub/pub_package_cache.dart';
import 'package:inspectra/src/pub/pub_repository_client.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/pub/registry_listings.dart';
import 'package:inspectra/src/trivy/trivy_installer.dart';
import 'package:inspectra/src/trivy/trivy_locator.dart';
import 'package:inspectra/src/trivy/trivy_provisioner.dart';
import 'package:inspectra/src/trivy/trivy_release_asset.dart';
import 'package:inspectra/src/trivy/trivy_runner.dart';
import 'package:inspectra/src/trivy/trivy_service.dart';
import 'package:inspectra/src/trust/trust_assessor.dart';
import 'package:inspectra/src/typosquat/confusion_detector.dart';
import 'package:inspectra/src/typosquat/typosquat_detector.dart';
import 'package:inspectra/src/util/display_path.dart';
import 'package:path/path.dart' as p;

/// The state of one command invocation and the composition root that wires
/// Inspectra's services together.
///
/// Every service is created from the loaded [config] and the [context], so a
/// test that controls both controls the complete object graph.
final class CommandSession {
  /// Creates a session.
  CommandSession({
    required this.context,
    required this.config,
    required this.console,
    required this.cliIgnores,
    required this.workingDirectory,
  });

  /// The outside world.
  final CommandContext context;

  /// The loaded configuration.
  final InspectraConfig config;

  /// The user facing console.
  final Console console;

  /// The ids given with `--ignore`.
  final List<String> cliIgnores;

  /// The project directory the command works in; relative paths of the
  /// command line and the configuration are resolved against it.
  final String workingDirectory;

  /// The lazily created HTTP transport.
  HttpTransport? _transport;

  /// The HTTP transport, created on first use.
  HttpTransport get transport => _transport ??= HttpTransport(
    config: _resolvedNetwork,
    environment: context.environment,
    sleep: context.sleep,
  );

  /// The network settings with the CA bundle resolved against the project.
  NetworkConfig get _resolvedNetwork =>
      config.network.withResolvedPaths(resolve);

  /// Releases network resources.
  void close() => _transport?.close();

  /// Resolves [path] against the working directory.
  ///
  /// Returns the absolute, normalised path.
  String resolve(String path) => p.normalize(p.join(workingDirectory, path));

  /// Returns [path] as shown in reports.
  String display(String path) => displayPath(path, workingDirectory);

  /// Reads the `pubspec.yaml` of the project.
  ///
  /// Returns the pubspec, or `null` when the project has none.
  ///
  /// Throws an [InvalidInputException] when it is malformed.
  Pubspec? pubspec() {
    final String path = resolve('pubspec.yaml');
    if (!File(path).existsSync()) {
      return null;
    }
    return const PubspecParser().parseFile(path);
  }

  /// The per-user cache directory, falling back to the temp directory.
  String get cacheRoot => CacheDirectory(
    environment: context.environment,
    host: context.host,
  ).resolveOrTemp();

  /// Creates the reporting policy filter; with [baseline] it also leaves
  /// out the findings recorded in the package's baseline file.
  ///
  /// Returns the filter evaluated at the current time.
  ///
  /// Throws an `InvalidInputException` when the baseline file is malformed.
  FindingFilter filter({bool baseline = true}) => FindingFilter(
    minSeverity: config.minSeverity,
    rules: config.ignore,
    cliIgnores: cliIgnores,
    now: context.clock.now(),
    baseline: baseline ? baselineMatcher() : null,
    unignorable: config.forbiddenIgnoreSeverities,
  );

  /// Loads the baseline of the package in the working directory.
  ///
  /// Returns the matcher, which covers nothing when the baseline is
  /// disabled or its file does not exist.
  ///
  /// Throws an `InvalidInputException` when the baseline file is malformed.
  BaselineMatcher baselineMatcher() => BaselineMatcher.load(
    config.baseline,
    workingDirectory,
    unignorable: config.forbiddenIgnoreSeverities,
  );

  /// Creates the dependency policy of the configuration.
  ///
  /// Returns the policy, or `null` while `dependency_policy.enabled` is not
  /// set.
  DependencyPolicy? dependencyPolicy() {
    final DependencyPolicyConfig policy = config.dependencyPolicy;
    if (!policy.enabled) {
      return null;
    }
    return DependencyPolicy(
      config: policy,
      defaultRegistry: config.network.pubHostedUrl,
      now: context.clock.now(),
    );
  }

  /// Creates the check of how far the dependencies are behind the
  /// registry, which needs the network.
  ///
  /// Returns the check, or `null` while the dependency policy is disabled,
  /// configures neither `max_major_behind` nor `max_libyear`, or the
  /// network is off.
  OutdatedPolicy? outdatedPolicy() {
    final DependencyPolicyConfig policy = config.dependencyPolicy;
    final bool online =
        policy.enabled && policy.hasOutdatedRules && !config.network.offline;
    if (!online) {
      return null;
    }
    final listings = RegistryListings(
      transport: transport,
      cache: PubPackageCache(p.join(cacheRoot, 'pub')),
      clock: context.clock,
    );
    return OutdatedPolicy(
      config: policy,
      lookup: listings.lookup,
      defaultRegistry: config.network.pubHostedUrl,
      concurrency: config.network.concurrency,
    );
  }

  /// Lists the files Git tracks in [root], when the dependency policy
  /// checks whether lockfiles are committed.
  ///
  /// Returns their absolute paths, or `null` when the rule is off or
  /// [root] is not in a Git repository.
  Future<Set<String>?> lockfileTracking(String root) {
    final DependencyPolicyConfig policy = config.dependencyPolicy;
    final bool needed =
        policy.enabled && policy.lockfilePolicy != LockfilePolicy.any;
    return needed
        ? trackedFiles(context.processRunner, root)
        : Future<Set<String>?>.value();
  }

  /// Creates the fixer of the dependency policy.
  ///
  /// Returns the fixer, or `null` while the policy is disabled.
  DependencyFixer? dependencyFixer() {
    final DependencyPolicyConfig policy = config.dependencyPolicy;
    return policy.enabled ? DependencyFixer(policy) : null;
  }

  /// Creates the pub repository client.
  ///
  /// Returns the client.
  PubRepositoryClient repository() => PubRepositoryClient(
    transport: transport,
    baseUrl: config.network.pubHostedUrl,
  );

  /// Creates the audit service.
  ///
  /// Returns the service.
  AuditService auditService() => AuditService(
    osvClient: OsvClient(
      transport: transport,
      baseUrl: config.network.osvUrl,
      cache: OsvCache(p.join(cacheRoot, 'osv')),
    ),
    mirrorUrl: config.network.pubHostedUrl,
  );

  /// Creates the trust assessor.
  ///
  /// Returns the assessor.
  TrustAssessor trustAssessor() => TrustAssessor(
    repository: repository(),
    thresholds: config.trust,
    clock: context.clock,
  );

  /// Creates the package inspector.
  ///
  /// Returns the inspector.
  PackageInspector inspector() => PackageInspector(
    repository: repository(),
    downloader: PackageArchiveDownloader(
      transport: transport,
      repositoryUrl: config.network.pubHostedUrl,
      maxBytes: config.inspect.maxArchiveBytes,
    ),
    trustAssessor: trustAssessor(),
    config: config.inspect,
  );

  /// Creates the typosquat detector.
  ///
  /// Returns the detector.
  TyposquatDetector typosquatDetector() => TyposquatDetector(
    extraPopular: config.typosquat.popular,
    allow: config.typosquat.allow,
  );

  /// Creates the dependency confusion detector.
  ///
  /// Returns the detector, or `null` in offline mode.
  ConfusionDetector? confusionDetector() {
    if (config.network.offline) {
      return null;
    }
    return ConfusionDetector(
      publicRepository: repository(),
      concurrency: transport.concurrency,
      mirrorUrl: config.network.pubHostedUrl,
    );
  }

  /// Creates the safe package adder.
  ///
  /// Returns the adder.
  SafePackageAdder packageAdder() => SafePackageAdder(
    repository: repository(),
    inspector: inspector(),
    typosquatDetector: typosquatDetector(),
    processRunner: context.processRunner,
    host: context.host,
    config: config.inspect,
  );

  /// The Trivy settings with their paths resolved against the project.
  TrivyConfig get trivyConfig => config.trivy.withResolvedPaths(resolve);

  /// Creates the Trivy provisioner.
  ///
  /// Returns the provisioner.
  TrivyProvisioner trivyProvisioner() {
    final TrivyConfig trivy = trivyConfig;
    final binaryName = context.host.isWindows ? 'trivy.exe' : 'trivy';
    final String installRoot =
        trivy.installDirectory ?? p.join(cacheRoot, 'trivy');
    return TrivyProvisioner(
      config: trivy,
      locator: TrivyLocator(
        resolver: ExecutableResolver(
          environment: context.environment,
          host: context.host,
        ),
        processRunner: context.processRunner,
        environment: context.environment,
        installRoot: installRoot,
        binaryName: binaryName,
      ),
      installer: TrivyInstaller(
        transport: transport,
        processRunner: context.processRunner,
        host: context.host,
      ),
      transport: transport,
      host: context.host,
    );
  }

  /// Creates the Trivy service.
  ///
  /// Returns the service.
  TrivyService trivyService() => TrivyService(
    config: config.trivy,
    provisioner: trivyProvisioner(),
    runner: TrivyRunner(
      config: config.trivy,
      processRunner: context.processRunner,
      offline: config.network.offline,
    ),
  );

  /// Describes the Trivy release asset for this host, for diagnostics.
  ///
  /// Returns the asset name, or `null` when there is none.
  String? trivyAssetName() => TrivyReleaseAsset.forHost(
    context.host,
    config.trivy.version,
  )?.archiveName;
}
