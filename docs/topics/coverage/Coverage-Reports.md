# Coverage reports

<primary-label ref="cli"/>
<secondary-label ref="cli-only"/>

<show-structure for="chapter" depth="2"/>

<link-summary>The console table and lcov.info, and how to use them in IDEs, HTML reports and CI services.</link-summary>

<card-summary>A console table for people, lcov.info for every coverage tool there is.</card-summary>

## Console table

```text
  lib/fixture.dart    25.00%  (1/4)
  lib/src/calc.dart   40.00%  (2/5)
  Total               33.33%  (3/9)

  1 file(s) were not loaded by any test and are not counted:
    lib/src/unused.dart

  Report: coverage/lcov.info
  Line coverage 33.33% is below the required 90.00%.
```

| Part | Meaning |
|:--|:--|
| One line per file | Path relative to the package root, line coverage, and `(lines hit/executable lines)`. Sorted by path. |
| `Total` | All reported files together. This is the number the gate compares. |
| Not loaded | Files below `report_on` that no test imported. They are not part of the total. See [Files no test loaded](Coverage-Overview.md#files-no-test-loaded). |
| `Report:` | Where `lcov.info` was written. |
| Verdict | Only when a threshold is set: `meets` or `is below the required`. |

A file with no executable lines - a file of constants, say - shows `100.00% (0/0)`.

## lcov.info

`<output_directory>/lcov.info`, by default `coverage/lcov.info`, in the standard lcov format:

```text
SF:lib/fixture.dart
DA:5,2
DA:7,0
DA:10,0
DA:11,0
LF:4
LH:1
end_of_record
```

| Record | Meaning |
|:--|:--|
| `SF:` | Source file, relative to the package root |
| `DA:<line>,<hits>` | An executable line and how often it ran |
| `LF:` | Lines found: executable lines in the file |
| `LH:` | Lines hit: executable lines that ran |
| `end_of_record` | End of the file's entry |

The file contains exactly what the gate measured: only reported files, ignored lines removed, excluded files left
out. It is rewritten on every run.

## Using lcov.info

<tabs group="tools">
    <tab title="HTML report" group-key="html">
        <code-block lang="bash"><![CDATA[
# genhtml is part of the lcov package (apt install lcov, brew install lcov)
genhtml coverage/lcov.info --output-directory coverage/html
open coverage/html/index.html
]]></code-block>
    </tab>
    <tab title="VS Code" group-key="vscode">
        <p>The <i>Coverage Gutters</i> extension reads <code>coverage/lcov.info</code> by default and shows hit and
            missed lines in the editor. Run <i>Coverage Gutters: Watch</i> once.</p>
    </tab>
    <tab title="IntelliJ / Android Studio" group-key="intellij">
        <p><i>Run | Show Coverage Data…</i>, add <code>coverage/lcov.info</code>.</p>
    </tab>
    <tab title="Codecov" group-key="codecov">
        <code-block lang="yaml"><![CDATA[
- run: dart run inspectra coverage
- uses: codecov/codecov-action@v5
  with:
    files: coverage/lcov.info
]]></code-block>
    </tab>
    <tab title="Coveralls" group-key="coveralls">
        <code-block lang="yaml"><![CDATA[
- run: dart run inspectra coverage
- uses: coverallsapp/github-action@v2
  with:
    file: coverage/lcov.info
]]></code-block>
    </tab>
    <tab title="GitLab" group-key="gitlab">
        <code-block lang="yaml"><![CDATA[
coverage:
  script:
    - dart run inspectra coverage
  # Shows the total in merge requests
  coverage: '/Total\s+(\d+\.\d+)%/'
  artifacts:
    paths: [coverage/lcov.info]
]]></code-block>
    </tab>
</tabs>

## Raw output

`<output_directory>/raw/` holds what the test runner wrote: one JSON hit map per test file for `dart test`, or Flutter's
own `lcov.info`. It is deleted and recreated at the start of every run. You rarely need it; it is useful when
debugging why a file is missing from the report.

<seealso>
    <category ref="coverage">
        <a href="Coverage-Overview.md">Coverage</a>
        <a href="Coverage-Configuration.md">Configuration</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
    </category>
    <category ref="external">
        <a href="https://github.com/linux-test-project/lcov">lcov and genhtml</a>
    </category>
</seealso>
