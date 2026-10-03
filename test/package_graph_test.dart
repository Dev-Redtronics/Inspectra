import 'dart:convert';

import 'package:inspectra/inspectra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late String root;

  setUp(() {
    root = temporaryDirectory();
    writeResolvedPackage(
      root,
      dependencies: ['http'],
      devDependencies: ['test'],
      packages: [
        const FakePackage('http', dependencies: ['meta']),
        const FakePackage('meta'),
        const FakePackage('test', dependencies: ['meta', 'matcher']),
        const FakePackage('matcher'),
        const FakePackage('local', source: 'path'),
      ],
    );
  });

  test('follows dependencies but not dev_dependencies', () async {
    final PackageGraph graph = await PackageGraph.load(p.join(root, 'app'));

    expect(graph.reachable(includeDev: false), {'http', 'meta'});
  });

  test('includes dev_dependencies on request', () async {
    final PackageGraph graph = await PackageGraph.load(p.join(root, 'app'));

    expect(graph.reachable(includeDev: true), {
      'http',
      'meta',
      'test',
      'matcher',
    });
  });

  test('knows where each package lives', () async {
    final PackageGraph graph = await PackageGraph.load(p.join(root, 'app'));

    expect(graph.directoryOf('http'), p.join(root, 'cache', 'http'));
    expect(graph.directoryOf('missing'), isNull);
  });

  test('narrows the lock file to the given packages', () async {
    final PackageGraph graph = await PackageGraph.load(p.join(root, 'app'));
    final retained =
        jsonDecode(graph.lock.retain({'meta', 'http'})) as Map<String, Object?>;

    expect((retained['packages']! as Map).keys, ['http', 'meta']);
    expect(
      PubspecLock.parse(graph.lock.retain({'meta'})).packages['meta']!.version,
      '1.0.0',
    );
  });

  test('tells external packages from path packages', () async {
    final PubspecLock lock = (await PackageGraph.load(p.join(root, 'app')))
        .lock;

    expect(lock.packages['http']!.isExternal, isTrue);
    expect(lock.packages['local']!.isExternal, isFalse);
    expect(lock.packages['test']!.dependency, 'direct dev');
  });
}
