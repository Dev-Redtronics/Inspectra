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

import 'package:pub_semver/pub_semver.dart';

/// Matches a date in the form `YYYY-MM-DD`.
final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses [text] as a semantic version, ignoring a leading `v`.
///
/// Returns the version, or `null` when [text] is none.
Version? tryParseVersion(String text) {
  final String plain = text.startsWith('v') ? text.substring(1) : text;
  try {
    return Version.parse(plain);
  } on FormatException {
    return null;
  }
}

/// Whether [text] is a calendar date in the form `YYYY-MM-DD`.
///
/// Returns `false` for other forms and for days that do not exist, such
/// as `2026-02-30`.
bool isIsoDate(String text) {
  final RegExpMatch? match = _isoDate.firstMatch(text);
  if (match == null) {
    return false;
  }
  final int year = int.parse(match[1] ?? '');
  final int month = int.parse(match[2] ?? '');
  final int day = int.parse(match[3] ?? '');
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

/// Formats [date] as `YYYY-MM-DD`.
///
/// Returns the formatted date.
String formatIsoDate(DateTime date) {
  final String year = '${date.year}'.padLeft(4, '0');
  final String month = '${date.month}'.padLeft(2, '0');
  final String day = '${date.day}'.padLeft(2, '0');
  return '$year-$month-$day';
}
