import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

/// Renders the API of `package:a/a.dart`, given its source and that of
/// further files of the package.
Future<String> render(
  String source, {
  Map<String, String> files = const {},
  List<String> nonPublic = const [],
}) => resolveSources(
  {
    'a|lib/a.dart': source,
    for (final MapEntry(:key, :value) in files.entries) 'a|$key': value,
  },
  (resolver) async => renderApi([
    await resolver.libraryFor(AssetId('a', 'lib/a.dart')),
  ], nonPublicAnnotations: nonPublic),
);

/// The rendered API without the header and the library line.
String body(String rendered) =>
    rendered.split('library package:a/a.dart\n').last.trim();

void main() {
  test('starts with the header and the library', () async {
    final String rendered = await render('int answer() => 42;');

    expect(rendered, startsWith(apiDumpHeader));
    expect(rendered, contains('library package:a/a.dart\n'));
  });

  test(
    'renders top-level declarations sorted by name, case-sensitively',
    () async {
      final String rendered = await render('''
int zeta() => 0;
final int alpha = 1;
const String beta = 'b';
int get gamma => 3;
set delta(int value) {}
typedef Callback = void Function(int value);
''');

      expect(
        body(rendered),
        'typedef Callback = void Function(int);\n\n'
        'final int alpha;\n\n'
        "const String beta = 'b';\n\n"
        'set delta(int value);\n\n'
        'int get gamma;\n\n'
        'int zeta();',
      );
    },
  );

  test('renders a class with its modifiers, supertypes and members', () async {
    final String rendered = await render('''
mixin Named {}
abstract base class Shape<T extends num> with Named implements Comparable<Shape<T>> {
  Shape(this.size, {this.label = 'shape'});
  const factory Shape.empty() = _Empty<T>;
  final T size;
  final String label;
  static int count = 0;
  int get sides;
  set sides(int value) {}
  double area();
  bool operator ==(Object other) => identical(this, other);
  int compareTo(Shape<T> other) => 0;
  void _secret() {}
}
final class _Empty<T extends num> implements Shape<T> {
  const _Empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
''');

    expect(
      body(rendered),
      contains(
        'abstract base class Shape<T extends num> with Named '
        'implements Comparable<Shape<T>> {\n'
        '  static int count;\n'
        '  final String label;\n'
        '  final T size;\n'
        "  Shape<T>(T size, {String label = 'shape'});\n"
        '  const factory Shape<T>.empty();\n'
        '  abstract int get sides;\n'
        '  set sides(int value);\n'
        '  bool operator ==(Object other);\n'
        '  abstract double area();\n'
        '  int compareTo(Shape<T> other);\n'
        '}',
      ),
    );
    expect(rendered, isNot(contains('_secret')));
    expect(rendered, isNot(contains('_Empty')));
  });

  test('renders enums with their values', () async {
    final String rendered = await render('''
enum Level {
  low(1), high(2);
  const Level(this.weight);
  final int weight;
  bool get isHigh => this == high;
}
''');

    expect(
      body(rendered),
      'enum Level {\n  low, high;\n  final int weight;\n  bool get isHigh;\n}',
    );
  });

  test('renders mixins, extensions and extension types', () async {
    final String rendered = await render('''
base mixin Logging on Object { void log(String message) {} }
extension Shout on String { String shout() => toUpperCase(); }
extension type Meters(double value) { Meters operator +(Meters other) => Meters(value + other.value); }
''');

    expect(
      body(rendered),
      contains(
        'base mixin Logging on Object {\n  void log(String message);\n}',
      ),
    );
    expect(
      body(rendered),
      contains('extension Shout on String {\n  String shout();\n}'),
    );
    expect(
      body(rendered),
      contains(
        'extension type Meters(double value) {\n'
        '  Meters(double value);\n'
        '  Meters operator +(Meters other);\n'
        '}',
      ),
    );
  });

  test('renders an empty class on one line', () async {
    expect(body(await render('class Marker {}')), 'class Marker {}');
  });

  test(
    'includes re-exported declarations but not the rest of lib/src',
    () async {
      final String rendered = await render(
        "export 'src/impl.dart' show Exported;",
        files: {'lib/src/impl.dart': 'class Exported {}\nclass NotExported {}'},
      );

      expect(body(rendered), 'class Exported {}');
    },
  );

  test('leaves out declarations with a non-public annotation', () async {
    final String rendered = await render(
      '''
class Internal { const Internal(); }
const internal = Internal();
@internal
void hiddenByConstant() {}
@Internal()
void hiddenByClass() {}
class Visible {
  @internal
  void hiddenMember() {}
  void shown() {}
}
''',
      nonPublic: ['internal'],
    );

    expect(rendered, isNot(contains('hiddenByConstant')));
    expect(rendered, contains('hiddenByClass'));
    expect(rendered, isNot(contains('hiddenMember')));
    expect(rendered, contains('void shown();'));
  });

  test('marks deprecated declarations', () async {
    final String rendered = await render(
      "@Deprecated('Use b') void a() {}\nvoid b() {}",
    );

    expect(body(rendered), '@Deprecated void a();\n\nvoid b();');
  });

  test('records whether a primary constructor is const', () async {
    final String rendered = await render(
      'extension type const Id(int value) {}',
    );

    expect(
      body(rendered),
      'extension type Id(int value) {\n  const Id(int value);\n}',
    );
  });

  test('records the values of constants', () async {
    final String rendered = await render('''
const limit = 10;
class Config {
  static const String name = 'config';
  static final DateTime started = DateTime.now();
}
''');

    expect(body(rendered), contains('const int limit = 10;'));
    expect(body(rendered), contains("static const String name = 'config';"));
    expect(body(rendered), contains('static final DateTime started;'));
  });

  test('leaves out unnamed extensions, which are library-private', () async {
    final String rendered = await render(
      'extension on int { int get doubled => this * 2; }',
    );

    expect(body(rendered), isEmpty);
  });
}
