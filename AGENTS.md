# AGENTS.md — gcs-yaml-importer

## Purpose

GitHub Composite Action that parses one or two YAML files and converts their key-value pairs into a flat environment variable file (importer file). The importer file can be `source`-d in subsequent bash steps or passed to other actions (e.g., `gcs-versioning-bot`) as a configuration input. Supports nested path queries, default-value overlays, sub-default key merging, and optional GitHub Actions artifact upload.

## Repository Map

| Path | Role |
|------|------|
| `action.yml` | Composite action definition — inputs, output, step sequence |
| `scripts/yaml-converter.sh` | Core conversion: calls `yq` to extract values and writes flat `KEY=value` lines |
| `scripts/clean-files.sh` | Removes stale importer files before a fresh generation run |
| `scripts/get-importer-filename.sh` | Resolves the output file path (custom or auto-generated) |
| `config/general.ini` | Default configuration constants |
| `test-yaml/smc-app.yaml` | Primary YAML test fixture |
| `test-yaml/smc-default.yaml` | Default YAML test fixture |
| `test-yaml/testing.yaml` | Additional test fixture |
| `.github/workflows/ci-workflow.yaml` | Main CI pipeline |
| `.github/workflows/unit-test.yml` | Unit test workflow |
| `.github/workflows/tag-partior-stable.yml` | Stable release tagging |

## Tech Stack

| Component | Version / Detail |
|-----------|-----------------|
| Action type | GitHub Composite Action |
| Shell | Bash |
| YAML processor | `yq` (mikefarah/yq — must be pre-installed; use `gcs-setup-yq`) |
| Artifact upload | `actions/upload-artifact@v4` (optional) |

## Architecture Patterns

- **Dual-file overlay** — default YAML is processed first, then the primary YAML overlays its values. This mirrors a "defaults then overrides" configuration pattern.
- **Flat variable naming** — YAML keys at any nesting depth are joined with underscores (e.g., `.ci.branches.default.enabled` → `ci_branches_default_enabled`).
- **Sub-default key merging** — specific nested paths can be designated as defaults within either YAML file, enabling partial fallback without processing the entire tree.
- **Importer file format** — output is a plain bash script where each line is `KEY=value`; downstream consumers `source` this file to inject all values as shell variables.

## Development Commands

| Command | Description |
|---------|-------------|
| `bash scripts/yaml-converter.sh test-yaml/smc-app.yaml ".my-service.ci" output.env ""` | Test conversion locally |
| `bash scripts/clean-files.sh output.env` | Clean up a specific importer file |
| `bash scripts/get-importer-filename.sh output.env` | Print resolved output file name |
| `source output.env && env \| grep ci_` | Inspect exported variables after sourcing |
| Trigger `.github/workflows/unit-test.yml` | Run integration tests via workflow dispatch |

## Environment Setup

| Variable/Secret | Description | Example |
|----------------|-------------|---------|
| `yq` binary | Must be on `PATH` — install with `gcs-setup-yq` | `yq version v4.44.x` |
| `yaml-file` input | Path to the primary YAML config | `config/versioning-rules.yaml` |
| `yaml-file-for-default` input | Path to the default YAML config | `config/defaults.yaml` |

## Key Abstractions

- `yaml-converter.sh` — takes `(yaml-file, query-path, output-file, sub-default-keys, [default-yaml-file])` and produces the flat env file. Core logic: `yq eval` at the query path → flatten nested structure → write `KEY=VALUE` lines.
- `importer-filename` output — the path to the generated file; downstream actions reference this to `source` or upload the file.
- `override-artifact-base-name` — pre-processes both YAML files with `yq e -i` to substitute the `artifact-base-name` field before conversion, enabling dynamic artifact naming in multi-service monorepos.

## Agentic Task Guidance

- ✅ Safe: Reading scripts; testing with YAML fixtures in `test-yaml/`; adding new test YAML files; adjusting the `upload` flag; reading the generated importer file to verify output.
- ⚠️ Review: Modifying the key-flattening logic in `yaml-converter.sh` (breaks all downstream consumers); changing the `override-artifact-base-name` in-place edit (affects files on disk); changing `output-file` naming conventions.
- ❌ Avoid: Sourcing importer files that contain untrusted YAML input (risk of shell injection if values contain special characters); using absolute paths for `output-file` that may conflict across concurrent jobs.

## External Dependencies & Integrations

- **`yq` (mikefarah/yq)** — must be available on the runner before this action runs; use `gcs-setup-yq` as a prior step.
- **`actions/upload-artifact@v4`** — used when `upload: "true"` to persist the importer file across jobs.
- **`gcs-versioning-bot`** — primary downstream consumer of the generated importer files.

## Common Pitfalls

- `yq` must be installed before this action; the action does not install it automatically.
- Values containing spaces or special shell characters may cause issues when the importer file is `source`-d — use double-quoting in consuming scripts.
- The `upload: true/false` input is compared as a string (`inputs.upload == 'true'`) — ensure the calling workflow passes the string `"true"`, not the boolean `true`.
- Running two instances of this action in parallel with the same `output-file` path will cause a race condition — use unique `output-file` names per call.
- `override-artifact-base-name` modifies the YAML files on disk in-place — if subsequent steps also read those files, they will see the modified values.
