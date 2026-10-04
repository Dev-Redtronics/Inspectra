# Installing Trivy

<primary-label ref="config"/>
<secondary-label ref="requires-trivy"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter,procedure" depth="2"/>

<link-summary>Installing Trivy, how Inspectra finds it, and how to run it offline or behind a mirror.</link-summary>

<card-summary>Installation, executable lookup, working directory, environment variables and offline use.</card-summary>

<tldr>
<p><b>Lookup order</b>: <code>%trivy_env%</code>, then <code>trivy.executable</code>, then <code>trivy</code> on the <code>PATH</code></p>
<p><b>Tested with</b>: Trivy %tested_trivy%</p>
<p><b>Working directory</b>: the package root</p>
</tldr>

%product% does not bundle Trivy. It runs whatever Trivy you install, which keeps the scanner and its database under
your control and lets you update Trivy without waiting for a %product% release.

## Installing

<tabs group="os">
    <tab title="macOS" group-key="macos">
        <code-block lang="bash"><![CDATA[
brew install trivy
]]></code-block>
    </tab>
    <tab title="Debian / Ubuntu" group-key="debian">
        <code-block lang="bash"><![CDATA[
sudo apt-get install -y wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
]]></code-block>
    </tab>
    <tab title="Windows" group-key="windows">
        <code-block lang="powershell"><![CDATA[
choco install trivy
# or
scoop install trivy
]]></code-block>
    </tab>
    <tab title="GitHub Actions" group-key="actions">
        <code-block lang="yaml"><![CDATA[
- uses: aquasecurity/setup-trivy@v0.3.1
  with:
    version: v%tested_trivy%
]]></code-block>
    </tab>
    <tab title="Container image" group-key="docker">
        <code-block lang="bash"><![CDATA[
# Copy the binary out of the official image, e.g. in a Dockerfile:
# COPY --from=aquasec/trivy:%tested_trivy% /usr/local/bin/trivy /usr/local/bin/trivy
docker run --rm aquasec/trivy:%tested_trivy% --version
]]></code-block>
    </tab>
</tabs>

Other methods are listed in [Trivy's installation guide](%trivy_install%). Check the result:

```bash
trivy --version
```

## How Inspectra finds Trivy {id="lookup"}

%product% decides which executable to start in this order:

1. The environment variable **`%trivy_env%`**, if it is set.
2. **`trivy.executable`** from the configuration, if it is set.
3. **`trivy`**, looked up on the `PATH`.

<tabs group="lookup">
    <tab title="Configuration" group-key="config">
        <code-block lang="yaml"><![CDATA[
inspectra:
  trivy:
    enabled: true
    executable: tools/trivy       # relative to the package root, or absolute
]]></code-block>
    </tab>
    <tab title="Environment" group-key="env">
        <code-block lang="bash"><![CDATA[
INSPECTRA_TRIVY=/opt/trivy/bin/trivy dart run inspectra trivy
]]></code-block>
    </tab>
</tabs>

The environment variable exists for CI images that keep Trivy somewhere else than developer machines: it overrides
the configuration without editing it.

When the executable cannot be started, the scan fails with:

```text
Could not start Trivy ("trivy"): No such file or directory
Install it (https://trivy.dev/latest/getting-started/installation/), or point "trivy.executable" or the INSPECTRA_TRIVY environment variable at it.
```

## Working directory {id="working-directory"}

Trivy runs with the **package root** as its working directory - the directory of `pubspec.yaml`, or the directory
given with `-C`. Trivy reads several files from its working directory, so these apply to every scan:

<deflist type="medium">
    <def title="trivy.yaml">
        Trivy's own configuration file: cache directory, database repository, timeouts and so on. Settings
        %product% passes on the command line - scanners, severities, format - take precedence over it.
    </def>
    <def title=".trivyignore">
        Findings to ignore, one identifier per line: vulnerability IDs, secret rule IDs, license names. It applies on
        top of %product%'s own <code>ignored_*</code> options.
    </def>
    <def title="trivy-secret.yaml">
        Secret rules. %product% passes it explicitly with <code>--secret-config</code> - see
        <a href="Trivy-Secret-Rules.md">Secret rules</a>.
    </def>
</deflist>

<note>
The working directory is the package root even when you run <code>dart run %package% -C packages/core</code> from a
repository root. Each package of a monorepo uses its own <code>.trivyignore</code> and <code>trivy.yaml</code>.
</note>

## Environment variables

%product% passes its environment to Trivy unchanged, so every `TRIVY_*` variable works:

| Variable | Effect |
|:--|:--|
| `TRIVY_CACHE_DIR` | Where Trivy keeps its database and cache, instead of `~/.cache/trivy`. Point it at a directory your CI caches. |
| `TRIVY_DB_REPOSITORY` | The registry the vulnerability database is downloaded from, such as an internal mirror. Default `mirror.gcr.io/aquasec/trivy-db`. |
| `TRIVY_JAVA_DB_REPOSITORY` | The same for the Java database, which Dart scans do not use. |
| `TRIVY_SKIP_DB_UPDATE` | `true` uses the database already in the cache without checking for a newer one. |
| `TRIVY_OFFLINE_SCAN` | `true` makes Trivy avoid network requests during the scan itself. |
| `TRIVY_SKIP_VERSION_CHECK` | `true` stops Trivy from checking for a newer Trivy release. |
| `TRIVY_INSECURE` | `true` skips TLS verification for registries; only behind a trusted proxy. |

## Offline and air-gapped use

Only the vulnerability scan - and the filesystem scan with the `vuln` scanner - needs the
<tooltip term="Trivy database">Trivy database</tooltip>. The secret and license scans work without network access.

<procedure title="Run the vulnerability scan without network access" id="offline">
    <step>
        <p>On a machine with network access, download the database into a directory:</p>
        <code-block lang="bash"><![CDATA[
TRIVY_CACHE_DIR=./trivy-cache trivy fs --download-db-only
]]></code-block>
    </step>
    <step>
        <p>Copy <code>trivy-cache</code> to the offline machine or bake it into the CI image.</p>
    </step>
    <step>
        <p>Run %product% against it without updating:</p>
        <code-block lang="bash"><![CDATA[
TRIVY_CACHE_DIR=./trivy-cache TRIVY_SKIP_DB_UPDATE=true TRIVY_OFFLINE_SCAN=true \
  dart run inspectra trivy vulnerability
]]></code-block>
    </step>
</procedure>

<warning>
A database that is never updated never learns about new vulnerabilities. Refresh it on a schedule; Trivy's database is
rebuilt every few hours upstream.
</warning>

## Versions

%product% uses Trivy's stable command line: `trivy fs`, `--scanners`, `--severity`, `--format json`, `--output`,
`--secret-config`, `--skip-dirs`, `--ignore-unfixed` and `--license-full`, and reads the `Results` of the JSON report.
It is tested with Trivy %tested_trivy%; any release since Trivy introduced `--scanners` should work. See
[Compatibility](Compatibility.md).

<seealso>
    <category ref="security">
        <a href="Trivy-Overview.md">Security and compliance</a>
        <a href="Trivy-Secret-Rules.md">Secret rules</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
        <a href="Troubleshooting.md">Troubleshooting</a>
    </category>
    <category ref="external">
        <a href="%trivy_install%">Trivy installation</a>
        <a href="%trivy_docs%/configuration/">Trivy configuration</a>
    </category>
</seealso>
