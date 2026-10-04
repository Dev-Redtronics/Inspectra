import 'package:coverage/coverage.dart';
import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

void main() {
  group('parseLcov', () {
    test('reads the line hits of each file, keyed by file URI', () {
      final Map<String, HitMap> hitMaps = parseLcov(
        'SF:lib/a.dart\nDA:1,1\nDA:2,0\nend_of_record\nSF:/abs/b.dart\nDA:3,4\nend_of_record\n',
        '/package',
      );

      expect(hitMaps.keys, [
        'file:///package/lib/a.dart',
        'file:///abs/b.dart',
      ]);
      expect(hitMaps['file:///package/lib/a.dart']!.lineHits, {1: 1, 2: 0});
      expect(hitMaps['file:///abs/b.dart']!.lineHits, {3: 4});
    });

    test('merges repeated records of the same file', () {
      final Map<String, HitMap> hitMaps = parseLcov(
        'SF:a.dart\nDA:1,1\nend_of_record\nSF:a.dart\nDA:1,2\nend_of_record\n',
        '/p',
      );

      expect(hitMaps.values.single.lineHits, {1: 3});
    });
  });

  group('CoverageReport', () {
    CoverageReport report({double? threshold}) => CoverageReport(
      files: [
        const FileCoverage('lib/b.dart', 10, 5),
        const FileCoverage('lib/a.dart', 10, 10),
      ],
      untested: const ['lib/c.dart'],
      lcovPath: 'coverage/lcov.info',
      minLineCoverage: threshold,
    );

    test('sums the lines of all files', () {
      final CoverageReport coverage = report();

      expect(coverage.linesFound, 20);
      expect(coverage.linesHit, 15);
      expect(coverage.percent, 75);
      expect(coverage.files.first.path, 'lib/a.dart');
    });

    test('fails only below the threshold', () {
      expect(report().failed, isFalse);
      expect(report(threshold: 75).failed, isFalse);
      expect(report(threshold: 75.01).failed, isTrue);
    });

    test('lists files no test loaded', () {
      expect(
        report(threshold: 80).render(),
        allOf(contains('lib/c.dart'), contains('below the required 80.00%')),
      );
    });
  });
}
