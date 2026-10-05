# CI integration

<primary-label ref="guide"/>
<secondary-label ref="requires-trivy"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Complete GitHub Actions and GitLab CI pipelines that run every Inspectra check.</link-summary>

<card-summary>Pipelines with Trivy provisioning, database caching, scheduled scans, dashboards and report artifacts.</card-summary>

<tldr>
<p><b>Two commands</b>: <code>dart run build_runner build --only-check</code> and <code>dart run %package% check</code></p>
<p><b>Trivy</b>: <code>check</code>, <code>scan</code> and <code>trivy</code> provision it themselves; only the Trivy builders with <code>run_on_build</code> need it on the <code>PATH</code></p>
<p><b>Cache</b>: <code>~/.cache/trivy</code></p>
<p><b>Schedule</b>: weekly, for new vulnerabilities in unchanged dependencies</p>
</tldr>

A CI job needs to answer two questions: is everything that is generated committed and current, and do all enabled
checks pass? One command each:

```bash
dart run build_runner build --only-check   # API dump current; checks enabled on build pass
dart run inspectra check                   # format, lint, style, API, changelog, every enabled scan, coverage gate
```

`--only-check` covers every builder - also those of `json_serializable`, `freezed` and the like - so it doubles as
the check for stale generated code. `inspectra check` reads the file system directly, so its secret scan also sees
files that are not build sources.

`check`, `scan` and `trivy` provision Trivy themselves: an installed one, a cached download, or a checksum-verified
download of the pinned release - see [Installing Trivy](Trivy-Installation.md#provisioning). The `build_runner`
builders never download anything, so only a build that runs Trivy scans with `run_on_build: true` needs Trivy on the
`PATH`, or in `%trivy_env%`, before it starts. `inspectra trivy --install` provides it.

## GitHub Actions

```yaml
name: CI

on:
  push:
  pull_request:
  schedule:
    # New vulnerabilities are published for dependencies you did not touch.
    - cron: '0 4 * * 1'

permissions:
  contents: read

jobs:
  inspectra:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: dart-lang/setup-dart@v1

      - name: Cache the Trivy database
        uses: actions/cache@v6
        with:
          path: ~/.cache/trivy
          key: trivy-db-${{ runner.os }}-${{ github.run_id }}
          restore-keys: trivy-db-${{ runner.os }}-

      - run: dart pub get

      # Only needed for Trivy builders with run_on_build: inspectra check
      # provisions Trivy itself. The download is checksum verified.
      - name: Provision Trivy
        run: |
          dart run inspectra trivy --install --format json --output "$RUNNER_TEMP/trivy.json"
          dirname "$(jq -r .trivy.executable "$RUNNER_TEMP/trivy.json")" >> "$GITHUB_PATH"

      - name: Generated files and API dump are current
        run: dart run build_runner build --only-check

      - name: Inspectra checks
        run: dart run inspectra check

      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: inspectra-reports
          path: |
            coverage/lcov.info
            .dart_tool/inspectra/trivy/
```

### Provisioning Trivy

`inspectra trivy --install` makes the configured Trivy version available - from the runner, from %product%'s cache or
as a download verified against the release's checksums - and its JSON report names the executable in
`trivy.executable`. Appending its directory to `$GITHUB_PATH` puts it on the `PATH` of every later step, where the
builders find it. Prefer the `PATH` over `%trivy_env%` when your own tests start fake Trivy executables: the
environment variable overrides every configured executable.

[`aquasecurity/setup-trivy`](https://github.com/aquasecurity/setup-trivy) is an alternative that installs Trivy with
a third-party action:

```yaml
- uses: aquasecurity/setup-trivy@v0.3.1
  with:
    version: v%tested_trivy%
```

### The Trivy database cache

The cache key contains the run ID, so every run saves a new cache entry, and `restore-keys` restores the most recent
one. Trivy then only downloads the database when the restored copy is outdated, which takes a fraction of a full
download. A fixed key would restore a database that never gets refreshed in the cache.

### Flutter

Replace `dart-lang/setup-dart` with `subosito/flutter-action@v2`, set `runner: flutter` in the coverage
configuration, and keep the rest.

## GitLab CI

```yaml
inspectra:
  image: dart:stable
  variables:
    TRIVY_CACHE_DIR: "$CI_PROJECT_DIR/.trivy-cache"
  cache:
    key: trivy-db
    paths:
      - .trivy-cache/
  before_script:
    - apt-get update && apt-get install -y wget gnupg
    - wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key
      | gpg --dearmor > /usr/share/keyrings/trivy.gpg
    - echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main"
      > /etc/apt/sources.list.d/trivy.list
    - apt-get update && apt-get install -y trivy
    - dart pub get
  script:
    - dart run build_runner build --only-check
    - dart run inspectra check
  coverage: '/Total\s+(\d+\.\d+)%/'
  artifacts:
    when: always
    paths:
      - coverage/lcov.info
      - .dart_tool/inspectra/trivy/
```

The `coverage` regex reads the total from the coverage table, so GitLab shows it in merge requests. Without Trivy
builders that have `run_on_build` set, the Trivy installation in `before_script` can go: `inspectra check` provisions
Trivy itself. Set `INSPECTRA_CACHE_DIR` to a directory inside the project, such as `$CI_PROJECT_DIR/.inspectra-cache`,
and cache it to keep the download between pipelines.

## Changelog and release notes {id="changelog"}

With `changelog.enabled: true`, `inspectra check` also fails when `CHANGELOG.md` does not document the version of
`pubspec.yaml`; it reads only files, so the default shallow checkout is enough. Jobs that *generate* a changelog read
the Git history and the release tags and need `fetch-depth: 0`. A release job takes its description from the
changelog with `dart run inspectra changelog notes "${GITHUB_REF_NAME#v}" --output RELEASE_NOTES.md`. See
[Releasing](Changelog-Releasing.md#ci) for complete jobs.

## Shared configuration {id="inheritance"}

Repositories that [extend](Configuration-Inheritance.md) a central configuration get its remote bases on the first
run. On runners without network access, run `dart run %package% config fetch` in a step that has it and cache
`INSPECTRA_CACHE_DIR`; a policy of the base also binds the `--set` and `INSPECTRA_*` values of the pipeline.

## Dashboards and CI reports {id="reports"}

`dart run %package% report -f html -o inspectra-report.html` runs every evaluation and writes one self-contained HTML
dashboard to keep as a job artifact; `--also gitlab=gl-code-quality.json --also junit=inspectra-junit.xml` feeds the
merge request widget and the test report of GitLab from the same run. Jenkins, Azure DevOps and SonarQube read the
`junit`, `checkstyle` and `sonarqube` formats. See [Reports and dashboards](Reports.md) for complete jobs.

## Splitting the work

One job is simplest. In larger projects, split by speed and by what needs Trivy:

| Job | Command | Needs Trivy | Typical time |
|:--|:--|:--|:--|
| Format, lint and style | `dart run %package% format`, `dart run %package% lint`, `dart run %package% style` | No | Seconds |
| Generated code | `dart run build_runner build --only-check` | Only for scans with `run_on_build` | Build time |
| API | `dart run %package% api check` | No | Seconds |
| Security | `dart run %package% trivy` | Yes; the command provisions it | Seconds, plus the database |
| Coverage | `dart run %package% coverage` | No | Test suite time |

## Scheduled scans

A vulnerability published today for a dependency you locked last month does not change any file in your repository,
so nothing triggers a build. Run the vulnerability scan on a schedule:

```yaml
on:
  schedule:
    - cron: '0 4 * * 1'      # Mondays, 04:00 UTC
```

Combine it with `ignore_unfixed: true` in the gate and a scheduled run without it, if unfixed vulnerabilities should
not block merges but should stay visible.

## Monorepos and workspaces

Run %product% once per package with `-C`:

```bash
for package in packages/*/; do
  dart run inspectra -C "$package" check || exit 1
done
```

In a <tooltip term="pub workspace">pub workspace</tooltip>, `pubspec.lock` and `.dart_tool/package_config.json` live
in the workspace root; %product% finds them there for every member.

<seealso>
    <category ref="operations">
        <a href="Troubleshooting.md">Troubleshooting</a>
        <a href="Inspectra-On-Itself.md">Inspectra on itself</a>
    </category>
    <category ref="security">
        <a href="Trivy-Installation.md">Installing Trivy</a>
        <a href="Trivy-Reports.md">Reports</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#exit-codes">Exit codes</a>
    </category>
</seealso>
