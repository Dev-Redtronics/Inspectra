# Secret scan

<primary-label ref="builder"/>
<secondary-label ref="requires-trivy"/>
<secondary-label ref="on-build"/>
<secondary-label ref="no-network"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Finding hard-coded credentials in your sources and configuration files on every build.</link-summary>

<card-summary>Trivy's secret rules over a precise selection of files, on every build_runner build.</card-summary>

<tldr>
<p><b>Enable</b>: <code>trivy: { enabled: true }</code> - the secret scan is on with it</p>
<p><b>Runs</b>: on every <code>build_runner build</code>, and with <code>dart run %package% trivy secret</code></p>
<p><b>Rules</b>: Trivy's built-in rules, plus <code>%secret_config%</code> when present</p>
</tldr>

The secret scan looks for credentials in your own files: API keys, tokens, private keys and passwords that were pasted
into a source file or a configuration file. Trivy ships rules for the formats of the major providers - AWS, GitHub,
GitLab, Google Cloud, Slack, Stripe, private keys in PEM format and many more - and you can add your own.

## Configuration

```yaml
inspectra:
  trivy:
    enabled: true
    secret:
      enabled: true                 # default
      run_on_build: true            # default
      fail_on_findings: true        # default
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      config: trivy-secret.yaml     # default: this file, when it exists
      include: ['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties']
      exclude: ['**/.dart_tool/**', '**/build/**', '**/.git/**']
```

| Key | Default | Description |
|:--|:--|:--|
| `enabled` | `true` | Whether the scan runs when `trivy.enabled` is set. |
| `run_on_build` | `true` | Whether `build_runner build` runs it. |
| `fail_on_findings` | `true` | Whether a finding fails the build or the command. |
| `severity` | all but `UNKNOWN` | The severities reported. |
| `config` | unset | The secret rules file; see [Secret rules](Trivy-Secret-Rules.md). |
| `include` | see above | Globs of the files to scan. |
| `exclude` | see above | Globs of files never scanned. |

## Which files are scanned

A file is scanned when it matches at least one `include` glob and no `exclude` glob. Both are matched against the
path relative to the package root, with `/` as separator.

The defaults cover where credentials are actually pasted: Dart sources, and the YAML, JSON, `.env` and properties files
that configuration lives in - `pubspec.yaml`, `firebase.json`, `.env`, deployment descriptors. Generated output and tool
caches are excluded, because a secret there is a copy of one in a file the scan already reads, and scanning it again
costs time without adding a finding.

### Glob syntax

| Glob | Matches |
|:--|:--|
| `**.dart` | Every `.dart` file at any depth, including the root |
| `lib/**` | Everything below `lib/` |
| `config/*.yaml` | YAML files directly in `config/` |
| `**/build/**` | Everything below any directory called `build`, including the root `build/` |
| `.env*` | `.env`, `.env.local`, `.env.production` in the root |
| `{lib,bin}/**.dart` | Dart files below `lib/` or `bin/` |

### Changing the selection

`include` and `exclude` replace their defaults. To scan more file types, repeat the defaults and add yours:

```yaml
inspectra:
  trivy:
    secret:
      include: ['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties',
                '**.xml', '**.plist', '**.gradle', '**.kts', 'Dockerfile*']
```

To leave out test fixtures that hold deliberately fake keys:

```yaml
inspectra:
  trivy:
    secret:
      exclude: ['**/.dart_tool/**', '**/build/**', '**/.git/**', 'test/fixtures/**']
```

<tip>
Prefer an allow rule in <code>%secret_config%</code> over an exclude when only one fake key is the problem: an exclude
hides real secrets in the same files as well. See <a href="Trivy-Secret-Rules.md#allow-rules">Allow rules</a>.
</tip>

### Builder versus command line

| | Builder | Command line |
|:--|:--|:--|
| Candidate files | The <tooltip term="build source">build sources</tooltip> | Every file under the package root |
| Root-level `.env`, `analysis_options.yaml`, `.github/` | Only when added to the sources | Yes, if they match `include` |
| Reruns | When a scanned file, or a matching new file, changes | Every run |

[Build sources](Build-Sources.md) shows how to let the builder see more files.

## How the scan runs

1. The selected files are copied into a temporary <tooltip term="staging directory">staging directory</tooltip>,
   keeping their package-relative paths.
2. One Trivy process scans the staging directory:
   `trivy fs --quiet --scanners secret --severity … --format json --output … [--secret-config …] <staging>`.
3. Each secret in the report becomes a finding with the file's package-relative path, the rule ID, the rule's title
   and the line number.
4. The staging directory is deleted.

Copying first is what makes the selection exact - Trivy sees neither more nor less than the configured files - and
it means one Trivy process per scan instead of one per file.

## Findings

```text
Trivy secret scan: 2 finding(s).
  [CRITICAL] lib/src/client.dart: github-pat - GitHub Personal Access Token (line 12)
  [HIGH] lib/src/client.dart: dart-hardcoded-credential - Hard-coded credential in Dart source (line 14)
```

Each finding names the file, the rule that matched, the rule's title and the line. Trivy masks the secret itself in
its report, and %product% never prints it.

<warning>
A secret that reached a commit must be treated as compromised, even if the commit was never pushed to a shared
branch. Rotate it first; then remove it from the history with <code>git filter-repo</code> or the BFG Repo-Cleaner.
Deleting it in a new commit leaves it readable in the old one.
</warning>

## When the scan is skipped

When no file matches the configured globs, the scan reports `Trivy secret scan skipped: no files match the configured
globs.` instead of running Trivy on an empty directory. That is not a failure, but it usually means `include` is
wrong.

## Trivy's allow rules

Trivy suppresses findings in some places by default, through built-in <tooltip term="allow rule">allow rules</tooltip>.
For a Dart package that means: `test/`, `tests/`, `testdata/`, `integration_test/`, `example/`, `examples/` and Markdown
files are **not** scanned for secrets out of the box, even when `include` matches them.

That is convenient for test fixtures, but `example/` is published with your package. To scan those paths as well,
disable the allow rules in `%secret_config%` and allow your real fixtures explicitly - see
[Secret rules](Trivy-Secret-Rules.md#allow-rules).

<seealso>
    <category ref="security">
        <a href="Trivy-Secret-Rules.md">Secret rules</a>
        <a href="Trivy-Overview.md">Security and compliance</a>
        <a href="Trivy-Reports.md">Reports</a>
    </category>
    <category ref="config">
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="external">
        <a href="%trivy_docs%/scanner/secret/">Trivy secret scanning</a>
    </category>
</seealso>
