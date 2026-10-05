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

import 'package:inspectra/src/api/api_change.dart';
import 'package:inspectra/src/api/api_change_kind.dart';
import 'package:inspectra/src/api/api_declaration.dart';
import 'package:inspectra/src/api/api_parameters.dart';
import 'package:inspectra/src/api/api_surface.dart';

/// Compares the public API [before] a change with the API [after] it and
/// decides for every difference whether it breaks consumers.
///
/// Removing anything breaks consumers, adding something does not, with two
/// exceptions: a new enum value breaks exhaustive `switch` statements, and
/// a new abstract member, or any new member of an interface class, breaks
/// the classes implementing it. A changed line breaks consumers unless it
/// only adds or removes `@Deprecated`, or only adds optional parameters to
/// a member nobody can override: a top-level function, a constructor, a
/// static member, an extension member, or a member of a final or sealed
/// class or an enum.
///
/// Returns the changes, ordered by library and name.
List<ApiChange> classifyApiChanges(ApiSurface before, ApiSurface after) {
  final changes = <ApiChange>[];
  for (final String library in _union(
    before.libraries.keys,
    after.libraries.keys,
  )) {
    final Map<String, ApiDeclaration>? old = before.libraries[library];
    final Map<String, ApiDeclaration>? current = after.libraries[library];
    if (current == null) {
      changes.add(
        ApiChange(
          kind: ApiChangeKind.breaking,
          library: library,
          declaration: '',
          reason: 'The library was removed or is no longer public.',
        ),
      );
      continue;
    }
    if (old == null) {
      changes.add(
        ApiChange(
          kind: ApiChangeKind.additive,
          library: library,
          declaration: '',
          reason: 'The library was added.',
        ),
      );
      continue;
    }
    for (final String name in _union(old.keys, current.keys)) {
      final ApiDeclaration? was = old[name];
      final ApiDeclaration? now = current[name];
      if (now == null) {
        changes.add(
          ApiChange(
            kind: ApiChangeKind.breaking,
            library: library,
            declaration: name,
            reason: 'The declaration was removed.',
            before: was?.line,
          ),
        );
        continue;
      }
      if (was == null) {
        changes.add(
          ApiChange(
            kind: ApiChangeKind.additive,
            library: library,
            declaration: name,
            reason: 'The declaration was added.',
            after: now.line,
          ),
        );
        continue;
      }
      changes.addAll(_declaration(library, was, now));
    }
  }
  return changes;
}

/// Compares the declaration [was] of [library] with [now].
///
/// Returns the changes.
List<ApiChange> _declaration(
  String library,
  ApiDeclaration was,
  ApiDeclaration now,
) {
  if (!was.isType && !now.isType) {
    return <ApiChange>[
      ?_line(library, now.name, null, was.line, now.line, closed: true),
    ];
  }
  if (was.isType != now.isType) {
    return <ApiChange>[
      ApiChange(
        kind: ApiChangeKind.breaking,
        library: library,
        declaration: now.name,
        reason: 'The declaration changed between a type and a member.',
        before: was.line,
        after: now.line,
      ),
    ];
  }
  final changes = <ApiChange>[];
  final ApiChange? header = _line(
    library,
    now.name,
    null,
    was.line,
    now.line,
    closed: false,
    changed:
        'The type declaration changed: its modifiers, type parameters, '
        'supertypes or representation.',
  );
  if (header != null) {
    changes.add(header);
  }
  for (final String value in was.values) {
    if (!now.values.contains(value)) {
      changes.add(
        ApiChange(
          kind: ApiChangeKind.breaking,
          library: library,
          declaration: now.name,
          member: value,
          reason: 'The enum value was removed.',
        ),
      );
    }
  }
  for (final String value in now.values) {
    if (!was.values.contains(value)) {
      changes.add(
        ApiChange(
          kind: ApiChangeKind.breaking,
          library: library,
          declaration: now.name,
          member: value,
          reason:
              'The enum value was added; switch statements over the enum '
              'without a default case no longer compile.',
        ),
      );
    }
  }
  final List<String> words = ApiSurface.withoutDeprecation(now.line).split(' ');
  final bool closed =
      words.contains('final') ||
      words.contains('sealed') ||
      words.contains('enum') ||
      words.contains('extension');
  final bool interface = words.contains('interface');
  for (final String member in _union(was.members.keys, now.members.keys)) {
    final String? old = was.members[member];
    final String? current = now.members[member];
    final bool unbound =
        member == now.name ||
        member.startsWith('${now.name}.') ||
        ApiSurface.withoutDeprecation(current ?? old ?? '')
            .startsWith('static ');
    if (current == null) {
      changes.add(
        ApiChange(
          kind: ApiChangeKind.breaking,
          library: library,
          declaration: now.name,
          member: member,
          reason: 'The member was removed.',
          before: old,
        ),
      );
      continue;
    }
    if (old == null) {
      changes.add(
        _added(
          library,
          now.name,
          member,
          current,
          closed: closed,
          interface: interface,
          unbound: unbound,
        ),
      );
      continue;
    }
    final ApiChange? change = _line(
      library,
      now.name,
      member,
      old,
      current,
      closed: closed || unbound,
    );
    if (change != null) {
      changes.add(change);
    }
  }
  return changes;
}

/// Describes the new [member] line [line] of the type [declaration]; a
/// [closed] type cannot be implemented outside its library, an
/// [interface] type is meant to be implemented, and an [unbound] member is
/// a constructor or static member.
///
/// Returns the change.
ApiChange _added(
  String library,
  String declaration,
  String member,
  String line, {
  required bool closed,
  required bool interface,
  required bool unbound,
}) {
  final bool isAbstract = ApiSurface.withoutDeprecation(line)
      .startsWith('abstract ');
  final bool breaksImplementers =
      !closed && !unbound && (isAbstract || interface);
  return ApiChange(
    kind: breaksImplementers ? ApiChangeKind.breaking : ApiChangeKind.additive,
    library: library,
    declaration: declaration,
    member: member,
    reason: breaksImplementers
        ? 'The member was added to a type that other classes implement; '
              'they must add it as well.'
        : 'The member was added.',
    after: line,
  );
}

/// Compares the line [was] of [member] of [declaration], or of the
/// declaration itself, with [now]; optional parameters may be added when
/// the member is [closed] to overriding. [changed] explains a breaking
/// change.
///
/// Returns the change, or `null` when the line is the same.
ApiChange? _line(
  String library,
  String declaration,
  String? member,
  String was,
  String now, {
  required bool closed,
  String changed = 'The signature changed.',
}) {
  if (was == now) {
    return null;
  }
  ApiChange change(ApiChangeKind kind, String reason) => ApiChange(
    kind: kind,
    library: library,
    declaration: declaration,
    member: member,
    reason: reason,
    before: was,
    after: now,
  );
  final String plainWas = ApiSurface.withoutDeprecation(was);
  final String plainNow = ApiSurface.withoutDeprecation(now);
  if (plainWas == plainNow) {
    return change(
      ApiChangeKind.additive,
      ApiSurface.isDeprecated(now)
          ? 'It was deprecated.'
          : 'It is no longer deprecated.',
    );
  }
  final ApiParameters? oldParameters = ApiParameters.of(plainWas);
  final ApiParameters? newParameters = ApiParameters.of(plainNow);
  final bool onlyOptional =
      oldParameters != null &&
      newParameters != null &&
      oldParameters.onlyAddsOptional(newParameters);
  if (onlyOptional && closed) {
    return change(
      ApiChangeKind.additive,
      'Only optional parameters were added.',
    );
  }
  if (onlyOptional) {
    return change(
      ApiChangeKind.breaking,
      'Optional parameters were added to a member that subclasses can '
      'override; their overrides no longer match.',
    );
  }
  final int wasValue = ApiSurface.topLevelIndexOf(plainWas, ' = ');
  final int nowValue = ApiSurface.topLevelIndexOf(plainNow, ' = ');
  final bool sameDeclaration =
      wasValue >= 0 &&
      nowValue >= 0 &&
      plainWas.substring(0, wasValue) == plainNow.substring(0, nowValue);
  return change(
    ApiChangeKind.breaking,
    sameDeclaration
        ? 'The value changed; constant expressions and switch patterns '
              'using it change or no longer compile.'
        : changed,
  );
}

/// Returns the keys of [a] and [b] without duplicates, sorted.
List<String> _union(Iterable<String> a, Iterable<String> b) =>
    <String>{...a, ...b}.toList()..sort();
