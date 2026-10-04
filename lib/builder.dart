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

/// The build_runner builders of Inspectra.
///
/// They are applied to the root package automatically once Inspectra is a
/// dev dependency, and do nothing until a feature is enabled in the
/// configuration.
library;

import 'package:build/build.dart';

import 'package:inspectra/src/builders/api_builder.dart';
import 'package:inspectra/src/builders/quality_builder.dart';
import 'package:inspectra/src/builders/trivy_builder.dart';

/// Checks the formatting when `format.run_on_build` is set.
Builder formatBuilder(BuilderOptions options) => const QualityBuilder.format();

/// Analyzes the package when `lint.run_on_build` is set.
Builder lintBuilder(BuilderOptions options) => const QualityBuilder.lint();

/// Writes the public API dump; see `api` in the configuration.
Builder apiBuilder(BuilderOptions options) => ApiBuilder.fromOptions(options);

/// Runs the secret scan when `trivy.secret.run_on_build` is set.
Builder secretScanBuilder(BuilderOptions options) =>
    const TrivyBuilder.secret();

/// Runs the license scan when `trivy.license.run_on_build` is set.
Builder licenseScanBuilder(BuilderOptions options) =>
    const TrivyBuilder.license();

/// Runs the vulnerability scan when `trivy.vulnerability.run_on_build` is set.
Builder vulnerabilityScanBuilder(BuilderOptions options) =>
    const TrivyBuilder.vulnerability();
