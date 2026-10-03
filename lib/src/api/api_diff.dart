/// The most lines shown per side of a diff.
const _maxReportedLines = 60;

/// Describes how [actual] differs from [expected], or returns `null` when
/// they are equal apart from line endings.
///
/// The common leading and trailing lines are cut away and the rest is shown
/// as removed (`-`) and added (`+`) lines, which is all a reviewer needs to
/// see what changed in a dump that is sorted anyway.
String? diffApi({required String expected, required String actual}) {
  final List<String> expectedLines = normalizeLineEndings(expected).split('\n');
  final List<String> actualLines = normalizeLineEndings(actual).split('\n');

  var start = 0;
  final int maxStart = expectedLines.length < actualLines.length
      ? expectedLines.length
      : actualLines.length;
  while (start < maxStart && expectedLines[start] == actualLines[start]) {
    start++;
  }
  if (start == expectedLines.length && start == actualLines.length) {
    return null;
  }

  var fromEnd = 0;
  final int maxFromEnd = maxStart - start;
  while (fromEnd < maxFromEnd &&
      expectedLines[expectedLines.length - 1 - fromEnd] ==
          actualLines[actualLines.length - 1 - fromEnd]) {
    fromEnd++;
  }

  final List<String> removed = expectedLines.sublist(
    start,
    expectedLines.length - fromEnd,
  );
  final List<String> added = actualLines.sublist(
    start,
    actualLines.length - fromEnd,
  );
  final buffer = StringBuffer('@@ line ${start + 1} @@\n');
  _appendSection(buffer, '-', removed);
  _appendSection(buffer, '+', added);
  return buffer.toString().trimRight();
}

/// [text] with Windows and old Mac line endings replaced by `\n`, so that a
/// dump checked out with `core.autocrlf` still compares equal.
String normalizeLineEndings(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

void _appendSection(StringBuffer buffer, String prefix, List<String> lines) {
  for (final String line in lines.take(_maxReportedLines)) {
    buffer.writeln('$prefix$line');
  }
  if (lines.length > _maxReportedLines) {
    buffer.writeln(
      '$prefix... and ${lines.length - _maxReportedLines} more line(s)',
    );
  }
}
