# Wiki Batch Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic repo-local batch pipeline for sanitized user input, external data snapshots, and retrieval index/package validation.

**Architecture:** The wiki remains a Git-first context repository. Batch scripts only capture sanitized or already-exported evidence into `raw/`, then rebuild or check static retrieval files under `indexes/`. Runtime services consume `packages/` and keep private user history and live operational data outside this repository.

**Tech Stack:** Bash, jq, Markdown, GitHub Actions, existing harness smoke checks.

## Global Constraints

- Do not commit API keys, tokens, private user travel history, or precise private location traces.
- User input may enter this repo only when it is sanitized and explicitly marked as wiki-shareable.
- External collection is file-based in this repo; live authenticated API polling belongs in a consumer backend or a separately configured scheduled job.
- Every batch command must be deterministic and verifiable with `./harness/scripts/smoke.sh`.

---

### Task 1: Batch Contracts And Fixtures

**Files:**
- Create: `harness/fixtures/user-input-capture.valid.json`
- Create: `harness/fixtures/external-tourism-snapshot.valid.json`
- Modify: `SCHEMA.md`
- Modify: `README.md`

**Interfaces:**
- Produces: JSON contracts consumed by the capture scripts.

- [x] Add a sanitized user-input fixture with `consentForWiki: true` and `containsPersonalData: false`.
- [x] Add an external snapshot fixture with `sourceKind`, `sourceUrl`, `license`, `collectedAt`, and `payload`.
- [x] Document the boundary between wiki-local batch and backend runtime batch.

### Task 2: Capture Scripts

**Files:**
- Create: `scripts/collect-user-input.sh`
- Create: `scripts/collect-external-snapshot.sh`
- Modify: `harness/scripts/smoke.sh`

**Interfaces:**
- `scripts/collect-user-input.sh <input-json> <output-dir>` writes `<output-dir>/<captureId>.json`.
- `scripts/collect-external-snapshot.sh <input-json> <output-dir>` writes `<output-dir>/<sourceKind>-<snapshotId>.json`.

- [x] Implement user-input validation that rejects personal data and non-consented input.
- [x] Implement external snapshot validation that rejects missing source, license, or payload metadata.
- [x] Add smoke checks that run both scripts against fixtures in a temporary directory.

### Task 3: Retrieval Index Batch

**Files:**
- Create: `scripts/build-index.sh`
- Modify: `harness/scripts/smoke.sh`
- Modify: `.github/workflows/wiki-batch.yml`

**Interfaces:**
- `scripts/build-index.sh` regenerates `indexes/manifest.json`, `indexes/chunks.jsonl`, and `indexes/source-map.json`.
- `scripts/build-index.sh --check` fails when committed index files are stale.

- [x] Implement deterministic index generation from canonical pages, records, packages, and source paths.
- [x] Add smoke validation for `scripts/build-index.sh --check`.
- [x] Add a scheduled GitHub Actions workflow that runs smoke and index checks without secrets.

### Task 4: Verification And Commit

**Files:**
- Modify: `log.md`

**Interfaces:**
- Produces: committed batch pipeline scaffold.

- [x] Run `./harness/scripts/smoke.sh`.
- [x] Run `scripts/build-index.sh --check`.
- [ ] Commit and push the completed batch pipeline.
