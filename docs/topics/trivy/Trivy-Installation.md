# Installing Trivy

<primary-label ref="config"/>
<secondary-label ref="requires-trivy"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter,procedure" depth="2"/>

<link-summary>How Inspectra finds or downloads Trivy, how to install it yourself, and how to run it offline or behind a mirror.</link-summary>

<card-summary>Provisioning, checksum-verified downloads, executable lookup, working directory, environment variables and offline use.</card-summary>

<tldr>
<p><b>Command line</b>: <code>trivy.executable</code> or <code>%trivy_env%</code>, else an installed Trivy, else a cached download, else a download</p>
<p><b>Builders</b>: <code>%trivy_env%</code>, then <code>trivy.executable</code>, then <code>trivy</code> on the <code>PATH</code></p>
<p><b>Default version</b>: 0.75.0, SHA-256 verified; tested with Trivy %tested_trivy%</p>
<p><b>Working directory</b>: the package root</p>
</tldr>

%product% does not bundle Trivy. The command line uses an installed Trivy when there is one, and otherwise downloads a
pinned, checksum-verified release from GitHub - only when the network is available. Installing Trivy yourself keeps the
scanner under your control and is what the `build_runner` builders need.

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

Other methods are listed in [Trivy's installation guide](%trivy_install%). Check the result, and which Trivy
%product% would use:

```bash
trivy --version
dart run inspectra trivy --where
```

## How Inspectra finds Trivy {id="lookup"}

### Provisioning on the command line {id="provisioning"}

Every command that runs Trivy - `scan`, `trivy` and `check` - resolves it in this order:

1. **`trivy.executable`**, or the environment variable **`%trivy_env%`**, which overrides it. Nothing else is
   considered: an executable that cannot be run makes Trivy unavailable.
2. With `use_installed: true` (the default), **an installed Trivy**, whatever its version: on the `PATH`, or in a
   well-known directory - `/usr/local/bin`, `/usr/bin`, `/opt/homebrew/bin`, `/home/linuxbrew/.linuxbrew/bin`,
   `/snap/bin`, `~/.local/bin`, `~/bin`, `~/scoop/shims`, `$env:LOCALAPPDATA\Programs\trivy`,
   `$env:LOCALAPPDATA\Microsoft\WinGet\Links` and `C:\ProgramData\chocolatey\bin`.
3. **A cached download** of the configured `version` in `<install directory>/<version>/`.
4. With `use_installed: false`, an installed Trivy of exactly the configured `version`.
5. **A download** of the configured `version` - only when `download: true`, not in `--offline` mode, the download host
   answers within `connectivity_timeout`, and Trivy publishes a build for the platform.

`version: latest` is resolved through the redirect of `latest_release_url` when online; offline, it falls back to the
newest cached version. `mode: disabled` skips the lookup entirely.

```bash
dart run inspectra trivy --where                       # which Trivy, and where it comes from
dart run inspectra trivy --install                     # provision it now, e.g. to warm a CI cache
inspectra scan --trivy-version latest --no-trivy-use-installed
```

What happens when no Trivy can be provisioned depends on the command and on `trivy.mode`:

| Situation | `auto` (default) | `required` |
|:--|:--|:--|
| The Trivy part of `scan`, and `trivy` without configured scans | Skipped with a warning; the other checks still run | Exit code `69` |
| The configured scans of `trivy` and `check` | Exit code `69` | Exit code `69` |

### Downloads {id="download"}

A download takes `trivy_<version>_<platform>.tar.gz` (`.zip` on Windows) and `trivy_<version>_checksums.txt` from
`<download_base_url>/v<version>/`:

| Platform | Release asset |
|:--|:--|
| Linux x64, ARM64, ARM, x86 | `Linux-64bit`, `Linux-ARM64`, `Linux-ARM`, `Linux-32bit` |
| macOS x64, ARM64 | `macOS-64bit`, `macOS-ARM64` |
| Windows x64 | `windows-64bit` (zip); Windows on ARM runs it through the built-in emulation |

- The archive's SHA-256 must match its entry in the release's checksums file. This check cannot be disabled, so an
  unverified binary is never executed.
- Only the `trivy` executable is taken from the archive, which is read in memory.
- The binary is written to a temporary file, made executable and atomically renamed to
  `<install directory>/<version>/trivy`, so concurrent CI jobs never see a half written file. Later runs reuse it.

The install directory is `trivy.install_directory`, by default `<user cache>/inspectra/trivy`:

| Host | User cache |
|:--|:--|
| Linux | `$XDG_CACHE_HOME`, else `~/.cache` |
| macOS | `~/Library/Caches` |
| Windows | `$env:LOCALAPPDATA` |

`INSPECTRA_CACHE_DIR` replaces `<user cache>/inspectra`. To cache Trivy in CI, cache that directory and run
`inspectra trivy --install` once.

### The builders {id="builder-lookup"}

The `build_runner` builders never download anything. They start, in this order:

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

When a builder cannot start the executable, the scan fails with:

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

`--offline` (or `network.offline: true`) guarantees that %product% opens no connection: it never downloads Trivy, and
uses an installed or cached one. For the download itself, point `trivy.download_base_url` at a mirror of the release
assets; it must provide the archives and the checksums file under `<base>/v<version>/`.

```yaml
inspectra:
  trivy:
    download_base_url: https://artifactory.corp/github/aquasecurity/trivy/releases/download
    db_repository: registry.corp/aquasecurity/trivy-db
```

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

For the Trivy run of `scan` and of `trivy` without configured scans, `trivy.skip_db_update`, `trivy.db_repository`
and `trivy.cache_directory` pass the same settings as flags.

<warning>
A database that is never updated never learns about new vulnerabilities. Refresh it on a schedule; Trivy's database is
rebuilt every few hours upstream.
</warning>

## Versions

%product% uses Trivy's stable command line: `trivy fs`, `--scanners`, `--severity`, `--format json`, `--output`,
`--secret-config`, `--skip-dirs`, `--ignore-unfixed` and `--license-full`, and reads the `Results` of the JSON report.
It is tested with Trivy %tested_trivy%, and downloads 0.75.0 unless `trivy.version` says otherwise; any release since
Trivy introduced `--scanners` should work. See [Compatibility](Compatibility.md).

<seealso>
    <category ref="security">
        <a href="Trivy-Overview.md">Security and compliance</a>
        <a href="Trivy-Configuration-Reference.md">Trivy configuration reference</a>
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
