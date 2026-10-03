import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

void main() {
  test('reports no difference for equal dumps', () {
    expect(diffApi(expected: 'a\nb\n', actual: 'a\nb\n'), isNull);
  });

  test('ignores Windows line endings', () {
    expect(diffApi(expected: 'a\r\nb\r\n', actual: 'a\nb\n'), isNull);
  });

  test('shows only the changed lines', () {
    final String? diff = diffApi(
      expected: 'a\nb\nc\nd\n',
      actual: 'a\nB\nc\nd\n',
    );

    expect(diff, '@@ line 2 @@\n-b\n+B');
  });

  test('shows added lines at the end', () {
    expect(diffApi(expected: 'a\n', actual: 'a\nb\n'), '@@ line 2 @@\n+b');
  });

  test('truncates long sections', () {
    final String added = List.generate(70, (index) => 'line $index').join('\n');
    final String diff = diffApi(expected: '', actual: added)!;

    expect(diff, contains('+line 59'));
    expect(diff, isNot(contains('+line 60')));
    expect(diff, contains('+... and 10 more line(s)'));
  });
}
