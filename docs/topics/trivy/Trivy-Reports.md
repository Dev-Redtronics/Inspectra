# Reports

<primary-label ref="cli"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>The console output and the JSON report each scan writes, and where to find them.</link-summary>

<card-summary>Console summaries for people, JSON reports for tooling and CI artifacts.</card-summary>

Every scan produces two things: a summary for people, printed to the console or the build log, and a JSON report for
tools.

## Console output

```text
Trivy secret scan: no findings.
Trivy license scan: 2 finding(s) (not failing).
  [UNKNOWN] bare_package 0.3.0: no-license-file - package ships no license file
  [UNKNOWN] private_fork 1.0.0: unclassified - Trivy could not classify the license file
Trivy vulnerability scan: 1 finding(s).
  [MEDIUM] http 0.13.0: CVE-2020-35669 - http before 0.13.3 vulnerable to header injection (fixed in 0.13.3, https://avd.aquasec.com/nvd/cve-2020-35669)
Trivy filesystem scan skipped: ...
```

Each finding line has the form `[SEVERITY] target: id - title (detail)`:

| Field | Secret | License | Vulnerability | Misconfiguration |
|:--|:--|:--|:--|:--|
| target | File | `package version` | `package version` | File |
| id | Rule ID | SPDX ID, `unclassified`, `no-license-file` | CVE or GHSA ID | Check ID |
| title | Rule title | `license category "…"` | Advisory summary | Check title |
| detail | `line N` | - | `fixed in X, URL` or `no fix released` | Trivy's message |

Findings are sorted by severity, most severe first, then by target and ID - so two runs over the same input print the
same lines in the same order.

In a `build_runner` build the same text appears in the log: as `SEVERE` when the scan fails, as `WARNING` when it has
findings that do not fail, and at `FINE` - hidden unless you pass `--verbose` - when it is clean.

## JSON reports

| Run | Location |
|:--|:--|
| `dart run %package% trivy` and `check` | `%report_dir%/<scan>.json`, configurable with `trivy.report_directory` |
| `dart run build_runner build` | `%artifact_dir%/<scan>.json`, in the <tooltip term="artifact tree">artifact tree</tooltip> |

`<scan>` is `secret`, `license`, `vulnerability` or `filesystem`. The command line overwrites the report on every run;
the builder only when the scan reruns.

### Format

```json
{
  "scan": "vulnerability",
  "failed": true,
  "findings": [
    {
      "severity": "MEDIUM",
      "target": "http 0.13.0",
      "id": "CVE-2020-35669",
      "title": "http before 0.13.3 vulnerable to header injection",
      "detail": "fixed in 0.13.3, https://avd.aquasec.com/nvd/cve-2020-35669"
    }
  ]
}
```

| Field | Type | Description |
|:--|:--|:--|
| `scan` | string | `secret`, `license`, `vulnerability` or `filesystem` |
| `failed` | boolean | Whether the scan failed: findings exist and `fail_on_findings` is `true` |
| `skipped` | string, optional | Why the scan did not run, for example `no files match the configured globs.` |
| `findings` | list | The findings, sorted as on the console |
| `findings[].severity` | string | `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` or `UNKNOWN` |
| `findings[].target` | string | Where the finding is |
| `findings[].id` | string | Rule, license or vulnerability identifier |
| `findings[].title` | string | One-line description |
| `findings[].detail` | string, optional | Line number, fixed version, URL or message |

The format is %product%'s own and stable across Trivy versions: it holds only what %product% decided, after
severities, ignores and categories were applied.

### Using the reports in CI

<tabs group="ci">
    <tab title="GitHub Actions" group-key="github">
        <code-block lang="yaml"><![CDATA[
- name: Upload the Trivy reports
  if: always()
  uses: actions/upload-artifact@v7
  with:
    name: trivy-reports
    path: .dart_tool/inspectra/trivy/
]]></code-block>
    </tab>
    <tab title="GitLab CI" group-key="gitlab">
        <code-block lang="yaml"><![CDATA[
inspectra:
  script:
    - dart run inspectra check
  artifacts:
    when: always
    paths:
      - .dart_tool/inspectra/trivy/
]]></code-block>
    </tab>
    <tab title="jq" group-key="jq">
        <code-block lang="bash"><![CDATA[
# Every critical finding of every scan
jq -r '.findings[] | select(.severity == "CRITICAL") | "\(.target): \(.id)"' \
  .dart_tool/inspectra/trivy/*.json
]]></code-block>
    </tab>
</tabs>

<note>
The report directory is under <code>.dart_tool</code> by default, which pub's <code>.gitignore</code> template already
ignores. Point <code>report_directory</code> elsewhere if your CI only collects artifacts from the workspace root.
</note>

<seealso>
    <category ref="security">
        <a href="Trivy-Overview.md">Security and compliance</a>
        <a href="Trivy-Severities.md">Severities</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
    </category>
</seealso>
