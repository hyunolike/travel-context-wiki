# Operation Log

## 2026-08-03 - create - initial evidence wiki scaffold

- Created repository scaffold for the initial evidence wiki.
- Added OpenAPI briefing extract, first consumer-service design snapshot, harness scenario snapshot, and attraction fixture snapshot under `raw/`.
- Added initial canonical pages for recommendation policy, public API entities, LLM explanation, and architecture decisions.
- Added harness smoke check and Spec Kit scaffolding.

## 2026-08-03 - update - pivot to travel context wiki

- Reframed the repository from a Hanjeok-only evidence wiki into a general travel, tourism, weather, congestion, and regional-context wiki.
- Moved initial Hanjeok files under `raw/service-snapshots/hanjeok/` as first consumer-service snapshots.
- Replaced Hanjeok-specific canonical names with Travel Context Wiki concepts and queries.

## 2026-08-03 - update - add data layer and mermaid workflow

- Added `records/`, `indexes/`, and `packages/` as derived data layers inspired by the 2nd Brain template's evidence-to-canonical workflow.
- Added README Mermaid diagrams for data layers, service integration, operating workflow, and architecture.
- Extended smoke validation to check JSON records, JSONL chunks, manifest paths, package references, and record source paths.

## 2026-08-03 - update - add repo-local batch pipeline

- Added sanitized user-input and external snapshot capture contracts.
- Added repo-local batch scripts for user input capture, external snapshot capture, and deterministic retrieval index generation.
- Added GitHub Actions smoke/index workflow for scheduled and PR validation without secrets.
