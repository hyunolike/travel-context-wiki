# Travel Context Wiki Constitution

## Core Principles

### I. Evidence First

Every reusable claim must trace to a file under `raw/`. New travel, tourism, weather, congestion, or regional-context behavior starts by preserving source material or a deterministic fixture before creating canonical synthesis.

### II. Deterministic Recommendation Boundary

The LLM wiki explains recommendations from consuming travel services; it does not decide ranking, reorder courses, invent attractions, invent weather, or override backend facts.

### III. Harness Before Automation

Every new integration path must add or update a Given/When/Then scenario and fixture before scripts, prompts, or generated outputs are changed.

### IV. Index And Log Atomicity

Canonical create, update, archive, or delete work is complete only when the canonical page, `index.md`, and `log.md` are updated together.

### V. Public Data Compliance

OpenAPI usage constraints, raw/derived data separation, local-server storage obligations, operation-account checks, weather-source provenance, and user privacy are first-class product requirements.

## Repository Constraints

- Markdown and Git are the durable storage layer.
- `raw/` source snapshots are immutable after capture.
- API keys, tokens, user travel history, private location records, and personal weather/location traces are never committed.
- Canonical pages live only in `entities/`, `concepts/`, `comparisons/`, `queries/`, and `decisions/`.
- Spec Kit artifacts live under `.specify/` and `specs/`.

## Development Workflow

1. Add or update harness scenario and fixture.
2. Add raw source evidence.
3. Create or update canonical wiki pages.
4. Update `index.md` and `log.md`.
5. Run `./harness/scripts/smoke.sh`.
6. For larger changes, use `$speckit-specify`, `$speckit-plan`, `$speckit-tasks`, and `$speckit-implement`.

## Governance

This constitution supersedes ad hoc note-taking practices in this repository. Changes to the evidence model, canonical directories, weather-source policy, or LLM recommendation boundary require an explicit decision page under `decisions/`.

**Version**: 1.0.0 | **Ratified**: 2026-08-03 | **Last Amended**: 2026-08-03
