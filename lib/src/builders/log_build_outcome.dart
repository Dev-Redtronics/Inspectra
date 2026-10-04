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

import 'package:build/build.dart';

/// Logs the [rendered] result of a check run by `build_runner`.
///
/// A [failed] check is logged as severe, which fails the build; a check
/// with [findings] that does not fail is logged as a warning; a clean check
/// is logged at the fine level, visible with `--verbose`.
void logBuildOutcome(
  String rendered, {
  required bool failed,
  required bool findings,
}) {
  if (failed) {
    log.severe(rendered);
    return;
  }
  if (findings) {
    log.warning(rendered);
    return;
  }
  log.fine(rendered);
}
