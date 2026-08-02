# Feature Specification: Evidence-backed Course Explanation

**Feature Branch**: `001-evidence-backed-course-explanation`
**Created**: 2026-08-03
**Status**: Draft
**Input**: User wants a separate LLM wiki repository that Hanjeok can use to explain public-data-based course recommendations.

## User Scenarios

### Scenario 1: Explain a crowded destination course

Given the Hanjeok backend has generated a course for a crowded destination, when the explanation layer retrieves wiki context, then the generated explanation must state that the backend selected the course and describe congestion, alternatives, and time-slot ordering.

### Scenario 2: Avoid LLM ranking changes

Given the backend returns a ranked course, when the LLM wiki is used, then it must not reorder the course, invent attractions, or change scores.

### Scenario 3: Trace public-data compliance

Given an operator asks why Hanjeok separates raw and derived data, when the wiki is queried, then the answer must trace back to OpenAPI briefing evidence and Hanjeok design evidence.

## Functional Requirements

- FR-001: The repository must preserve OpenAPI briefing, Hanjeok design, and harness snapshots under `raw/`.
- FR-002: The repository must define canonical pages for congestion diagnosis, alternative scoring, course generation, raw/derived separation, and LLM ranking boundary.
- FR-003: Canonical pages must include frontmatter with `title`, `created`, `updated`, `type`, `tags`, `sources`, `confidence`, `contested`, and `contradictions`.
- FR-004: Every canonical `sources` item must point to an existing file under `raw/`.
- FR-005: The smoke harness must fail when index count and canonical filesystem count diverge.
- FR-006: The LLM wiki must be documented as an explanation layer, not a recommendation decision layer.
- FR-007: Spec Kit scaffolding must exist for future SDD workflows.

## Non-Goals

- Build a runtime vector database.
- Call live public APIs.
- Search external papers per user request.
- Create a production prompt gateway.

## Success Criteria

- SC-001: `./harness/scripts/smoke.sh` passes on a fresh clone.
- SC-002: README explains how Hanjeok can integrate the wiki.
- SC-003: A future worker can start from `specs/001-evidence-backed-course-explanation/` and continue SDD work.

## Key Entities

- Evidence source: copied source file under `raw/`.
- Canonical page: curated Markdown page with source-backed claims.
- Explanation query: reusable query page that maps backend facts to user-facing explanation rules.

