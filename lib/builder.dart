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
