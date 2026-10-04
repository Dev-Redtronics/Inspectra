# Custom style rules

<primary-label ref="library"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Write your own style rules in Dart against the analyzer's syntax tree, test them, and run them with inspectra style.</link-summary>

<card-summary>A StyleRule class, a styleRules list and one configuration key: your conventions as checks.</card-summary>

<tldr>
<p><b>Library</b>: <code>package:inspectra/style.dart</code></p>
<p><b>Declare</b>: a top level <code>styleRules</code> of type <code>List&lt;StyleRule&gt;</code></p>
<p><b>Register</b>: <code>style: { custom_rules: [tool/style_rules.dart] }</code></p>
<p><b>Test</b>: <code>StyleChecker([rule]).checkSource(path, source)</code></p>
</tldr>

Every team has conventions that no lint knows: no `print` outside `bin/`, no `DateTime.now()` where a clock is
injected, widgets named `…View` only under `lib/ui/`, no imports from `package:http` outside one adapter. A custom
style rule turns such a convention into a check that runs wherever the built-in [style rules](Style-Check.md) run:
`inspectra style`, `inspectra check`, the `inspectra:style` builder and SARIF uploads, with the same exceptions,
switches and output.

## Writing a rule

<procedure title="Add a rule that forbids print" id="first-rule">
    <step>
        <p>Make sure %product% and the analyzer are dev dependencies; the rule uses the analyzer's syntax tree:</p>
        <code-block lang="bash"><![CDATA[
dart pub add dev:inspectra dev:analyzer
]]></code-block>
    </step>
    <step>
        <p>Write the rule, for example in <code>tool/style_rules.dart</code>, and list it in a top level
            <code>styleRules</code>:</p>
        <code-block lang="dart"><![CDATA[
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:inspectra/style.dart';

final styleRules = <StyleRule>[const NoPrintRule()];

final class NoPrintRule extends StyleRule {
  const NoPrintRule();

  @override
  String get id => 'no_print';

  @override
  String get description => 'Use a logger instead of print.';

  @override
  void check(StyleFile file, StyleReporter reporter) {
    if (file.path.startsWith('bin/')) {
      return;
    }
    file.unit.accept(_PrintFinder(reporter));
  }
}

final class _PrintFinder extends RecursiveAstVisitor<void> {
  _PrintFinder(this.reporter);

  final StyleReporter reporter;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'print') {
      reporter.reportAt(node, 'Use a logger instead of print.');
    }
    super.visitMethodInvocation(node);
  }
}
]]></code-block>
    </step>
    <step>
        <p>Register the file:</p>
        <code-block lang="yaml"><![CDATA[
inspectra:
  style:
    enabled: true
    custom_rules: [tool/style_rules.dart]
]]></code-block>
    </step>
    <step>
        <p>Run it:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra style
]]></code-block>
        <code-block lang="text"><![CDATA[
Style: 1 violation(s) in 1 of 12 file(s).
  lib/greeter.dart:2:3: Use a logger instead of print. [no_print]
]]></code-block>
    </step>
</procedure>

## The API {id="api"}

Everything a rule needs comes from `package:inspectra/style.dart`:

| API | Description |
|:--|:--|
| `StyleRule` | The base class. Implement `id`, `description` and `check(file, reporter)`. |
| `id` | Lower snake case, unique, and not the id of a built-in rule. It is the name in `rules`, in ignore comments and in reports. |
| `description` | One sentence: what the rule requires. |
| `StyleFile` | The checked file: `path` relative to the package root with `/`, `content`, the syntax tree `unit`, `lineInfo`, the file `name` without extension, `isPart`. |
| `StyleReporter` | `reportAt(nodeOrToken, message)`, `reportOffset(offset, message)`, `reportLine(line, message)`. Lines and columns are computed for you. |
| `StyleViolation` | What a report produces: `ruleId`, `path`, `line`, `column`, `message`. |
| `StyleChecker` | Runs rules on source text: `StyleChecker(rules).checkSource(path, content)`. |

Rules see the parsed, unresolved syntax tree - `CompilationUnit` from `package:analyzer/dart/ast/ast.dart`. That keeps
the check fast and independent of type resolution, but it also means a rule sees names, not types: `print` is a call
named `print`, not necessarily `dart:core`'s. Walk the tree with a `RecursiveAstVisitor` or a `GeneralizingAstVisitor`
from `package:analyzer/dart/ast/visitor.dart`.

A rule must be deterministic and keep no state between files; %product% may call it for files in any order.

<note>
The syntax tree is the analyzer's public API, and %product% depends on <code>analyzer</code> %analyzer_version% or a
later compatible version. Keep the <code>analyzer</code> constraint of your package compatible with %product%'s so that
both resolve to the same version.
</note>

## Testing a rule {id="testing"}

`StyleChecker` runs rules on a string, so a rule is tested like any other function:

```dart
import 'package:inspectra/style.dart';
import 'package:test/test.dart';

import '../tool/style_rules.dart';

void main() {
  const checker = StyleChecker(<StyleRule>[NoPrintRule()]);

  test('reports print', () {
    final violations = checker.checkSource('lib/a.dart', "void f() => print('x');");
    expect(violations.single.toString(), 'lib/a.dart:1:13: Use a logger instead of print. [no_print]');
  });

  test('allows print in bin/', () {
    expect(checker.checkSource('bin/main.dart', "void main() => print('x');"), isEmpty);
  });

  test('respects ignore comments', () {
    const source = "void f() {\n  print('x'); // inspectra: ignore-style no_print\n}";
    expect(checker.checkSource('lib/a.dart', source), isEmpty);
  });
}
```

## Switching rules and exceptions {id="switching"}

Custom rules run in every [preset](Style-Check.md#presets). Switch one off in the configuration or for one run:

```yaml
inspectra:
  style:
    custom_rules: [tool/style_rules.dart]
    rules:
      no_print: false
```

```bash
dart run inspectra style --set style.rules.no_print=false
```

[Ignore comments](Style-Check.md#ignore) work for custom rules as for built-in ones:
`// inspectra: ignore-style no_print`. An id in `rules` that is neither built in nor declared by a custom rule file is
an error that lists the known rules, so a typo never switches nothing off.

## How custom rules run {id="how-it-works"}

A running %product% - possibly the compiled executable - cannot load Dart code of your package. Like analyzer
plugins and `custom_lint`, it generates a small program instead:

```text
.dart_tool/inspectra/style/
  host.dart       imports package:inspectra/style.dart and every custom_rules file, calls runStyleHost
  request.json    the files to check and the rules that are switched off
  answer.json     every rule's id and description, and the violations
```

and runs it with `dart run` in the package, where `package:inspectra`, `package:analyzer` and everything your rule
files import resolve through your `pubspec.lock`. The built-in rules keep running inside %product%. Both results are
merged, sorted and reported together.

This needs:

- a `dart` executable on the `PATH` - the one that runs %product% when it runs with `dart run`,
- `inspectra` as a dependency of the package and `dart pub get` done,
- rule files inside the package; they may import anything the package depends on.

| Problem | Exit code | Message |
|:--|:--|:--|
| A file of `custom_rules` does not exist | `65` | `The custom style rules tool/x.dart (style.custom_rules) do not exist.` |
| The program does not compile, for example without a `styleRules` | `65` | `… could not be run …` and the compiler output |
| An id is invalid, duplicated or that of a built-in rule | `65` | `The custom style rule id "…" …` |
| `rules` names an unknown rule | `65` | `Invalid Inspectra configuration at "style.rules.…": unknown rule. Known rules: …` |
| `dart` cannot be started | `69` | `Could not start "dart": …` |

The builder runs custom rules the same way and reruns when a file of `custom_rules` changes. A rule file that imports
other files of the package is rerun only when one of the checked files or the listed rule files changes.

<seealso>
    <category ref="quality">
        <a href="Style-Check.md">Style check</a>
        <a href="Lint-Check.md">Lint check</a>
    </category>
    <category ref="reference">
        <a href="Library-API.md#style">Library API</a>
    </category>
    <category ref="external">
        <a href="https://pub.dev/documentation/analyzer/latest/dart_ast_ast/">The analyzer's syntax tree</a>
        <a href="https://pub.dev/documentation/analyzer/latest/dart_ast_visitor/">Visitors</a>
    </category>
</seealso>
