# Build sources

<primary-label ref="builder"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Which files build_runner shows the builders, and how to make it show more.</link-summary>

<card-summary>Why an edit to inspectra.yaml may not rerun a build, and the build.yaml that fixes it.</card-summary>

`build_runner` only lets builders read <tooltip term="build source">build sources</tooltip>, and only reruns a build
step when a source it read has changed. That makes incremental builds fast and exact, and it decides what %product%'s
builders can see.

## The default sources

Without a `targets` section in your `build.yaml`, the sources of your package are:

```text
$package$        lib/**          bin/**          test/**
example/**       benchmark/**    tool/**         web/**
integration_test/**              assets/**       node/**
pubspec.yaml     pubspec.lock    README*         CHANGELOG*      LICENSE*
```

Not among them, and therefore invisible to the builders:

- `%config_file%` and `%secret_config%`,
- `analysis_options.yaml`, `build.yaml`, `dart_test.yaml` and other root-level configuration files,
- dotfiles and dot-directories, such as `.env` or `.github/`,
- anything in a directory not listed, such as `api/`, `docs/` or `scripts/`.

## What that means for each builder

| Builder | Affected by | Effect |
|:--|:--|:--|
| `inspectra:format` | Which files it checks | It checks the Dart files among the build sources; with the default sources that is everything under `lib/`, `bin/`, `test/`, `example/`, `tool/` and the other default directories. |
| `inspectra:lint` | `analysis_options.yaml` | `dart analyze` always applies it, but editing it does not rerun the lint check unless the file is a source. |
| `inspectra:api` | Nothing | It reads `pubspec.yaml` and `lib/**`, which are always sources. |
| `inspectra:secret_scan` | Which files it scans | It scans the build sources that match `include` and not `exclude`. A root-level `.env` or `config.yaml` is not scanned by the builder. |
| `inspectra:secret_scan` | `%secret_config%` | The rules are applied, but editing them does not rerun the scan unless the file is a source. |
| all | `%config_file%` | Read from disk with a warning; editing it does not rerun the builders unless it is a source. |
| `inspectra:license_scan`, `inspectra:vulnerability_scan` | Nothing | They read `pubspec.lock`, which is always a source. |

<note>
The command line is not affected at all: <code>dart run %package% trivy secret</code> walks the file system and
applies <code>include</code> and <code>exclude</code> to every file, dotfiles included. That is why CI should run the
command line even when developers rely on the builders.
</note>

## Adding sources

List the extra files in a `targets` section of your package's `build.yaml`. Listing `sources` replaces the default
list, so repeat the defaults you need:

```yaml
# build.yaml
targets:
  $default:
    sources:
      # The defaults this package uses
      - $package$
      - lib/**
      - bin/**
      - test/**
      - example/**
      - tool/**
      - pubspec.yaml
      - pubspec.lock
      - README.md
      - CHANGELOG.md
      # Inspectra's configuration and rules: edits rerun the builders
      - inspectra.yaml
      - trivy-secret.yaml
      # Files the secret scan should see on every build
      - analysis_options.yaml
      - .github/**
      - .env
```

After this, an edit to `%config_file%` or `%secret_config%` reruns the builders on the next build, and the secret scan
covers the workflows and the `.env` file.

<warning>
Do not add the API dump's directory, such as <code>api/**</code>, to the sources. The dump is an output of the
<code>inspectra:api</code> builder, which <code>build_runner</code> tracks as such; declaring it a source as well
gains nothing and invites conflicts between the two roles.
</warning>

## The warning about inspectra.yaml

When the configuration lives in `%config_file%` and it is not a source, every build logs once:

```text
W inspectra:<builder> on $package$:
  inspectra.yaml is not a build_runner source, so editing it does not rerun Inspectra. Add it to the sources in build.yaml, or move the settings to an "inspectra:" section of pubspec.yaml.
```

Either of the two fixes it. Moving the settings into `pubspec.yaml` needs no `build.yaml` at all.

## Forcing a rerun

To rerun every builder regardless of what changed, for example after editing a file that is not a source:

```bash
dart run build_runner clean
dart run build_runner build
```

<seealso>
    <category ref="config">
        <a href="Configuration-Overview.md">Where the configuration lives</a>
    </category>
    <category ref="reference">
        <a href="Builder-Reference.md">Builder reference</a>
    </category>
    <category ref="external">
        <a href="https://github.com/dart-lang/build/blob/master/docs/build_yaml_format.md">build.yaml format</a>
    </category>
</seealso>
