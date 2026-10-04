# Inspectra examples

```bash
# Install
dart pub global activate inspectra

# Full project scan (OSV.dev, supply chain checks, Trivy) — the default command
inspectra
inspectra scan --recursive          # every package of a monorepo

# CI: SARIF for GitHub code scanning, fail only on HIGH or worse
inspectra scan -f sarif -o inspectra.sarif --fail-on high

# Only the OSV.dev audit, dart_audit compatible JSON
inspectra audit --format json

# Vet a package before adding it, then add exactly the vetted version
inspectra inspect some_package 1.2.3
inspectra add some_package 1.2.3 --dev

# Trivy control
inspectra trivy --where                     # which Trivy would be used
inspectra trivy --install                   # download it now (e.g. to warm a CI cache)
inspectra --trivy-version latest            # newest release
inspectra --no-trivy-download               # never download
inspectra --trivy-mode required             # fail with 69 when Trivy is unavailable
```

See [`inspectra.example.yaml`](../inspectra.example.yaml) for every configuration key.
