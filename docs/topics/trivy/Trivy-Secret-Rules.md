# Secret rules

<primary-label ref="config"/>
<secondary-label ref="requires-trivy"/>
<secondary-label ref="no-network"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Writing trivy-secret.yaml: custom rules, disabled rules, and allow rules for fixtures.</link-summary>

<card-summary>Add rules for your own credential formats, and silence fake keys without hiding real ones.</card-summary>

<tldr>
<p><b>File</b>: <code>%secret_config%</code> in the package root, or <code>trivy.secret.config</code></p>
<p><b>Add</b>: <code>rules</code> · <b>Remove</b>: <code>disable-rules</code>, <code>enable-builtin-rules</code></p>
<p><b>Silence</b>: <code>allow-rules</code> · <b>Re-enable paths</b>: <code>disable-allow-rules</code></p>
</tldr>

The secret scan uses Trivy's built-in rules. A secret configuration file changes them: it adds rules for credential
formats Trivy does not know, removes rules that produce noise, and decides which paths and values are never reported.

## Where the file comes from

| `trivy.secret.config` | `%secret_config%` exists | Rules used |
|:--|:--|:--|
| unset | no | Trivy's built-in rules |
| unset | yes | Built-in rules, changed by `%secret_config%` |
| `security/secrets.yaml` | - | Built-in rules, changed by that file. It must exist; a missing file is a configuration error. |

The file is passed to Trivy with `--secret-config` as an absolute path, by both the builder and the command line. The
filesystem scan uses the same file when its `scanners` include `secret`.

<tip>
For <code>build_runner</code> to rerun the secret scan when you edit the rules, the file must be a
<tooltip term="build source">build source</tooltip> - see <a href="Build-Sources.md">Build sources</a>. The rules
always apply; only the automatic rerun depends on it.
</tip>

## Adding rules

A rule matches a regular expression. Trivy reports the part captured by the named group given in
`secret-group-name`, and masks it in its output.

```yaml
# trivy-secret.yaml
rules:
  - id: dart-hardcoded-credential
    category: Dart
    title: Hard-coded credential in Dart source
    severity: HIGH
    regex: (?i)(api_?key|token|secret|password)\s*=\s*['"](?P<secret>[A-Za-z0-9_/+\-]{8,})['"]
    secret-group-name: secret
    keywords:
      - apikey
      - api_key
      - token
      - secret
      - password
```

<deflist type="medium">
    <def title="id">Unique identifier; reported as the finding's ID and usable in <code>.trivyignore</code>.</def>
    <def title="category">A grouping shown in Trivy's own reports.</def>
    <def title="title">The description reported with each finding.</def>
    <def title="severity">CRITICAL, HIGH, MEDIUM or LOW. Findings outside <code>trivy.secret.severity</code> are dropped.</def>
    <def title="regex">An RE2 regular expression, Go syntax: no look-ahead or look-behind.</def>
    <def title="secret-group-name">The named group holding the secret itself. Without it, the whole match is the secret.</def>
    <def title="keywords">
        Lower-case words of which at least one must appear in a file before the regex runs on it. They make rules
        fast; a rule without keywords runs its regex on every file.
    </def>
    <def title="path">Optional regex; the rule only applies to files whose path matches.</def>
</deflist>

### Rules for Dart and Flutter projects

These patterns are common in Dart code bases and not all are covered by the built-in rules:

```yaml
rules:
  # const apiKey = '...';  final token = "...";
  - id: dart-hardcoded-credential
    category: Dart
    title: Hard-coded credential in Dart source
    severity: HIGH
    regex: (?i)(api_?key|token|secret|password)\s*=\s*['"](?P<secret>[A-Za-z0-9_/+\-]{8,})['"]
    secret-group-name: secret
    keywords: [apikey, api_key, token, secret, password]

  # String.fromEnvironment('X', defaultValue: '...') with a real value as default
  - id: dart-environment-default
    category: Dart
    title: Credential as default of String.fromEnvironment
    severity: MEDIUM
    regex: fromEnvironment\(\s*['"][A-Z_]*(KEY|TOKEN|SECRET)[A-Z_]*['"]\s*,\s*defaultValue:\s*['"](?P<secret>[^'"]{8,})['"]
    secret-group-name: secret
    keywords: [fromenvironment]
```

## Removing rules

```yaml
# Turn off individual rules by ID
disable-rules:
  - slack-web-hook

# Or keep only the listed built-in rules
enable-builtin-rules:
  - aws-access-key-id
  - aws-secret-access-key
  - github-pat
```

<warning>
<code>enable-builtin-rules</code> is an allow list: every built-in rule not listed is off. A configuration that lists
only the AWS rules does not detect a GitHub token, a Stripe key or a private key. Prefer
<code>disable-rules</code> for the few rules you want gone.
</warning>

## Allow rules {id="allow-rules"}

<tooltip term="allow rule">Allow rules</tooltip> suppress findings. They match a path, a value, or both.

```yaml
allow-rules:
  # Everything in the fixtures directory
  - id: fixture-keys
    description: Fake keys used by the tests
    path: ^test/fixtures/

  # One documented placeholder, wherever it appears
  - id: documented-placeholder
    description: The example key from the README
    regex: EXAMPLE-PLACEHOLDER-KEY-0000
```

Paths are regular expressions matched against the path Trivy reports, which for %product%'s secret scan is the path
relative to the package root.

### Trivy's built-in allow rules

Trivy suppresses findings in some paths out of the box. For a Dart package the relevant ones are:

| Built-in allow rule | Suppresses findings in | Example paths |
|:--|:--|:--|
| `tests` | Test directories | `test/`, `tests/`, `testdata/`, `integration_test/`, `test/fixtures/` |
| `examples` | Example directories | `example/`, `examples/` |
| `markdown` | Markdown files | `README.md`, `docs/*.md` |
| `usr-dirs` | System directories | `usr/` |

Not suppressed by default: `lib/`, `bin/`, `tool/`, `docs/` files other than Markdown, and `vendor/`.

<note>
For Dart this matters: a credential committed in <code>example/main.dart</code> or <code>integration_test/</code> is
published with your package and still not reported by default. To scan those directories too, disable the allow rules
and allow your real fixtures explicitly:
</note>

```yaml
disable-allow-rules:
  - tests
  - examples
  - markdown

allow-rules:
  - id: fixture-keys
    description: Fake keys used by the tests
    path: ^test/fixtures/
```

## A complete file

```yaml
# trivy-secret.yaml
# https://trivy.dev/latest/docs/scanner/secret/

# Scan test, example and Markdown files too: they are published with the package.
disable-allow-rules:
  - tests
  - examples
  - markdown

# ... except the fixtures that hold deliberately fake keys.
allow-rules:
  - id: fixture-keys
    description: Fake keys used by the tests
    path: ^test/fixtures/

disable-rules:
  - slack-web-hook

rules:
  - id: dart-hardcoded-credential
    category: Dart
    title: Hard-coded credential in Dart source
    severity: HIGH
    regex: (?i)(api_?key|token|secret|password)\s*=\s*['"](?P<secret>[A-Za-z0-9_/+\-]{8,})['"]
    secret-group-name: secret
    keywords: [apikey, api_key, token, secret, password]
```

## Ignoring a single finding

To accept one finding without changing the rules, add the rule ID to `.trivyignore` in the package root - Trivy runs
there, so it applies - or exclude the file with `trivy.secret.exclude`. Both are blunter than an allow rule with a
path, which is usually the better choice.

<seealso>
    <category ref="security">
        <a href="Trivy-Secret-Scan.md">Secret scan</a>
        <a href="Trivy-Installation.md#working-directory">Working directory</a>
    </category>
    <category ref="config">
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="external">
        <a href="%trivy_docs%/scanner/secret/">Trivy secret scanning</a>
        <a href="https://github.com/google/re2/wiki/Syntax">RE2 syntax</a>
    </category>
</seealso>
