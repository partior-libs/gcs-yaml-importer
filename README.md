# gcs-yaml-importer

> GitHub Composite Action that parses a YAML configuration file and exports its key-value pairs as flat GitHub Actions environment variables, with support for default-value overlays and optional artifact upload.

## Overview

`gcs-yaml-importer` uses `yq` to traverse a YAML file at an optional query path and converts each leaf value into a flat environment variable file (importer file) suitable for `source`-ing in subsequent steps. It supports:

- A **primary** YAML file and an optional **default** YAML file (values in the primary override the default).
- Sub-default keys — specific nested paths to merge as fallback defaults.
- Overriding the `artifact-base-name` field across both YAML files before parsing.
- Optional upload of the generated importer file as a GitHub Actions artifact.

## Usage

```yaml
- id: import-config
  uses: partior-libs/gcs-yaml-importer@main
  with:
    yaml-file: config/smc-app.yaml
    query-path: .my-service.ci
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `yaml-file` | Path to the primary YAML file to parse | Yes | `default-config.yaml` |
| `yaml-file-for-default` | Path to a YAML file providing fallback/default values | No | `""` |
| `query-path` | `yq`-style query path within the primary YAML (e.g. `.my-service.ci`) | No | `""` (root) |
| `query-path-for-default` | `yq`-style query path within the default YAML file | No | `""` |
| `set-sub-default-keys` | Comma-delimited list of sub-paths in the primary YAML to treat as defaults (e.g. `ci.branches.default`) | No | `""` |
| `set-sub-default-keys-for-default` | Same as above but for the default YAML file | No | `""` |
| `output-file` | Custom path for the generated importer file | No | *(auto-generated)* |
| `upload` | Upload the importer file as a GitHub Actions artifact | No | `false` |
| `override-artifact-base-name` | Override the `artifact-base-name` key in both YAML files before parsing | No | `""` |

## Outputs

| Output | Description |
|--------|-------------|
| `importer-filename` | Path to the generated importer environment file |

## Prerequisites

- `yq` must be installed on the runner. Use [`gcs-setup-yq`](../gcs-setup-yq/) if it is not pre-installed.
- YAML files must be committed to the repository or downloaded before this step runs.

## Examples

### Import versioning config

```yaml
- uses: partior-libs/gcs-setup-yq@main

- id: import
  uses: partior-libs/gcs-yaml-importer@main
  with:
    yaml-file: config/versioning-rules.yaml
    query-path: .artifact-auto-versioning

- name: Source and use variables
  run: |
    source ${{ steps.import.outputs.importer-filename }}
    echo "Versioning strategy: $artifact_auto_versioning_strategy"
```

### Import with defaults overlay

```yaml
- id: import-with-defaults
  uses: partior-libs/gcs-yaml-importer@main
  with:
    yaml-file: config/smc-app.yaml
    yaml-file-for-default: config/smc-default.yaml
    query-path: .my-service.ci
    query-path-for-default: .default.ci
    set-sub-default-keys: ci.branches.default
    upload: "true"
```

### Override artifact base name

```yaml
- uses: partior-libs/gcs-yaml-importer@main
  with:
    yaml-file: config/app.yaml
    override-artifact-base-name: my-overridden-artifact
```

## Project Structure

```
gcs-yaml-importer/
├── action.yml                         # Composite action definition
├── scripts/
│   ├── yaml-converter.sh              # Core yq-based YAML → env-var conversion
│   ├── clean-files.sh                 # Removes stale importer files before generation
│   └── get-importer-filename.sh       # Resolves/returns the importer file path
├── config/
│   └── general.ini                    # Default configuration constants
├── test-yaml/
│   ├── smc-app.yaml                   # Example primary YAML for testing
│   ├── smc-default.yaml               # Example default YAML for testing
│   └── testing.yaml                   # Additional test fixture
└── .github/workflows/
    ├── ci-workflow.yaml               # Main CI pipeline
    ├── unit-test.yml                  # Unit test workflow
    └── tag-partior-stable.yml         # Stable release tagging
```

## Contributing

1. Fork the repository and create a feature branch.
2. Add test YAML files to `test-yaml/` to cover new scenarios.
3. Run the unit tests via `.github/workflows/unit-test.yml`.
4. Open a pull request targeting `main`.

## License

Proprietary — Copyright 2025 Partior. All rights reserved.
