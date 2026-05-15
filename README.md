# gcs-yaml-importer
> Reads a multi-tiered YAML configuration file and generates a shell script that populates GitHub Actions flat output variables.

## Overview

`gcs-yaml-importer` solves a core CICD problem: YAML configuration files have nested structure, but GitHub Actions job outputs are flat key=value pairs. This action bridges that gap by:

1. Reading a YAML file (optionally merged with a defaults file) at a given `query-path`.
2. Generating an executable shell script (`start_import.sh` by default) that, when sourced, sets all keys as GitHub Actions step outputs using flattened dot-separated names (`.` and `-` become `_`).
3. Optionally uploading the script as a workflow artifact so downstream jobs (on different runners) can download and source it.

This enables downstream jobs to consume structured YAML config as simple `${{ steps.id.outputs.key_subkey }}` references without any additional YAML parsing tooling.

## Usage

### Basic — read entire YAML file

```yaml
- name: Import YAML config
  id: importer
  uses: partior-libs/gcs-yaml-importer@partior-stable
  with:
    yaml-file: config/default.yaml
    query-path: .

- name: Source the importer
  id: config
  run: ./${{ steps.importer.outputs.importer-filename }}

- name: Use a value
  run: echo "App name = ${{ steps.config.outputs.app_name }}"
```

### With query scope (most common pattern)

```yaml
- name: Import branch-specific config
  id: branch-importer
  uses: partior-libs/gcs-yaml-importer@partior-stable
  with:
    yaml-file: controller-config-files/projects/default.yml
    query-path: .smc.ci.branches.${{ steps.repo.outputs.branch-name }}
    yaml-file-for-default: controller-config-files/projects/default.yml
    query-path-for-default: .smc.ci.branches.default
    output-file: branch-config-importer
    upload: true
```

### Cross-job consumption via artifact download

```yaml
# Producer job
- uses: partior-libs/gcs-yaml-importer@partior-stable
  with:
    yaml-file: config.yaml
    query-path: .project
    output-file: my-config-importer
    upload: true

# Consumer job (different runner)
- uses: actions/download-artifact@v4
  with:
    name: my-config-importer
- name: Source config
  id: cfg
  run: source ./my-config-importer
- run: echo "${{ steps.cfg.outputs.project_version }}"
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `yaml-file` | Yes | `default-config.yaml` | Path to the primary YAML file to import |
| `query-path` | No | `.` | yq-style query path to scope the import (e.g., `.smc.ci`, `.project.branches.main`) |
| `yaml-file-for-default` | No | — | Path to a YAML file providing default/fallback values |
| `query-path-for-default` | No | — | Query path within the defaults file |
| `set-sub-default-keys` | No | — | Comma-delimited list of sub-keys within the primary file to also treat as defaults |
| `set-sub-default-keys-for-default` | No | — | Comma-delimited list of sub-keys within the defaults file to also merge |
| `output-file` | No | `start_import.sh` | Custom filename (and path) for the generated importer script |
| `upload` | No | `false` | If `true`, uploads the importer script as a GitHub Actions artifact for use by downstream jobs |
| `override-artifact-base-name` | No | — | Override the artifact name used when uploading (defaults to the `output-file` basename) |

## Outputs

| Output | Description |
|--------|-------------|
| `importer-filename` | Filename of the generated importer shell script |

## How It Works

1. **`scripts/yaml-converter.sh`** — Uses `yq` to walk the YAML tree at `query-path`, flattening each leaf into a `key=value` pair. Nested keys are joined with `_`. For example, `.project.ci-pipeline.build-cmd: npm run build` becomes `ci-pipeline_build-cmd=npm run build`.
2. **`scripts/get-importer-filename.sh`** — Resolves the output filename (respects `output-file` input).
3. The generated script contains lines like: `echo "key=value" >> $GITHUB_OUTPUT`
4. When a step `run`s or `source`s the script, all values are injected into the step's GitHub Actions output context.
5. **`scripts/clean-files.sh`** — Cleans up intermediate work files.

## Key Variable Naming Rules

- YAML key hierarchy separator `.` → `_`
- Hyphen `-` in key names → preserved as `_` in output variable names
- Example: `artifact-auto-versioning.enabled` → `artifact-auto-versioning_enabled`

## Full Workflow Example

```yaml
name: Test YAML Importer
on: [push, workflow_dispatch]

env:
  CONFIG_IMPORTER: project-config-${{ github.run_id }}

jobs:
  read-config:
    runs-on: ubuntu-latest
    outputs:
      project-name: ${{ steps.cfg.outputs.name }}
      ci-enabled: ${{ steps.cfg.outputs.ci-pipeline_enabled }}
    steps:
      - uses: actions/checkout@v4

      - name: Generate importer
        id: gen
        uses: partior-libs/gcs-yaml-importer@partior-stable
        with:
          yaml-file: config/projects.yaml
          query-path: .project2
          yaml-file-for-default: config/projects.yaml
          query-path-for-default: .default
          output-file: ${{ env.CONFIG_IMPORTER }}
          upload: true

      - name: Source importer (same job)
        id: cfg
        run: source ./${{ steps.gen.outputs.importer-filename }}

  use-config:
    needs: read-config
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: ${{ env.CONFIG_IMPORTER }}

      - name: Source config (downstream job)
        id: cfg
        run: source ./${{ env.CONFIG_IMPORTER }}

      - name: Print values
        run: |
          echo "Project: ${{ steps.cfg.outputs.name }}"
          echo "Build cmd: ${{ steps.cfg.outputs.ci-pipeline_build-cmd }}"
```

## Supported YAML Input Example

```yaml
default:
  name: default-project
  ci-pipeline:
    codescan: true
    build-cmd: npm run build
  cd-pipeline:
    prod-environments: []

project2:
  name: my-service
  ci-pipeline:
    codescan: false
    build-cmd: make build
  cd-pipeline:
    prod-environments:
      - prod-us
      - prod-eu
```

With `query-path: .project2`, the importer generates outputs:
- `name` = `my-service`
- `ci-pipeline_codescan` = `false`
- `ci-pipeline_build-cmd` = `make build`
- `cd-pipeline_prod-environments` = `[prod-us, prod-eu]`

## Prerequisites

- `yq` must be available on the runner. Install it first using `partior-libs/gcs-setup-yq@partior-stable`.
- The YAML file(s) must be checked out before calling this action.

## Contributing

```
git commit -m "<TICKET_NUMBER> <COMMIT_MESSAGE>"
```

Example: `git commit -m "PLAT-111 Support array values in importer output"`

## License

See [LICENSE.md](LICENSE.md)
