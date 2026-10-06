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
import 'package:inspectra/src/inspect/regex_rule.dart';
import 'package:inspectra/src/inspect/regex_rules.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/rules/rule_info.dart';
import 'package:inspectra/src/style/built_in_style_rules.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// The rules whose ids are fixed, apart from the regular expression rules
/// of the source inspector and the style rules, which describe themselves.
const _rules = <RuleInfo>[
  RuleInfo(
    id: 'WILDCARD_VERSION',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'A dependency accepts every version ("*")',
    explanation:
        'The next "dart pub upgrade" may pull in any release, '
        'including a compromised or breaking one. Give it a caret constraint '
        'such as ^1.2.0.',
  ),
  RuleInfo(
    id: 'ANY_VERSION',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'A dependency accepts every version ("any")',
    explanation:
        'The next "dart pub upgrade" may pull in any release, '
        'including a compromised or breaking one. Give it a caret constraint '
        'such as ^1.2.0. Packages of the same pub workspace are exempt.',
  ),
  RuleInfo(
    id: 'PATH_DEPENDENCY',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'A dependency comes from a local path',
    explanation:
        'A path dependency only resolves on machines with the same '
        'directory layout and bypasses the registry. Publish the package, use '
        'a pub workspace, or keep it in dev_dependencies.',
  ),
  RuleInfo(
    id: 'INSECURE_URL',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'A dependency source uses plain HTTP',
    explanation:
        'Anyone on the network path can replace the package. Use '
        'an https:// URL for hosted and Git sources.',
  ),
  RuleInfo(
    id: 'SUSPICIOUS_GIT_HOST',
    source: FindingSource.pubspec,
    severity: Severity.critical,
    summary: 'A Git dependency comes from an unusual host',
    explanation:
        'Code from paste sites, URL shorteners or file hosters is '
        'a common way to smuggle malware in. Depend on the package from its '
        'registry or its official repository.',
  ),
  RuleInfo(
    id: 'GIT_IP_ADDRESS',
    source: FindingSource.pubspec,
    severity: Severity.critical,
    summary: 'A Git dependency is fetched from a bare IP address',
    explanation:
        'A bare IP address hides who serves the code and cannot be '
        'verified with a certificate. Use the host name of the repository.',
  ),
  RuleInfo(
    id: 'GIT_BRANCH_REF',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'A Git dependency follows a branch',
    explanation:
        'A branch moves: every resolution can fetch other code. '
        'Pin the dependency to a tag or a commit with ref:.',
  ),
  RuleInfo(
    id: 'DEPENDENCY_OVERRIDE',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary:
        'A dependency_overrides entry replaces normal version '
        'resolution',
    explanation:
        'An override forces a version every other package did not '
        'agree on and hides incompatibilities. Remove it, or justify it in '
        'dependency_policy.overrides.allowed.',
  ),
  RuleInfo(
    id: 'OLD_SDK_CONSTRAINT',
    source: FindingSource.pubspec,
    severity: Severity.low,
    summary: 'The SDK constraint allows very old Dart versions',
    explanation:
        'Old SDKs lack null safety and current language features, '
        'and are no longer tested. Raise the lower bound of environment.sdk.',
  ),
  RuleInfo(
    id: 'DENIED_PACKAGE',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'A denied package is declared or pulled in transitively',
    explanation:
        'dependency_policy.denied forbids the package, with a '
        'reason and maybe a replacement. Remove it, or replace the dependency '
        'that pulls it in.',
  ),
  RuleInfo(
    id: 'PACKAGE_NOT_ALLOWED',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'A hosted dependency is not on the allowed list',
    explanation:
        'dependency_policy.allowed names the only hosted packages '
        'that may be used. Use an allowed package, or get this one approved '
        'and added to the list.',
  ),
  RuleInfo(
    id: 'DISALLOWED_HOST',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary:
        'A package comes from a registry or Git host that is not '
        'allowed',
    explanation:
        'dependency_policy.allowed_hosts and allowed_git_hosts '
        'name the only sources. Take the package from an approved registry or '
        'mirror.',
  ),
  RuleInfo(
    id: 'MISSING_UPPER_BOUND',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'A hosted constraint has no upper bound',
    explanation:
        'A constraint such as >=1.2.0 accepts the next breaking '
        'release. Use ^1.2.0; "inspectra deps --fix" applies it.',
  ),
  RuleInfo(
    id: 'SDK_BELOW_POLICY',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'The SDK constraint allows SDKs below the policy minimum',
    explanation:
        'dependency_policy.min_sdk or min_flutter sets the lowest '
        'supported SDK. Raise the lower bound of environment.sdk or '
        'environment.flutter.',
  ),
  RuleInfo(
    id: 'DEV_ONLY_DEPENDENCY',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'A development package is a runtime dependency',
    explanation:
        'Every user of the package resolves its runtime '
        'dependencies. Move it to dev_dependencies; "inspectra deps --fix" '
        'does.',
  ),
  RuleInfo(
    id: 'MISSING_PUBLISH_TO',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'The package can be published to pub.dev by accident',
    explanation:
        'Without publish_to, "dart pub publish" uploads it to '
        'pub.dev. Add "publish_to: none", or list the package in '
        'dependency_policy.published_packages.',
  ),
  RuleInfo(
    id: 'MISSING_METADATA',
    source: FindingSource.pubspec,
    severity: Severity.low,
    summary: 'A publishable package lacks a metadata field',
    explanation:
        'dependency_policy.required_metadata names the fields '
        'every published package declares, such as repository and '
        'issue_tracker. Add the field to pubspec.yaml.',
  ),
  RuleInfo(
    id: 'LOCKFILE_OUT_OF_SYNC',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'pubspec.lock does not match pubspec.yaml',
    explanation:
        'A dependency is missing from the lockfile, locked outside '
        'its constraint, or removed but still locked. Run "dart pub get" and '
        'commit the lockfile.',
  ),
  RuleInfo(
    id: 'MISSING_CHECKSUM',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'A hosted package of pubspec.lock has no checksum',
    explanation:
        'Without sha256, a changed archive cannot be detected. Run '
        '"dart pub get" with a current SDK to record the checksums.',
  ),
  RuleInfo(
    id: 'UNUSED_DEPENDENCY',
    source: FindingSource.pubspec,
    severity: Severity.low,
    summary: 'A dependency is never imported',
    explanation:
        'No file of lib/ or bin/ imports it; maybe only tests use '
        'it. Remove it, move it to dev_dependencies, or list it in '
        'dependency_policy.unused_allow.',
  ),
  RuleInfo(
    id: 'DEV_DEPENDENCY_IN_LIB',
    source: FindingSource.pubspec,
    severity: Severity.high,
    summary: 'lib/ or bin/ imports a development dependency',
    explanation:
        'The users of the package do not get dev_dependencies, so '
        'the import fails for them. Move the package to dependencies.',
  ),
  RuleInfo(
    id: 'CONSTRAINT_STYLE',
    source: FindingSource.pubspec,
    severity: Severity.low,
    summary: 'A hosted constraint is not written in the configured style',
    explanation:
        'dependency_policy.constraint_style asks for caret, range '
        'or exact constraints. Rewrite it; "inspectra deps --fix" rewrites '
        'caret and range constraints.',
  ),
  RuleInfo(
    id: 'UNJUSTIFIED_OVERRIDE',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'A dependency override has no valid justification',
    explanation:
        'dependency_policy.overrides.require_reason asks for an '
        'entry in overrides.allowed with a reason. Add one with an expiry '
        'date, or remove the override.',
  ),
  RuleInfo(
    id: 'LOCKFILE_POLICY',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'pubspec.lock is committed against the policy',
    explanation:
        'Applications commit pubspec.lock so that builds are '
        'reproducible; published packages do not, because their users resolve '
        'them. Follow dependency_policy.lockfile_policy.',
  ),
  RuleInfo(
    id: 'OUTDATED_MAJOR',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'A direct dependency is too many breaking releases behind',
    explanation:
        'dependency_policy.max_major_behind limits how far a '
        'dependency may lag. Upgrade with "dart pub upgrade --major-versions '
        '<package>".',
  ),
  RuleInfo(
    id: 'LIBYEAR_EXCEEDED',
    source: FindingSource.pubspec,
    severity: Severity.medium,
    summary: 'The dependencies are too many libyears behind',
    explanation:
        'A libyear is a year between the locked and the latest '
        'release of a dependency; dependency_policy.max_libyear limits their '
        'sum. Upgrade the largest contributors.',
  ),
  RuleInfo(
    id: 'LEVENSHTEIN_1',
    source: FindingSource.typosquat,
    severity: Severity.critical,
    summary: 'The name is one edit away from a popular package',
    explanation:
        'Typosquatters publish packages whose names differ from '
        'popular ones by a single character. Check that you meant this package '
        'and not the popular one.',
  ),
  RuleInfo(
    id: 'LEVENSHTEIN_2',
    source: FindingSource.typosquat,
    severity: Severity.high,
    summary: 'The name is two edits away from a popular package',
    explanation:
        'Typosquatters publish lookalike names of popular '
        'packages. Check that you meant this package.',
  ),
  RuleInfo(
    id: 'PREFIX_FLUTTER',
    source: FindingSource.typosquat,
    severity: Severity.high,
    summary: 'The name adds a flutter_ prefix to a popular package',
    explanation:
        'Prefixing a known name is a common confusion attack. '
        'Check the publisher and that this is the package you meant.',
  ),
  RuleInfo(
    id: 'SUFFIX_FLUTTER',
    source: FindingSource.typosquat,
    severity: Severity.high,
    summary: 'The name adds a _flutter suffix to a popular package',
    explanation:
        'Suffixing a known name is a common confusion attack. '
        'Check the publisher and that this is the package you meant.',
  ),
  RuleInfo(
    id: 'PREFIX_DART_PUB',
    source: FindingSource.typosquat,
    severity: Severity.high,
    summary: 'The name adds a dart_ or pub_ prefix to a popular package',
    explanation:
        'The prefix suggests an official package. Check the '
        'publisher and that this is the package you meant.',
  ),
  RuleInfo(
    id: 'SUSPICIOUS_SUFFIX',
    source: FindingSource.typosquat,
    severity: Severity.medium,
    summary: 'The name adds a suspicious suffix to a popular package',
    explanation:
        'Suffixes such as _utils or _plus on a known name are used '
        'to imitate it. Check the publisher.',
  ),
  RuleInfo(
    id: 'DEPENDENCY_CONFUSION',
    source: FindingSource.confusion,
    severity: Severity.high,
    summary: 'An internal package name also exists on pub.dev',
    explanation:
        'A resolver that asks the public registry may install the '
        'public package instead of the internal one. Pin the hosted URL of '
        'internal packages, or reserve the name.',
  ),
  RuleInfo(
    id: 'SUSPICIOUS_VERSION',
    source: FindingSource.confusion,
    severity: Severity.medium,
    summary: 'A public package claims a suspiciously high version',
    explanation:
        'Attackers publish huge version numbers so that resolvers '
        'prefer their package over the internal one. Pin the hosted URL of the '
        'dependency.',
  ),
  RuleInfo(
    id: 'FRESH_PACKAGE',
    source: FindingSource.trust,
    severity: Severity.critical,
    summary: 'The package was published only days ago',
    explanation:
        'Malicious packages are usually removed within days. Wait, '
        'and review the source with "inspectra inspect".',
  ),
  RuleInfo(
    id: 'FRESH_RELEASE',
    source: FindingSource.trust,
    severity: Severity.critical,
    summary: 'The version was released only hours ago',
    explanation:
        'A compromised maintainer account publishes a malicious '
        'release that is retracted soon after. Wait before upgrading.',
  ),
  RuleInfo(
    id: 'YOUNG_PACKAGE',
    source: FindingSource.trust,
    severity: Severity.medium,
    summary: 'The package is only weeks old',
    explanation:
        'Young packages have few users who would notice malicious '
        'code. Review the source with "inspectra inspect".',
  ),
  RuleInfo(
    id: 'UNVERIFIED_PUBLISHER',
    source: FindingSource.trust,
    severity: Severity.high,
    summary: 'The package has no verified publisher',
    explanation:
        'A verified publisher ties the package to a domain its '
        'owner controls. Prefer packages of verified publishers.',
  ),
  RuleInfo(
    id: 'RETRACTED_VERSION',
    source: FindingSource.trust,
    severity: Severity.high,
    summary: 'The version was retracted by its publisher',
    explanation:
        'Publishers retract versions that are broken or dangerous. '
        'Use another version.',
  ),
  RuleInfo(
    id: 'DISCONTINUED',
    source: FindingSource.trust,
    severity: Severity.high,
    summary: 'The package is discontinued',
    explanation:
        'It will not get fixes, including security fixes. Move to '
        'its replacement or an alternative.',
  ),
  RuleInfo(
    id: 'LOW_LIKES',
    source: FindingSource.trust,
    severity: Severity.medium,
    summary: 'The package has very few likes',
    explanation:
        'Few likes mean few users who would notice problems. '
        'Review it before depending on it.',
  ),
  RuleInfo(
    id: 'LOW_DOWNLOADS',
    source: FindingSource.trust,
    severity: Severity.medium,
    summary: 'The package has very few downloads',
    explanation:
        'Few downloads mean few users who would notice problems. '
        'Review it before depending on it.',
  ),
  RuleInfo(
    id: 'LOW_QUALITY_SCORE',
    source: FindingSource.trust,
    severity: Severity.medium,
    summary: 'The package has a low pub points score',
    explanation:
        'Low pub points hint at missing documentation, analysis '
        'issues or outdated dependencies.',
  ),
  RuleInfo(
    id: 'PATH_TRAVERSAL',
    source: FindingSource.archive,
    severity: Severity.critical,
    summary: 'An archive entry escapes the package directory',
    explanation:
        'An entry such as ../../.bashrc writes outside the package '
        'when extracted. Do not use the package.',
  ),
  RuleInfo(
    id: 'ABSOLUTE_PATH',
    source: FindingSource.archive,
    severity: Severity.critical,
    summary: 'An archive entry has an absolute path',
    explanation:
        'An absolute path writes anywhere on the machine when '
        'extracted. Do not use the package.',
  ),
  RuleInfo(
    id: 'OVERLONG_NAME',
    source: FindingSource.archive,
    severity: Severity.high,
    summary: 'An archive entry has an overlong name',
    explanation:
        'Overlong names crash or confuse extractors and hide '
        'files. Treat the package as suspicious.',
  ),
  RuleInfo(
    id: 'SPECIAL_FILE',
    source: FindingSource.archive,
    severity: Severity.high,
    summary: 'The archive contains a device file or pipe',
    explanation:
        'A Dart package has no reason to ship special files. Treat '
        'the package as suspicious.',
  ),
  RuleInfo(
    id: 'SETUID_BIT',
    source: FindingSource.archive,
    severity: Severity.high,
    summary: 'An archive entry has the setuid or setgid bit',
    explanation:
        'Such files run with the rights of their owner. A Dart '
        'package has no reason to ship them.',
  ),
  RuleInfo(
    id: 'HIDDEN_EXECUTABLE',
    source: FindingSource.archive,
    severity: Severity.high,
    summary: 'The archive contains a hidden executable',
    explanation:
        'Hidden executables are a way to smuggle in code that runs '
        'outside of Dart. Review why the package ships it.',
  ),
  RuleInfo(
    id: 'NATIVE_BINARY',
    source: FindingSource.archive,
    severity: Severity.medium,
    summary: 'The archive contains a native binary',
    explanation:
        'Native code cannot be reviewed like Dart code. Check that '
        'the package is expected to ship binaries.',
  ),
  RuleInfo(
    id: 'BUILD_HOOK',
    source: FindingSource.archive,
    severity: Severity.medium,
    summary: 'The package has a build hook',
    explanation:
        'hook/build.dart runs on every build of every user. Review '
        'what it does.',
  ),
  RuleInfo(
    id: 'LINK_ENTRY',
    source: FindingSource.archive,
    severity: Severity.high,
    summary: 'The archive contains a symbolic or hard link',
    explanation:
        'Links can point outside the package and overwrite files '
        'when extracted. Treat the package as suspicious.',
  ),
  RuleInfo(
    id: 'DUPLICATE_ENTRY',
    source: FindingSource.archive,
    severity: Severity.high,
    summary: 'The archive contains the same path twice',
    explanation:
        'Duplicates let a reviewed file be replaced by another one '
        'on extraction. Treat the package as suspicious.',
  ),
  RuleInfo(
    id: 'CASE_COLLISION',
    source: FindingSource.archive,
    severity: Severity.medium,
    summary: 'Two archive entries differ only in case',
    explanation:
        'On case-insensitive file systems one replaces the other, '
        'so what runs differs from what was reviewed.',
  ),
  RuleInfo(
    id: 'MALFORMED_PUBSPEC',
    source: FindingSource.archive,
    severity: Severity.high,
    summary: 'The published pubspec.yaml cannot be read',
    explanation:
        'A package whose pubspec cannot be parsed cannot be '
        'checked. Treat it as suspicious.',
  ),
  RuleInfo(
    id: 'BIDI_OVERRIDE',
    source: FindingSource.unicode,
    severity: Severity.critical,
    summary: 'The source contains bidirectional control characters',
    explanation:
        'Trojan Source: the code that runs differs from the code a '
        'reviewer sees. Remove the characters.',
  ),
  RuleInfo(
    id: 'ZERO_WIDTH',
    source: FindingSource.unicode,
    severity: Severity.high,
    summary: 'The source contains zero-width characters',
    explanation:
        'Invisible characters make identifiers that look the same '
        'differ. Remove them.',
  ),
  RuleInfo(
    id: 'TAG_CHARACTER',
    source: FindingSource.unicode,
    severity: Severity.critical,
    summary: 'The source contains Unicode tag characters',
    explanation:
        'Tag characters are invisible and can carry hidden data or '
        'instructions. Remove them.',
  ),
  RuleInfo(
    id: 'PUA_CARRIER',
    source: FindingSource.unicode,
    severity: Severity.critical,
    summary: 'The source contains private use characters',
    explanation:
        'Private use characters can carry hidden payloads. Remove '
        'them.',
  ),
  RuleInfo(
    id: 'HOMOGLYPH',
    source: FindingSource.unicode,
    severity: Severity.high,
    summary: 'An identifier mixes scripts that look alike',
    explanation:
        'A Cyrillic letter can look like a Latin one but names '
        'another identifier. Use one script.',
  ),
  RuleInfo(
    id: 'HIGH_ENTROPY_STRING',
    source: FindingSource.entropy,
    severity: Severity.medium,
    summary: 'A string literal looks random',
    explanation:
        'High entropy strings are often secrets or encoded '
        'payloads. Check what it is; move secrets out of the source.',
  ),
  RuleInfo(
    id: 'CONFIG_INSECURE_URL',
    source: FindingSource.config,
    severity: Severity.high,
    summary: 'A service URL of the configuration uses plain HTTP',
    explanation:
        'Advisories, package metadata and Trivy releases read over '
        'HTTP can be changed on the network path. Use https://.',
  ),
  RuleInfo(
    id: 'CONFIG_UNKNOWN_VARIABLE',
    source: FindingSource.config,
    severity: Severity.medium,
    summary: 'An INSPECTRA_* variable names no option',
    explanation:
        'The variable is ignored, so the option keeps its default. '
        'Fix the name; the finding suggests the closest one.',
  ),
  RuleInfo(
    id: 'CONFIG_TRIVY_DISABLED',
    source: FindingSource.config,
    severity: Severity.medium,
    summary: 'trivy.mode is disabled',
    explanation:
        'No secret, license or vulnerability scan runs. Use auto '
        'or required.',
  ),
  RuleInfo(
    id: 'CONFIG_UNPINNED_TRIVY',
    source: FindingSource.config,
    severity: Severity.medium,
    summary: 'trivy.version is latest',
    explanation:
        'Runs of the same commit use different Trivy releases and '
        'can disagree. Pin a version.',
  ),
  RuleInfo(
    id: 'CONFIG_IGNORE_EXPIRED',
    source: FindingSource.config,
    severity: Severity.medium,
    summary: 'An ignore rule has expired',
    explanation:
        'It no longer suppresses anything. Fix the finding, or '
        'renew the rule with a new date and reason.',
  ),
  RuleInfo(
    id: 'CONFIG_IGNORE_WITHOUT_EXPIRY',
    source: FindingSource.config,
    severity: Severity.low,
    summary: 'An ignore rule has no expiry date',
    explanation:
        'Suppressions without an end stay forever. Add expires: '
        'YYYY-MM-DD.',
  ),
  RuleInfo(
    id: 'CONFIG_GATE_NOT_FAILING',
    source: FindingSource.config,
    severity: Severity.low,
    summary: 'An enabled check never fails',
    explanation:
        'fail_on_findings: false or lint.fail_on: none reports '
        'problems without stopping anything.',
  ),
  RuleInfo(
    id: 'CONFIG_MIN_SEVERITY',
    source: FindingSource.config,
    severity: Severity.low,
    summary: 'min_severity hides findings from every report',
    explanation:
        'Hidden findings are never decided about. Prefer fail_on '
        'to decide what fails, and ignore rules for what is accepted.',
  ),
  RuleInfo(
    id: 'CONFIG_NO_COVERAGE_THRESHOLD',
    source: FindingSource.config,
    severity: Severity.low,
    summary: 'The coverage gate has no threshold',
    explanation: 'Without coverage.min_line_coverage the gate never fails.',
  ),
  RuleInfo(
    id: 'CONFIG_BASELINE_UNBOUNDED',
    source: FindingSource.config,
    severity: Severity.low,
    summary: 'The baseline may cover findings of any severity',
    explanation:
        'Set baseline.max_severity, for example to high, so that a '
        'recorded critical finding still fails.',
  ),
  RuleInfo(
    id: 'CONFIG_PUBSPEC_SECTION_IGNORED',
    source: FindingSource.config,
    severity: Severity.medium,
    summary: 'The inspectra: section of pubspec.yaml is ignored',
    explanation:
        'A configuration file replaces the section completely. '
        'Move the settings into one place.',
  ),
  RuleInfo(
    id: 'CONFIG_DEPRECATED_OPTION',
    source: FindingSource.config,
    severity: Severity.low,
    summary: 'The configuration uses the old name of a renamed option',
    explanation:
        'The old name works until the next major version. Run '
        '"inspectra config migrate".',
  ),
  RuleInfo(
    id: 'UNFORMATTED',
    source: FindingSource.quality,
    severity: Severity.low,
    summary: 'A file is not formatted with dart format',
    explanation: 'Run "inspectra format --fix" or "dart format".',
  ),
  RuleInfo(
    id: 'API_CHANGED',
    source: FindingSource.quality,
    severity: Severity.medium,
    summary: 'The public API differs from the committed dump',
    explanation:
        'Review the change; run "inspectra api dump" when it is '
        'deliberate, and mention it in the changelog.',
  ),
  RuleInfo(
    id: 'API_DUMP_MISSING',
    source: FindingSource.quality,
    severity: Severity.medium,
    summary: 'The public API dump is missing',
    explanation: 'Run "inspectra api dump" and commit the file.',
  ),
  RuleInfo(
    id: 'CHANGELOG_PROBLEM',
    source: FindingSource.quality,
    severity: Severity.medium,
    summary: 'The changelog is malformed or misses the version',
    explanation:
        'Document the version of pubspec.yaml in CHANGELOG.md, or '
        'run "inspectra changelog generate --write".',
  ),
  RuleInfo(
    id: 'COVERAGE_BELOW_THRESHOLD',
    source: FindingSource.quality,
    severity: Severity.medium,
    summary: 'Line coverage is below the threshold',
    explanation:
        'Add tests for the uncovered lines, or lower '
        'coverage.min_line_coverage deliberately.',
  ),
  RuleInfo(
    id: 'SEMVER_VIOLATION',
    source: FindingSource.quality,
    severity: Severity.high,
    summary: 'The version does not make the step the API changes need',
    explanation:
        'Breaking changes need a major, additions a minor version. '
        'Raise the version of pubspec.yaml.',
  ),
  RuleInfo(
    id: 'SEMVER_UNDECLARED_BREAKING',
    source: FindingSource.quality,
    severity: Severity.medium,
    summary: 'A breaking API change is not announced in a commit',
    explanation:
        'Mark the commit with "!" or a BREAKING CHANGE footer, so '
        'that the changelog names it.',
  ),
  RuleInfo(
    id: 'WORKSPACE_MEMBER_MISSING',
    source: FindingSource.workspace,
    severity: Severity.high,
    summary:
        'A workspace entry names no package, or a package is not '
        'listed',
    explanation:
        '"dart pub get" fails for the workspace. Fix the '
        'workspace: list.',
  ),
  RuleInfo(
    id: 'WORKSPACE_RESOLUTION_MISSING',
    source: FindingSource.workspace,
    severity: Severity.high,
    summary: 'A listed package is not resolved by the workspace',
    explanation:
        'Add "resolution: workspace" to its pubspec.yaml, so that '
        'it shares the workspace lockfile.',
  ),
  RuleInfo(
    id: 'WORKSPACE_VERSION_MISMATCH',
    source: FindingSource.workspace,
    severity: Severity.medium,
    summary: 'The packages constrain a dependency differently',
    explanation:
        'workspace_policy.align_versions asks for compatible or '
        'identical constraints. Align them; the finding names the most common '
        'one.',
  ),
  RuleInfo(
    id: 'WORKSPACE_SDK_MISMATCH',
    source: FindingSource.workspace,
    severity: Severity.medium,
    summary: 'A package has another SDK constraint than the root',
    explanation:
        'workspace_policy.same_sdk asks every package for the '
        'environment.sdk of the root.',
  ),
  RuleInfo(
    id: 'DEPENDENCY_CYCLE',
    source: FindingSource.workspace,
    severity: Severity.high,
    summary: 'Packages of the workspace depend on each other in a cycle',
    explanation:
        'None of them can be built, tested or released alone. Move '
        'what they share into a package they all depend on.',
  ),
  RuleInfo(
    id: 'LAYER_VIOLATION',
    source: FindingSource.workspace,
    severity: Severity.high,
    summary: 'A package depends on a layer it may not use',
    explanation:
        'workspace_policy.layers sets which layers may depend on '
        'which, and isolated layers forbid dependencies within. Invert or move '
        'the dependency.',
  ),
  RuleInfo(
    id: 'FORBIDDEN_DEPENDENCY',
    source: FindingSource.workspace,
    severity: Severity.high,
    summary: 'A package depends on a package its layer forbids',
    explanation:
        'workspace_policy.layers forbids it, for example Flutter '
        'in a pure Dart domain layer. Remove the dependency.',
  ),
  RuleInfo(
    id: 'LAYER_UNASSIGNED',
    source: FindingSource.workspace,
    severity: Severity.low,
    summary: 'A package belongs to no layer',
    explanation:
        'No layer rule applies to it. Add its directory to a layer '
        'of workspace_policy.layers.',
  ),
];

/// Every rule with a fixed id: the rules above, the regular expression
/// rules of the source inspector and the built-in style rules.
///
/// Returns the rules, sorted by id.
List<RuleInfo> ruleCatalog() {
  final rules = <RuleInfo>[
    ..._rules,
    for (final RegexRule rule in RegexRules.all)
      RuleInfo(
        id: rule.id,
        source: FindingSource.regex,
        severity: rule.severity,
        summary: rule.description,
        explanation:
            'The source inspector found code that matches this pattern in a '
            'package. It is common in malware; review what the code does '
            'before depending on the package.',
      ),
    for (final StyleRule rule in builtInStyleRules())
      RuleInfo(
        id: rule.id,
        source: FindingSource.style,
        severity: Severity.low,
        summary: rule.description,
        explanation:
            'A built-in style rule, switched with style.rules.${rule.id}. '
            'Suppress a single line with "// inspectra: ignore-style '
            '${rule.id}".',
      ),
  ];
  return rules..sort((a, b) => a.id.compareTo(b.id));
}

/// Finds the rule [id] in the [ruleCatalog], in any case.
///
/// Returns the rule, or `null` when no rule has that id.
RuleInfo? findRule(String id) {
  final String wanted = id.trim().toUpperCase();
  return ruleCatalog()
      .where((rule) => rule.id.toUpperCase() == wanted)
      .firstOrNull;
}
