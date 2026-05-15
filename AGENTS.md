# AGENTS.md — gcs-yaml-importer

## Purpose

`gcs-yaml-importer` bridges the gap between nested YAML configuration files and GitHub Actions' flat key=value output system. It reads a YAML file at a configurable query path, optionally merges it with default values from a second file, and generates an executable shell script. When sourced in a GitHub Actions step, that script populates the step's output variables with flattened key=value pairs. Downstream jobs can then consume structured config as simple `${{ steps.id.outputs.key_subkey }}` references.

This action is a foundational dependency of `gcs-versioning-bot` and many other Partior CI/CD actions.

## Repository Map

```
gcs-yaml-importer/
├── action.yml                         # Composite action definition
├── scripts/
│   ├── yaml-converter.sh              # Core: reads YAML, generates importer shell script
│   ├── get-importer-filename.sh       # Resolves output filename (respects output-file input)
│   └── clean-files.sh                 # Removes intermediate work files
├── config/
│   └── general.ini                    # Internal config (script paths, defaults)
├── test-yaml/                         # YAML fixtures for integration tests
│   └── testing.yaml                   # Multi-project test config
├── LICENSE.md
└── README.md
```

## Tech Stack

- **GitHub Actions** — Composite action (`runs: composite`)
- **Shell (bash)** — All scripts
- **yq** >= v4 — YAML querying and iteration (must be installed before calling this action)
- **`$GITHUB_OUTPUT`** — Modern output mechanism used in generated scripts

## Architecture Patterns

- **Code generation pattern**: The action doesn't set outputs directly — it generates a shell script (the "importer") that, when executed by a subsequent step, sets all outputs at once.
- **Two-phase usage**: (1) Call the action to generate the importer file. (2) Run/source the importer file in a `run:` step to populate outputs.
- **Artifact upload for cross-job sharing**: With `upload: true`, the importer file is uploaded as a workflow artifact, allowing jobs on different runners to `download-artifact` and source it.
- **Default merging**: When `yaml-file-for-default` is provided, the action merges the default values under the primary values, so keys missing from the primary are backfilled from defaults.
- **Sub-default keys**: The `set-sub-default-keys` input allows merging specific sub-keys within the same file as additional fallback layers.

## Development Commands

```bash
# Validate action.yml syntax
yq '.' action.yml

# Test yaml-converter.sh directly
bash scripts/yaml-converter.sh test-yaml/testing.yaml .project2 "" "" "" ""

# Verify generated importer is valid shell
bash -n start_import.sh

# Source importer and inspect outputs (local simulation)
# Note: $GITHUB_OUTPUT won't be set locally; redirect to see output
GITHUB_OUTPUT=/dev/stdout bash start_import.sh

# Run full test scenarios (as described in README)
cat test-yaml/testing.yaml
```

## Environment Setup

```bash
# yq MUST be installed before calling this action
# Use gcs-setup-yq or install directly:
YQ_VERSION=v4.35.1
wget "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
  -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# Verify
yq --version
```

## Coding Conventions

- `yaml-converter.sh` generates lines of the form: `echo "KEY=VALUE" >> $GITHUB_OUTPUT`
- Key flattening rules:
  - YAML hierarchy levels joined with `_`
  - Hyphens (`-`) in key names are preserved as-is (NOT replaced with underscores) in the output variable name
  - Example: `.ci-pipeline.build-cmd` → output key `ci-pipeline_build-cmd`
- The importer script must be executable (`chmod +x`) before it can be run directly; or use `source`/`.` to execute it.
- `general.ini` holds internal path and default configuration — do not rename variables referenced there.
- Scripts use `set -euo pipefail`.

## Testing

- Integration tests are defined in the sample workflow in the README, using `test-yaml/testing.yaml` as fixtures.
- Test scenarios cover: no query scope, scoped query, custom output filename, default merging, and artifact upload/download.
- To add a test: add a new key in `test-yaml/testing.yaml` and a corresponding scenario in the test workflow.
- Local testing: export `GITHUB_OUTPUT` to a temp file, source the generated importer, then inspect the file contents.

## Key Abstractions

| Abstraction | Description |
|-------------|-------------|
| `yaml-converter.sh` | Core logic: uses `yq` to walk the YAML tree at `query-path` and emit `key=value` lines |
| Importer script | Generated shell script; when sourced, populates `$GITHUB_OUTPUT` with flattened YAML values |
| `query-path` | yq-syntax path (e.g., `.smc.ci.branches.main`) that scopes which YAML section to import |
| Default merging | Values from `yaml-file-for-default` + `query-path-for-default` backfill missing keys |
| `upload: true` | Uploads the importer as a GitHub artifact for cross-job consumption |
| `importer-filename` output | The filename of the generated script — callers use this to source or download the file |

## Agentic Task Guidance

✅ **Safe to add** support for additional `yq` output formats (e.g., exporting list values as comma-separated strings).  
✅ **Safe to update** `clean-files.sh` to clean additional intermediate files.  
✅ **Safe to add** test YAML files to `test-yaml/` to cover new scenarios.  
⚠️ **Be careful** changing key flattening logic in `yaml-converter.sh` — this is a breaking change; all callers reference output variable names by their flattened form.  
⚠️ **Be careful** changing the default `output-file` name (`start_import.sh`) — callers that don't set `output-file` depend on this default.  
⚠️ **Be careful** with the `upload` artifact name — it defaults to the `output-file` basename; callers use `actions/download-artifact` with that exact name.  
❌ **Do not** change the `importer-filename` output key name — it is referenced by downstream actions including `gcs-versioning-bot`.  
❌ **Do not** use `::set-output` (deprecated) in the generated importer scripts — use `$GITHUB_OUTPUT`.  
❌ **Do not** call this action before `yq` is installed — the scripts will fail with `command not found`.

## External Dependencies

- **`yq`** >= v4 — Must be pre-installed on the runner (use `gcs-setup-yq@partior-stable`)
- **`actions/upload-artifact@v4`** — Called internally when `upload: true`
- No network access required beyond artifact upload

## Common Pitfalls

- **`yq` not installed**: The most common failure. Always add a `gcs-setup-yq` step before `gcs-yaml-importer` in the same job.
- **Sourcing vs executing**: The importer script sets `$GITHUB_OUTPUT` correctly only when run as a `run:` step in GitHub Actions. Running it outside of a workflow step (e.g., in a subshell) will not populate the step outputs.
- **Wrong `query-path`**: An incorrect path (e.g., typo in branch name) produces an empty importer with no outputs. Validate paths with `yq '<path>' <file>` before committing.
- **Output variable name collisions**: If two keys at different YAML depths flatten to the same variable name, the last one wins. Design YAML schemas to avoid this.
- **Cross-job artifact name**: When using `upload: true`, the artifact name is the `output-file` basename. If two jobs run concurrently and use the same `output-file` name, they will overwrite each other's artifact. Use unique names (e.g., include `${{ github.run_id }}`).
- **YAML boolean/number values**: `yq` may output booleans as `true`/`false` and numbers without quotes. Callers must handle these as strings in GitHub Actions expressions.
