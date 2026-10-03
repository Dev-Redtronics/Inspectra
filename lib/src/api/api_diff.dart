import 'dart:typed_data';

/// The most changed lines shown before the diff is cut short.
const _maxReportedLines = 120;

/// The unchanged lines shown around each change.
const _contextLines = 2;

/// Above this many cells, the comparison table would cost too much memory,
/// and the changed region is shown as one removal and one addition instead.
const _maxTableCells = 4000000;

/// Describes how [actual] differs from [expected] in unified diff format, or
/// returns `null` when they are equal apart from line endings.
///
/// Only the lines that changed are shown, each hunk with
/// [_contextLines] unchanged lines around it and a header such as
/// `@@ -12,3 +12,4 @@` giving the line numbers in both versions - the same
/// form `git diff` uses, so a reviewer reads it without thinking.
String? diffApi({required String expected, required String actual}) {
  final List<String> before = _normalizeLineEndings(expected).split('\n');
  final List<String> after = _normalizeLineEndings(actual).split('\n');

  final List<_Line> lines = _compare(before, after);
  if (lines.every((line) => line.kind == _Kind.same)) {
    return null;
  }
  return _render(lines);
}

/// [text] with Windows and old Mac line endings replaced by `\n`, so that a
/// dump checked out with `core.autocrlf` still compares equal.
String _normalizeLineEndings(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

enum _Kind { same, removed, added }

class _Line {
  const _Line(this.kind, this.text, this.before, this.after);

  final _Kind kind;
  final String text;

  /// The 1-based line number in the expected text, for unchanged and removed
  /// lines; for an added line, the number of the line it follows.
  final int before;

  /// The 1-based line number in the actual text, for unchanged and added
  /// lines; for a removed line, the number of the line it follows.
  final int after;
}

/// Aligns [before] and [after] along their longest common subsequence.
List<_Line> _compare(List<String> before, List<String> after) {
  var start = 0;
  while (start < before.length &&
      start < after.length &&
      before[start] == after[start]) {
    start++;
  }
  var end = 0;
  while (end < before.length - start &&
      end < after.length - start &&
      before[before.length - 1 - end] == after[after.length - 1 - end]) {
    end++;
  }

  final List<String> oldMiddle = before.sublist(start, before.length - end);
  final List<String> newMiddle = after.sublist(start, after.length - end);
  final result = <_Line>[
    for (var i = 0; i < start; i++) _Line(_Kind.same, before[i], i + 1, i + 1),
  ];

  var oldLine = start;
  var newLine = start;
  for (final _Kind kind in _align(oldMiddle, newMiddle)) {
    switch (kind) {
      case _Kind.same:
        oldLine++;
        newLine++;
        result.add(_Line(kind, before[oldLine - 1], oldLine, newLine));
      case _Kind.removed:
        oldLine++;
        result.add(_Line(kind, before[oldLine - 1], oldLine, newLine));
      case _Kind.added:
        newLine++;
        result.add(_Line(kind, after[newLine - 1], oldLine, newLine));
    }
  }

  for (var i = 0; i < end; i++) {
    final int oldIndex = before.length - end + i;
    final int newIndex = after.length - end + i;
    result.add(_Line(_Kind.same, before[oldIndex], oldIndex + 1, newIndex + 1));
  }
  return result;
}

/// The edit script turning [before] into [after]: a classic dynamic
/// programming longest common subsequence, which is exact and fast enough
/// for the region between the common prefix and suffix of two dumps.
List<_Kind> _align(List<String> before, List<String> after) {
  final int rows = before.length;
  final int columns = after.length;
  if ((rows + 1) * (columns + 1) > _maxTableCells) {
    return [
      for (var i = 0; i < rows; i++) _Kind.removed,
      for (var i = 0; i < columns; i++) _Kind.added,
    ];
  }

  // lengths[i][j] is the length of the longest common subsequence of
  // before[i..] and after[j..].
  final List<Int32List> lengths = [
    for (var i = 0; i <= rows; i++) Int32List(columns + 1),
  ];
  for (int i = rows - 1; i >= 0; i--) {
    for (int j = columns - 1; j >= 0; j--) {
      lengths[i][j] = before[i] == after[j]
          ? lengths[i + 1][j + 1] + 1
          : (lengths[i + 1][j] >= lengths[i][j + 1]
                ? lengths[i + 1][j]
                : lengths[i][j + 1]);
    }
  }

  final script = <_Kind>[];
  var i = 0;
  var j = 0;
  while (i < rows && j < columns) {
    if (before[i] == after[j]) {
      script.add(_Kind.same);
      i++;
      j++;
    } else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
      script.add(_Kind.removed);
      i++;
    } else {
      script.add(_Kind.added);
      j++;
    }
  }
  for (; i < rows; i++) {
    script.add(_Kind.removed);
  }
  for (; j < columns; j++) {
    script.add(_Kind.added);
  }
  return script;
}

/// Groups the changed lines into hunks with their context.
String _render(List<_Line> lines) {
  final changed = <int>[
    for (var i = 0; i < lines.length; i++)
      if (lines[i].kind != _Kind.same) i,
  ];

  final hunks = <(int, int)>[];
  for (final index in changed) {
    final int from = index - _contextLines < 0 ? 0 : index - _contextLines;
    final int to = index + _contextLines >= lines.length
        ? lines.length - 1
        : index + _contextLines;
    if (hunks.isNotEmpty && from <= hunks.last.$2 + 1) {
      hunks.last = (hunks.last.$1, to);
    } else {
      hunks.add((from, to));
    }
  }

  final output = <String>[];
  var shown = 0;
  for (final (int from, int to) in hunks) {
    final List<_Line> hunk = lines.sublist(from, to + 1);
    final int oldCount = hunk.where((line) => line.kind != _Kind.added).length;
    final int newCount = hunk
        .where((line) => line.kind != _Kind.removed)
        .length;
    output.add(
      '@@ -${_start(hunk.first.before, oldCount)},$oldCount '
      '+${_start(hunk.first.after, newCount)},$newCount @@',
    );
    for (final line in hunk) {
      if (line.kind != _Kind.same && shown == _maxReportedLines) {
        final int remaining = changed.length - shown;
        output.add('... and $remaining more changed line(s)');
        return output.join('\n');
      }
      if (line.kind != _Kind.same) {
        shown++;
      }
      final String prefix = switch (line.kind) {
        _Kind.same => ' ',
        _Kind.removed => '-',
        _Kind.added => '+',
      };
      output.add('$prefix${line.text}');
    }
  }
  return output.join('\n');
}

/// The first line number of a hunk side, which is 0 for an empty side
/// starting before the first line, as in `git diff`.
int _start(int lineNumber, int count) =>
    count == 0 ? lineNumber : (lineNumber < 1 ? 1 : lineNumber);
