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

/// Inspectra — supply-chain security scanning for Dart and Flutter.
///
/// The library exposes the command line (`InspectraCommandRunner`) for
/// embedding, the configuration model and the normalised finding model so
/// that other tools can consume Inspectra results programmatically.
library;

export 'src/cli/command_context.dart';
export 'src/cli/exit_code.dart';
export 'src/cli/inspectra_command_runner.dart';
export 'src/config/config_loader.dart';
export 'src/config/ignore_rule.dart';
export 'src/config/inspect_config.dart';
export 'src/config/inspectra_config.dart';
export 'src/config/network_config.dart';
export 'src/config/trivy_config.dart';
export 'src/config/trivy_mode.dart';
export 'src/config/trust_thresholds.dart';
export 'src/config/typosquat_config.dart';
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
export 'src/version.dart';
