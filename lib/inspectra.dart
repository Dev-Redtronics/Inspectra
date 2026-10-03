/// Security scans with Trivy, public API validation and a coverage gate for
/// Dart packages, driven by build_runner and a single YAML configuration.
///
/// Most packages only need Inspectra as a dev dependency and its
/// configuration; this library is for tooling that wants to run the checks
/// programmatically.
library;

export 'src/api/api_command.dart'
    show ApiCheckResult, checkApi, dumpApi, renderPackageApi;
export 'src/api/api_diff.dart' show diffApi;
export 'src/api/api_renderer.dart' show apiDumpHeader, renderApi;
export 'src/config/config_exception.dart';
export 'src/config/config_loader.dart';
export 'src/config/inspectra_config.dart';
export 'src/config/severity.dart';
export 'src/coverage/coverage_gate.dart';
export 'src/trivy/finding.dart';
export 'src/trivy/package_graph.dart';
export 'src/trivy/scans.dart';
export 'src/trivy/trivy.dart';
export 'src/trivy/trivy_command.dart';
