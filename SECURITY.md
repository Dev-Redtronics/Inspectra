# Security Policy

## Supported Versions

Security fixes are released for the latest minor version of the current major release.

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Reporting a Vulnerability

**Do not open a public issue for a security problem.**

Report it privately through GitHub's
[private vulnerability reporting](https://github.com/davils-com/Inspectra/security/advisories/new).

Please include:

- the affected Inspectra version (`inspectra --version`) and the Dart SDK version,
- a description of the impact — what an attacker gains,
- the steps to reproduce it, ideally a minimal project or package archive,
- any mitigation you are already aware of.

## Scope

Inspectra runs with the privileges of the developer or CI agent that executes it, downloads package
archives and the Trivy binary, and starts `git`, `dart`, `flutter` and `trivy`.

The following are **in scope**:

- Inspectra executing or installing a binary or package that failed, or skipped, integrity
  verification;
- a crafted package archive, lockfile, pubspec or OSV/pub.dev response that makes Inspectra write
  outside its cache, execute code, exhaust memory or crash instead of reporting an error;
- a malicious finding or snippet that injects terminal escape sequences or corrupts a JSON, SARIF
  or Markdown report;
- a verification that did not complete but is reported as clean (exit code `0`);
- credentials from the environment or configuration ending up in reports or logs.

The following are **not** vulnerabilities in Inspectra:

- missing detections of the heuristic scanners (regex, entropy, typosquat) — please open a regular
  issue with the sample instead;
- vulnerabilities in Trivy, the Dart SDK, OSV.dev or pub.dev — report those to the respective
  project;
- findings that require an attacker to already have write access to the scanned repository or to
  Inspectra's configuration.

## Hardening Built Into Inspectra

- Package archives are verified against their published SHA-256 checksum and inspected in memory,
  within size, entry and expansion limits; nothing is extracted to disk.
- Trivy downloads are verified against the official `checksums.txt`; the check cannot be disabled.
- All snippets are sanitised before they are printed.
- `--offline` (or `network.offline: true`) makes Inspectra send no HTTP request and download no
  Trivy, and starts Trivy with `--skip-db-update --offline-scan`, so Trivy does not fetch its
  database either. Without a cached database the Trivy part of `scan` is skipped in
  `trivy.mode: auto` and exits with `69` in `required`.
