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

import 'package:pub_semver/pub_semver.dart';

/// Parses the version [constraint] of a hosted dependency.
///
/// Returns the constraint, or `null` when it is absent, `any`, `*` or
/// malformed, which other rules report.
VersionConstraint? parseConstraint(String? constraint) {
  if (constraint == null || constraint == 'any' || constraint == '*') {
    return null;
  }
  try {
    return VersionConstraint.parse(constraint);
  } on FormatException {
    return null;
  }
}

/// Bounds the [constraint] of a hosted dependency that has a lower but no
/// upper bound, like `>=1.2.0`, below the next breaking version.
///
/// Returns the bounded constraint - the caret constraint `^1.2.0` for an
/// inclusive lower bound, otherwise `>1.2.0 <2.0.0` - or `null` when the
/// constraint already has an upper bound or cannot be bounded.
String? boundedConstraint(String? constraint) {
  final VersionConstraint? parsed = parseConstraint(constraint);
  if (parsed is! VersionRange || parsed.max != null) {
    return null;
  }
  final Version? min = parsed.min;
  if (min == null) {
    return null;
  }
  if (parsed.includeMin) {
    return '^$min';
  }
  return '>$min <${min.nextBreaking}';
}

/// Returns the lowest version [constraint] allows, or `null` when it has
/// no lower bound or is malformed.
Version? lowerBound(String? constraint) {
  final VersionConstraint? parsed = parseConstraint(constraint);
  return parsed is VersionRange ? parsed.min : null;
}
