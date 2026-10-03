import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

void main() {
  test('reports no difference for equal dumps', () {
    expect(diffApi(expected: 'a\nb\n', actual: 'a\nb\n'), isNull);
  });

  test('ignores Windows line endings', () {
    expect(diffApi(expected: 'a\r\nb\r\n', actual: 'a\nb\n'), isNull);
  });

  test('shows a changed line with its context', () {
    final String? diff = diffApi(
      expected: 'a\nb\nc\nd\ne\nf\n',
      actual: 'a\nb\nC\nd\ne\nf\n',
    );

    expect(diff, '@@ -1,5 +1,5 @@\n a\n b\n-c\n+C\n d\n e');
  });

  test('shows an added line at the end', () {
    expect(
      diffApi(expected: 'a\nb\n', actual: 'a\nb\nc\n'),
      '@@ -1,3 +1,4 @@\n a\n b\n+c\n ',
    );
  });

  test('shows an added line at the start', () {
    expect(
      diffApi(expected: 'b\nc\nd\ne\n', actual: 'a\nb\nc\nd\ne\n'),
      '@@ -1,2 +1,3 @@\n+a\n b\n c',
    );
  });

  test('keeps distant changes in separate hunks', () {
    final String expected = List.generate(20, (i) => 'line $i').join('\n');
    final String actual = expected
        .replaceFirst('line 2\n', 'line two\n')
        .replaceFirst('line 15\n', 'line fifteen\n');

    final String diff = diffApi(expected: expected, actual: actual)!;

    expect(RegExp('^@@', multiLine: true).allMatches(diff), hasLength(2));
    expect(diff, contains('@@ -1,5 +1,5 @@\n line 0\n line 1\n-line 2\n'));
    expect(diff, contains('@@ -14,5 +14,5 @@\n line 13\n line 14\n'));
    expect(diff, isNot(contains('line 8')));
  });

  test('shows only the lines that changed, not everything in between', () {
    final String expected = [
      'class A {}',
      for (var i = 0; i < 50; i++) 'unchanged $i',
      'class Z {}',
    ].join('\n');
    final String actual = expected
        .replaceFirst('class A {}', 'class A2 {}')
        .replaceFirst('class Z {}', 'class Z2 {}');

    final String diff = diffApi(expected: expected, actual: actual)!;

    expect(diff, isNot(contains('unchanged 10')));
    expect(diff.split('\n').where((line) => line.startsWith('-')), [
      '-class A {}',
      '-class Z {}',
    ]);
  });

  test('truncates a diff with very many changed lines', () {
    final String added = List.generate(
      150,
      (index) => 'line $index',
    ).join('\n');
    final String diff = diffApi(expected: '', actual: added)!;

    expect(diff, contains('+line 118'));
    expect(diff, isNot(contains('+line 120')));
    expect(diff, contains('... and 31 more changed line(s)'));
  });
}
