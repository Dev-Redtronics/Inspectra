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
    });
    expect(config.enabled, isTrue);
    expect(config.denied.single.replacement, 'string_padding');
    expect(config.allowedHosts, <String>['https://pub.corp']);
    expect(config.minSdk, Version(3, 6, 0));
    expect(config.minFlutter, Version(3, 27, 0));
    expect(config.requiredMetadata, <String>['description', 'topics']);
    expect(config.unusedAllow, isEmpty);
    expect(config.checkImports, isTrue);
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
  });
}
