# Feature Specification: Travel Context Layer

**Feature Branch**: `001-travel-context-layer`
**Created**: 2026-08-03
**Status**: Draft
**Input**: User wants a general LLM wiki repository for travel, tourism, weather, congestion, and regional context. Hanjeok is the first consumer service, not the only purpose.

## User Scenarios

### Scenario 1: Explain a travel recommendation with context

Given a travel service backend has generated a place or route recommendation, when the explanation layer retrieves wiki context, then the generated explanation must state that the backend selected the recommendation and describe congestion, weather, alternatives, and time-slot ordering.

### Scenario 2: Avoid LLM ranking changes

Given the backend returns a ranked course, when the LLM wiki is used, then it must not reorder the course, invent attractions, invent weather, or change scores.

### Scenario 3: Trace public-data compliance

Given an operator asks why a consumer service separates raw and derived data, when the wiki is queried, then the answer must trace back to public API evidence and service snapshot evidence.

## Functional Requirements

- FR-001: The repository must preserve public tourism API evidence and first consumer-service snapshots under `raw/`.
- FR-002: The repository must define canonical pages for congestion diagnosis, weather-aware recommendation, alternative scoring, course generation, raw/derived separation, and LLM ranking boundary.
- FR-003: Canonical pages must include frontmatter with `title`, `created`, `updated`, `type`, `tags`, `sources`, `confidence`, `contested`, and `contradictions`.
- FR-004: Every canonical `sources` item must point to an existing file under `raw/`.
- FR-005: The smoke harness must fail when index count and canonical filesystem count diverge.
- FR-006: The LLM wiki must be documented as a travel context explanation layer, not a recommendation decision layer.
- FR-007: Spec Kit scaffolding must exist for future SDD workflows.

## Non-Goals

- Build a runtime vector database.
- Call live public APIs.
- Search external papers per user request.
- Create a production prompt gateway.

## Success Criteria

- SC-001: `./harness/scripts/smoke.sh` passes on a fresh clone.
- SC-002: README explains how any travel service can integrate the wiki, with Hanjeok as the first example.
- SC-003: A future worker can start from `specs/001-travel-context-layer/` and continue SDD work.

## Key Entities

- Evidence source: copied source file under `raw/`.
- Canonical page: curated Markdown page with source-backed claims.
- Explanation query: reusable query page that maps backend facts to user-facing explanation rules.
