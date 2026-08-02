# Wiki Schema

## Repository Orientation

The repository root is the wiki root. Every operation resolves paths from this root. No database or hosted service is required for the canonical wiki.

Before curating, read `SCHEMA.md`, `index.md`, and the latest entries in `log.md`.

## Layers

1. **Evidence:** immutable or append-only source snapshots under `raw/`.
2. **Canonical Memory:** curated pages under `entities/`, `concepts/`, `comparisons/`, `queries/`, and `decisions/`.
3. **Operation Metadata:** `SCHEMA.md`, `index.md`, `log.md`, harness assets, and Spec Kit artifacts.

## Directory Roles

| Path | Role |
| --- | --- |
| `inbox/` | Temporary intake awaiting classification. Not evidence and not canonical. |
| `raw/openapi-briefing/` | Extracted source records from the 2026 OpenAPI briefing. |
| `raw/hanjeok-design/` | Snapshots copied from Hanjeok design documents. |
| `raw/harness/` | Snapshots copied from Hanjeok scenarios and fixtures. |
| `raw/api-spikes/` | Public API verification results and response samples. |
| `raw/competition/` | Competition submission, review, and compliance source records. |
| `entities/` | Canonical pages whose `type` is `entity`. |
| `concepts/` | Canonical pages whose `type` is `concept`. |
| `comparisons/` | Canonical pages whose `type` is `comparison`. |
| `queries/` | Canonical pages whose `type` is `query`. |
| `decisions/` | Canonical pages whose `type` is `decision`. |
| `research/` | Staging area for human-reviewed research drafts. Not canonical. |
| `harness/` | Scenarios, fixtures, and smoke checks for this wiki. |
| `.specify/` | Spec Kit SDD templates, scripts, and workflow metadata. |

## Canonical Frontmatter

Every canonical page must start at byte zero with YAML frontmatter:

```yaml
---
title: Example
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - recommendation-policy
sources:
  - raw/hanjeok-design/design-v3.md
confidence: medium
contested: false
contradictions: []
---
```

Rules:

- `type` must be one of `entity`, `concept`, `comparison`, `query`, or `decision`.
- `type` must match the containing directory.
- `sources` must point to existing files under `raw/`.
- `confidence` must be `high`, `medium`, or `low`.
- Use `high` only when multiple source records support the claim.
- Use `contested: true` when the source evidence is unresolved or conflicting.
- Preserve `created`; update `updated` whenever content changes.

## Registered Tags

- `api-compliance`
- `api-spike`
- `competition`
- `congestion`
- `course-explanation`
- `course-generation`
- `data-lineage`
- `evidence-wiki`
- `fallback-policy`
- `hanjeok`
- `llm-rag`
- `openapi`
- `public-data`
- `recommendation-policy`
- `sdd`
- `tourapi`

## Source Rules

- Do not edit raw source bodies after capture. Add a new source snapshot instead.
- Raw text, Markdown, JSON, and copied public documents are allowed if registered under `raw/`.
- Canonical pages may synthesize raw sources, but must not cite generated docs, templates, or other canonical pages as `sources`.
- If a canonical claim needs precise attribution, include an inline marker such as `^[raw/openapi-briefing/2026-openapi-briefing.txt]`.

## Link Rules

- Canonical pages should use Obsidian-style `[[wikilinks]]` to connect related pages.
- Once three or more canonical pages exist, each canonical page should link to at least two other active canonical pages.
- Links to `raw/`, `templates/`, `_archive/`, or missing files do not count as canonical links.

## Index And Log Synchronization

For every canonical create, update, archive, or delete:

1. Update `index.md`.
2. Append one entry to `log.md`.
3. Run `./harness/scripts/smoke.sh`.

