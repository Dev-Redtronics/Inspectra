# Filesystem scan

<primary-label ref="cli"/>
<secondary-label ref="requires-trivy"/>
<secondary-label ref="cli-only"/>
<secondary-label ref="opt-in"/>

<show-structure for="chapter" depth="2"/>

<link-summary>A plain trivy fs over the whole package, including misconfiguration checks.</link-summary>

<card-summary>Everything Trivy finds in the package root, including Dockerfiles and Terraform.</card-summary>

<tldr>
<p><b>Enable</b>: <code>trivy.filesystem.enabled: true</code></p>
<p><b>Command</b>: <code>dart run %package% trivy filesystem</code></p>
<p><b>Default scanners</b>: <code>vuln</code>, <code>secret</code>, <code>misconfig</code></p>
</tldr>

The filesystem scan runs `trivy fs` over the package root with the scanners you choose. It complements the three
focused scans with what they deliberately leave out:

- **Misconfigurations**: Trivy's `misconfig` scanner checks Dockerfiles, Kubernetes manifests, Helm charts, Terraform,
  CloudFormation and Azure templates in your repository - for a Dart server or a Flutter web app with a deployment
  next to it.
- **Every lock file**: the `vuln` scanner reads every dependency file Trivy understands, not only `pubspec.lock` -
  a `package-lock.json` of a web front end, a `Gemfile.lock` of the iOS tooling, a `go.sum` of a sidecar.
- **Every file**: the `secret` scanner reads the whole package, not a selection.

## Configuration

```yaml
inspectra:
  trivy:
    enabled: true
    filesystem:
      enabled: true                          # off by default
      fail_on_findings: true                 # default
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      scanners: [vuln, secret, misconfig]    # default
      skip_dirs: [.dart_tool, build, .git]   # default
```

| Key | Default | Description |
|:--|:--|:--|
| `enabled` | `false` | Off even with `trivy.enabled`, because it overlaps with the focused scans. |
| `fail_on_findings` | `true` | Whether a finding fails the command. |
| `severity` | all but `UNKNOWN` | The severities reported. |
| `scanners` | `[vuln, secret, misconfig]` | Any of `vuln`, `secret`, `misconfig`, `license`. |
| `skip_dirs` | `[.dart_tool, build, .git]` | Directories Trivy skips, relative to the package root. |

There is no `run_on_build`: the scan reads the whole package, most of which `build_runner` cannot see, and its result
would not be reproducible from the build sources.

## The command Inspectra runs

```bash
trivy fs --quiet --scanners vuln,secret,misconfig \
  --severity CRITICAL,HIGH,MEDIUM,LOW --format json --output <report> \
  --skip-dirs .dart_tool --skip-dirs build --skip-dirs .git \
  [--secret-config <trivy-secret.yaml>] [--license-full] \
  <package root>
```

- `--secret-config` is added when the scanners include `secret` and a secret configuration is in use - the same file
  the [secret scan](Trivy-Secret-Rules.md) uses.
- `--license-full` is added when the scanners include `license`, so license files are classified as well as package
  metadata.

## Findings

All scanners report into one result, each finding prefixed with the file it was found in:

```text
Trivy filesystem scan: 3 finding(s).
  [CRITICAL] lib/src/config.dart: github-pat - GitHub Personal Access Token (line 4)
  [HIGH] Dockerfile: DS-0002 - Image user should not be 'root' (Specify at least 1 USER command in Dockerfile with non-root user as argument)
  [MEDIUM] pubspec.lock: http 0.13.0: CVE-2020-35669 - http before 0.13.3 vulnerable to header injection (fixed in 0.13.3, https://avd.aquasec.com/nvd/cve-2020-35669)
```

| Scanner | Target | ID | Detail |
|:--|:--|:--|:--|
| `vuln` | `<lock file>: <package> <version>` | CVE or GHSA | Fixed version and URL |
| `secret` | The file | Rule ID | Line |
| `misconfig` | The file | Check ID such as `DS-0002` | Trivy's message; passed checks are not reported |
| `license` | The package or the license file | SPDX ID | Category |

## Differences from the focused scans

| | Focused scans | Filesystem scan |
|:--|:--|:--|
| Secret file selection | `include` / `exclude` globs | Everything except `skip_dirs` |
| Dependency scope | `pubspec.lock`, optionally narrowed to shipped dependencies | Every lock file, everything in it |
| `ignored_vulnerabilities`, `ignore_unfixed` | Applied | Not applied; use `.trivyignore` |
| Licenses of pub packages | From the packages' license files | Only what Trivy finds in the package itself |
| Builder | Yes | No |

<tip>
Running the filesystem scan with only <code>[misconfig]</code> is a good fit next to the three focused scans: no
finding is reported twice, and the infrastructure files get checked too.
</tip>

<include from="lib.topic" element-id="trivy-required"/>

<seealso>
    <category ref="security">
        <a href="Trivy-Overview.md">Security and compliance</a>
        <a href="Trivy-Secret-Rules.md">Secret rules</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md">Command line reference</a>
    </category>
    <category ref="external">
        <a href="%trivy_docs%/scanner/misconfiguration/">Trivy misconfiguration scanning</a>
    </category>
</seealso>
