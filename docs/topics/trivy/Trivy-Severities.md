# Severities

<primary-label ref="config"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>The five severity levels, where each scan's severities come from, and how to filter them.</link-summary>

<card-summary>CRITICAL to UNKNOWN: what each level means for secrets, licenses and vulnerabilities.</card-summary>

Every finding has one of five severities. Each scan's `severity` option lists the levels that are reported; findings
of every other level are dropped before anything is printed, written or counted.

<include from="lib.topic" element-id="severity-values"/>

## Defaults per scan

| Scan | Default `severity` | Left out by default |
|:--|:--|:--|
| Secret | `CRITICAL, HIGH, MEDIUM, LOW` | Nothing a secret rule can report |
| License | `CRITICAL, HIGH, UNKNOWN` | Reciprocal (`MEDIUM`) and notice, permissive, unencumbered (`LOW`) licenses |
| Vulnerability | `CRITICAL, HIGH, MEDIUM, LOW` | `UNKNOWN`, which Trivy uses for advisories without a rating |
| Filesystem | `CRITICAL, HIGH, MEDIUM, LOW` | `UNKNOWN` |

## Secrets {id="secrets"}

The severity of a secret comes from the rule that found it. Trivy's built-in rules rate credentials by what they
grant. Some examples, as Trivy %tested_trivy% reports them:

| Severity | Built-in rule | Matches |
|:--|:--|:--|
| `CRITICAL` | `github-pat` | GitHub personal access tokens (`ghp_…`) |
| `CRITICAL` | `gitlab-pat` | GitLab personal access tokens (`glpat-…`) |
| `CRITICAL` | `stripe-secret-token` | Stripe secret keys (`sk_live_…`) |
| `HIGH` | `private-key` | PEM private keys (`-----BEGIN … PRIVATE KEY-----`) |
| `HIGH` | `slack-access-token` | Slack bot and user tokens (`xoxb-…`, `xoxp-…`) |
| `MEDIUM` | `slack-web-hook` | Slack incoming webhook URLs |

The full list is in Trivy's
[built-in rules](https://github.com/aquasecurity/trivy/blob/main/pkg/fanal/secret/builtin-rules.go).

Your own rules in `%secret_config%` set their severity explicitly. See [Secret rules](Trivy-Secret-Rules.md).

## Licenses {id="licenses"}

The severity of a license comes from its <tooltip term="license category">category</tooltip>:

| Severity | Category | Examples |
|:--|:--|:--|
| `CRITICAL` | forbidden | AGPL-3.0, CC-BY-NC-4.0 |
| `HIGH` | restricted | GPL-2.0, GPL-3.0, LGPL-2.1, LGPL-3.0 |
| `MEDIUM` | reciprocal | MPL-2.0, EPL-2.0 |
| `LOW` | notice, permissive, unencumbered | MIT, BSD-3-Clause, Apache-2.0, CC0-1.0 |
| `UNKNOWN` | not recognized | %product%'s `unclassified` and `no-license-file` findings |

Change the categories with a `trivy.yaml` in the package root - see
[License scan](Trivy-License-Scan.md#changing-the-categories).

## Vulnerabilities {id="vulnerabilities"}

The severity of a vulnerability is Trivy's rating, taken from the advisory's vendor - for pub packages the GitHub
Security Advisory - and otherwise from the CVSS score:

| Severity | CVSS v3 score |
|:--|:--|
| `CRITICAL` | 9.0 - 10.0 |
| `HIGH` | 7.0 - 8.9 |
| `MEDIUM` | 4.0 - 6.9 |
| `LOW` | 0.1 - 3.9 |
| `UNKNOWN` | No rating |

## Filtering

```yaml
inspectra:
  trivy:
    secret:
      severity: [CRITICAL, HIGH]           # ignore low-confidence rules
    license:
      severity: [CRITICAL, HIGH, MEDIUM, UNKNOWN]   # also report reciprocal licenses
    vulnerability:
      severity: [CRITICAL, HIGH]           # gate on the serious ones only
```

Severities are case-insensitive and can be listed in any order. An empty list is a configuration error; to stop
reporting a scan, set its `enabled: false`.

### Reporting without failing

To see more than you gate on, run a scan twice with different settings, or keep the gate strict and report the rest
from a scheduled job with `fail_on_findings: false`:

```yaml
# inspectra.yaml of a scheduled "report everything" job
trivy:
  enabled: true
  vulnerability:
    severity: [CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN]
    fail_on_findings: false
```

<seealso>
    <category ref="security">
        <a href="Trivy-Overview.md">Security and compliance</a>
        <a href="Trivy-Reports.md">Reports</a>
        <a href="Trivy-Configuration-Reference.md">Configuration reference</a>
    </category>
    <category ref="external">
        <a href="https://www.first.org/cvss/specification-document">CVSS specification</a>
    </category>
</seealso>
