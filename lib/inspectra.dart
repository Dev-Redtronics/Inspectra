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

/// Inspectra — software assurance and supply-chain security for Dart and
/// Flutter.
///
/// Most packages only need Inspectra as a command line tool or as a dev
/// dependency with its configuration. This library is for tooling that
/// wants to run the checks programmatically: the command line itself
/// (`InspectraCommandRunner`), the configuration model, the normalised
/// finding model of the supply-chain commands, the Trivy scans, the public
/// API dump, the format and lint checks and the coverage gate.
library;

export 'src/api/api_command.dart'
    show ApiCheckResult, checkApi, dumpApi, renderPackageApi;
export 'src/api/api_diff.dart' show diffApi;
export 'src/api/api_renderer.dart' show apiDumpHeader, renderApi;
export 'src/cli/command_context.dart';
export 'src/cli/exit_code.dart';
export 'src/cli/inspectra_command_runner.dart';
export 'src/config/config_loader.dart';
export 'src/config/config_overrides.dart';
export 'src/config/inspectra_config.dart';
export 'src/config/inspectra_config_exception.dart';
export 'src/coverage/coverage_gate.dart';
export 'src/host/host_platform.dart';
export 'src/io/clock.dart';
export 'src/io/environment.dart';
export 'src/io/process_outcome.dart';
export 'src/io/process_runner.dart';
export 'src/io/system_process_runner.dart';
export 'src/model/finding.dart';
export 'src/model/finding_source.dart';
export 'src/model/inspectra_exception.dart';
export 'src/model/severity.dart';
export 'src/model/source_location.dart';
export 'src/quality/format_check.dart';
export 'src/quality/lint.dart';
export 'src/quality/quality_command.dart';
export 'src/trivy/finding.dart';
export 'src/trivy/package_graph.dart';
export 'src/trivy/scans.dart';
export 'src/trivy/trivy.dart';
export 'src/trivy/trivy_command.dart';
export 'src/util/dart_tool.dart' show DartToolException;
export 'src/version.dart';
