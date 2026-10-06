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

import 'package:inspectra/inspectra.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// Tests reading the `dependency_policy:` section of the configuration.
void main() {
  /// Parses the `dependency_policy:` section [section].
  DependencyPolicyConfig parse(Map<String, Object?>? section) =>
      InspectraConfig.parse(<String, Object?>{
        'dependency_policy': section,
      }, packageName: 'demo').dependencyPolicy;

  test('has defaults that check nothing', () {
    final DependencyPolicyConfig config = parse(null);
    expect(config.enabled, isFalse);
    expect(config.denied, isEmpty);
    expect(config.allowed, isEmpty);
    expect(config.requireUpperBound, isFalse);
    expect(config.minSdk, isNull);
    expect(config.unusedAllow, <String>['cupertino_icons']);
    expect(config.constraintStyle, ConstraintStyle.any);
    expect(config.overridesRequireReason, isFalse);
    expect(config.allowedOverrides, isEmpty);
    expect(config.lockfilePolicy, LockfilePolicy.any);
    expect(config.maxMajorBehind, isNull);
    expect(config.maxLibyear, isNull);
    expect(config.libyearScope, LibyearScope.direct);
    expect(config.hasOutdatedRules, isFalse);
  });

  test('reads every key', () {
    final DependencyPolicyConfig config = parse(<String, Object?>{
      'enabled': true,
      'denied': <Object?>[
        <String, Object?>{
          'name': 'left_pad',
          'reason': 'Unmaintained.',
          'replacement': 'string_padding',
        },
      ],
      'allowed': <String>['http'],
      'allowed_hosts': <String>['https://pub.corp/'],
      'allowed_git_hosts': <String>['git.corp'],
      'require_upper_bound': true,
      'min_sdk': '3.6.0',
      'min_flutter': '3.27.0',
      'dev_only': <String>['mockito'],
      'require_publish_to': true,
      'published_packages': <String>['open'],
      'required_metadata': <String>['Description', 'topics'],
      'lockfile_in_sync': true,
      'lockfile_checksums': true,
      'check_imports': true,
      'unused_allow': <String>[],
      'constraint_style': 'Caret',
      'overrides': <String, Object?>{
        'require_reason': true,
        'allowed': <Object?>[
          <String, Object?>{
            'name': 'intl',
            'reason': 'Flutter pins an older intl.',
            'expires': '2027-01-31',
          },
        ],
      },
      'lockfile_policy': 'auto',
      'max_major_behind': 1,
      'max_libyear': 12.5,
      'libyear_scope': 'all',
    });
    expect(config.enabled, isTrue);
    expect(config.denied.single.replacement, 'string_padding');
    expect(config.allowedHosts, <String>['https://pub.corp']);
    expect(config.minSdk, Version(3, 6, 0));
    expect(config.minFlutter, Version(3, 27, 0));
    expect(config.requiredMetadata, <String>['description', 'topics']);
    expect(config.unusedAllow, isEmpty);
    expect(config.checkImports, isTrue);
    expect(config.constraintStyle, ConstraintStyle.caret);
    expect(config.overridesRequireReason, isTrue);
    expect(config.allowedOverrides.single.name, 'intl');
    expect(
      config.allowedOverrides.single.isExpired(DateTime.utc(2027, 1, 31, 23)),
      isFalse,
    );
    expect(
      config.allowedOverrides.single.isExpired(DateTime.utc(2027, 2)),
      isTrue,
    );
    expect(config.lockfilePolicy, LockfilePolicy.auto);
    expect(config.maxMajorBehind, 1);
    expect(config.maxLibyear, 12.5);
    expect(config.libyearScope, LibyearScope.all);
    expect(config.hasOutdatedRules, isTrue);
  });

  test('rejects malformed values with the offending key', () {
    /// Expects [section] to fail at [path] with a [message].
    void rejects(Map<String, Object?> section, String path, String message) {
      expect(
        () => parse(section),
        throwsA(
          isA<InspectraConfigException>()
              .having((e) => e.path, 'path', path)
              .having((e) => e.message, 'message', contains(message)),
        ),
      );
    }

    rejects(
      <String, Object?>{'min_sdk': 'three'},
      'dependency_policy.min_sdk',
      'expected a version',
    );
    rejects(
      <String, Object?>{
        'denied': <Object?>[
          <String, Object?>{'name': 'x'},
        ],
      },
      'dependency_policy.denied[0].reason',
      'a reason is required',
    );
    rejects(
      <String, Object?>{
        'denied': <Object?>[
          <String, Object?>{'reason': 'x'},
        ],
      },
      'dependency_policy.denied[0].name',
      'a package name is required',
    );
    rejects(
      <String, Object?>{
        'denied': <Object?>[
          <String, Object?>{'name': 'x', 'reason': 'y', 'replacment': 'z'},
        ],
      },
      'dependency_policy.denied[0].replacment',
      'Did you mean "replacement"?',
    );
    rejects(
      <String, Object?>{'denied': 'x'},
      'dependency_policy.denied',
      'expected a list',
    );
    rejects(
      <String, Object?>{
        'denied': <Object?>['x'],
      },
      'dependency_policy.denied[0]',
      'expected a mapping',
    );
    rejects(
      <String, Object?>{
        'required_metadata': <String>['license'],
      },
      'dependency_policy.required_metadata[0]',
      'expected one of description',
    );
    rejects(
      <String, Object?>{'constraint_style': 'loose'},
      'dependency_policy.constraint_style',
      'expected one of any, caret, range, pinned',
    );
    rejects(
      <String, Object?>{
        'overrides': <String, Object?>{
          'allowed': <Object?>[
            <String, Object?>{'name': 'intl'},
          ],
        },
      },
      'dependency_policy.overrides.allowed[0].reason',
      'a reason is required',
    );
    rejects(
      <String, Object?>{
        'overrides': <String, Object?>{
          'allowed': <Object?>[
            <String, Object?>{'name': 'intl', 'reason': 'r', 'expires': 'soon'},
          ],
        },
      },
      'dependency_policy.overrides.allowed[0].expires',
      'expected a date',
    );
    rejects(
      <String, Object?>{
        'overrides': <String, Object?>{'require_reasons': true},
      },
      'dependency_policy.overrides.require_reasons',
      'Did you mean "require_reason"?',
    );
    rejects(
      <String, Object?>{'max_major_behind': -1},
      'dependency_policy.max_major_behind',
      'a whole number between 0 and 100',
    );
  });

  test('limits of the registry rules may only be tightened', () {
    final ConfigStrictness? order = ConfigStrictness.of(
      'dependency_policy.max_libyear',
    );
    expect(order, ConfigStrictness.lowerNumber);
    final double? five = order?.rankOf(5);
    final double? ten = order?.rankOf(10.0);
    final double? unset = order?.rankOf(null);
    expect(five, greaterThan(ten ?? 0));
    expect(ten, greaterThan(unset ?? 0));
    expect(
      ConfigStrictness.of('dependency_policy.overrides.require_reason'),
      ConfigStrictness.enabledFlag,
    );
  });
}
