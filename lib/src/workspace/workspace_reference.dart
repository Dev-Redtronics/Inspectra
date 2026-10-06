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

import 'package:inspectra/src/model/finding.dart';

/// The pubspec rules about version constraints, which do not apply to the
/// packages of the same workspace: pub resolves those to the workspace's
/// own copy whatever the constraint says.
const _constraintRules = <String>{'ANY_VERSION', 'WILDCARD_VERSION'};

/// Whether [finding] is a constraint rule about one of the [siblings], the
/// packages of the workspace the checked package belongs to.
///
/// Returns `true` when the finding does not apply.
bool isWorkspaceReference(Finding finding, Set<String> siblings) =>
    _constraintRules.contains(finding.ruleId) &&
    siblings.contains(finding.packageName);
