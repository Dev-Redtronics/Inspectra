# Inspectra example

Add Inspectra as a dev dependency and enable what you need:

```yaml
# pubspec.yaml
name: my_package

dev_dependencies:
  build_runner: ^2.16.1
  inspectra: ^1.0.0

inspectra:
  api:
    enabled: true
  trivy:
    enabled: true
    license:
      ignored_licenses: [MPL-2.0]
    vulnerability:
      run_on_build: true
  coverage:
    enabled: true
    min_line_coverage: 80
```

Then:

```bash
dart run build_runner build               # writes api/my_package.api, runs the secret and vulnerability scans
git add api/my_package.api                # the dump is committed and reviewed like code

dart run build_runner build --only-check  # in CI: fails when the API dump is outdated
dart run inspectra check                  # in CI: API check, all Trivy scans, coverage gate
```

## Supply-chain security

```bash
# Full project scan (OSV.dev, supply chain checks, Trivy) — the default command
dart run inspectra
dart run inspectra scan --recursive          # every package of a monorepo

# CI: SARIF for GitHub code scanning, fail only on HIGH or worse
dart run inspectra scan -f sarif -o inspectra.sarif --fail-on high

# Vet a package before adding it, then add exactly the vetted version
dart run inspectra inspect some_package 1.2.3
dart run inspectra add some_package 1.2.3 --dev

# Trivy control
dart run inspectra trivy --where             # which Trivy would be used
dart run inspectra trivy --install           # download it now (e.g. to warm a CI cache)
dart run inspectra --trivy-version latest    # newest release
dart run inspectra --no-trivy-download       # never download
```

See [`inspectra.example.yaml`](../inspectra.example.yaml) for every configuration key.
