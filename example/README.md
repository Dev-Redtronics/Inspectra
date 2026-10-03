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
