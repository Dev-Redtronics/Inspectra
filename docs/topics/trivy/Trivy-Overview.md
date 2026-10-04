# Security and compliance

<primary-label ref="builder"/>
<secondary-label ref="requires-trivy"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Four Trivy scans for credentials, licenses, vulnerabilities and misconfigurations.</link-summary>

<card-summary>Secret, license, vulnerability and filesystem scans, from build_runner or the command line.</card-summary>

<tldr>
<p><b>Enable</b>: <code>trivy: { enabled: true }</code></p>
<p><b>Requires</b>: Trivy, installed or downloaded by the command line</p>
<p><b>Runs on build</b>: the secret scan; the others on request</p>
<p><b>Command</b>: <code>dart run %package% trivy [secret|license|vulnerability|filesystem]</code></p>
</tldr>

%product% runs [Trivy](%trivy_docs%), Aqua Security's open source scanner, in four configurations. Each answers one
question about your package:

| Scan | Question | Reads | Default | Builder |
|:--|:--|:--|:--|:--|
| [Secret](Trivy-Secret-Scan.md) | Is a credential hard-coded in a source or configuration file? | Your files | On, on every build | Yes |
| [License](Trivy-License-Scan.md) | May I ship the licenses of my dependencies? | License files of shipped dependencies | On, on request | Yes, opt-in |
| [Vulnerability](Trivy-Vulnerability-Scan.md) | Does a dependency have a known vulnerability? | `pubspec.lock` | On, on request | Yes, opt-in |
| [Filesystem](Trivy-Filesystem-Scan.md) | Anything else Trivy finds in the package? | The whole package | Off | No |

## Enabling the scans

```yaml
inspectra:
  trivy:
    enabled: true
```

That one switch enables the secret, license and vulnerability scans with their defaults. Each scan has its own
`enabled` to turn it off again, and the filesystem scan has to be enabled explicitly:

```yaml
inspectra:
  trivy:
    enabled: true
    license:
      enabled: false        # this package ships no third-party code
    filesystem:
      enabled: true         # also check the Dockerfile
```

<include from="lib.topic" element-id="trivy-required"/>

## Running the scans

<tabs group="run">
    <tab title="build_runner" group-key="build">
        <code-block lang="bash"><![CDATA[
dart run build_runner build      # scans with run_on_build: true
dart run build_runner watch      # ... and again on every change
]]></code-block>
        <p>Only scans with <code>run_on_build: true</code> run here: by default the secret scan. Enable the others per
            scan - see <a href="#on-build">Which scans run on build</a>.</p>
    </tab>
    <tab title="Command line" group-key="cli">
        <code-block lang="bash"><![CDATA[
dart run inspectra trivy                       # every enabled scan (a filesystem scan when trivy.enabled is false)
dart run inspectra trivy secret license        # these scans, even if disabled
dart run inspectra check                       # every enabled scan, plus API and coverage
]]></code-block>
    </tab>
</tabs>

Output is the same in both places, one block per scan, most severe findings first:

```text
Trivy secret scan: 2 finding(s).
  [CRITICAL] tool/leak.dart: github-pat - GitHub Personal Access Token (line 1)
  [HIGH] tool/leak.dart: dart-hardcoded-credential - Hard-coded credential in Dart source (line 1)
Trivy license scan: no findings.
Trivy vulnerability scan: 1 finding(s) (not failing).
  [MEDIUM] http 0.13.0: CVE-2020-35669 - http before 0.13.3 vulnerable to header injection (fixed in 0.13.3, https://avd.aquasec.com/nvd/cve-2020-35669)
```

*(not failing)* marks a scan with `fail_on_findings: false`. See [Reports](Trivy-Reports.md) for the JSON files.

## Which scans run on build {id="on-build"}

| Scan | `run_on_build` default | Cost of a run | Why |
|:--|:--|:--|:--|
| Secret | `true` | About a second | It reads files that are already on disk. A secret leaks with the push, not with the merge, so a check that only runs in CI runs too late. |
| License | `false` | A second or two | It reads a license file per dependency. It only changes when `pubspec.lock` does, so it costs nothing on most builds; turn it on freely. |
| Vulnerability | `false` | Seconds; minutes on the first run | It needs the <tooltip term="Trivy database">Trivy database</tooltip>, which is downloaded on the first run and refreshed when outdated. |
| Filesystem | not available | Seconds to minutes | It reads the whole package, most of which `build_runner` cannot see. |

Because the builders rerun only when their inputs change, enabling the license and vulnerability scans on build costs
little: both reread only when `pubspec.lock` changes. A new <tooltip term="CVE">CVE</tooltip> for an unchanged lock
file is not noticed by an incremental build, though - which is why CI should run the command line on a schedule. See
[CI integration](CI-Integration.md).

## How a scan fails

| What happened | Builder | Command line |
|:--|:--|:--|
| Findings, `fail_on_findings: true` | `SEVERE` with the findings; the build fails | Findings printed, exit code `1` |
| Findings, `fail_on_findings: false` | `WARNING` with the findings | Findings printed with *(not failing)*, exit code `0` |
| No findings | Logged at `FINE` only | `no findings.` |
| Nothing to scan | Skipped, with the reason in the report | `Trivy <scan> scan skipped: <reason>` |
| Trivy is missing, crashes or cannot download its database | `SEVERE` with Trivy's error | Exit code `69` with Trivy's error |

A scan never passes because Trivy failed: findings are read from Trivy's JSON report, and any non-zero exit of Trivy
is reported as an error, not as a result. `--exit-zero` does not hide it.

<tip>
<code>inspectra scan</code> runs a Trivy filesystem scan as part of the supply-chain checks, independent of
<code>trivy.enabled</code>. Its <code>trivy.mode</code> decides whether a missing Trivy is skipped with a warning or is
an error - see <a href="Trivy-Installation.md#provisioning">Provisioning</a>.
</tip>

<seealso>
    <category ref="security">
        <a href="Trivy-Installation.md">Installing Trivy</a>
        <a href="Trivy-Severities.md">Severities</a>
        <a href="Trivy-Reports.md">Reports</a>
        <a href="Trivy-Configuration-Reference.md">Configuration reference</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
    </category>
    <category ref="external">
        <a href="%trivy_docs%">Trivy documentation</a>
    </category>
</seealso>
