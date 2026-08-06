# Wiki Schema

## Repository Orientation

The repository root is the wiki root. Every operation resolves paths from this root. No database or hosted service is required for the canonical wiki.

Before curating, read `SCHEMA.md`, `index.md`, and the latest entries in `log.md`.

## Layers

1. **Evidence:** immutable or append-only source snapshots under `raw/`.
2. **Normalized Records:** derived JSON records under `records/` for places, weather, congestion, events, regions, and papers.
3. **Canonical Memory:** curated pages under `entities/`, `concepts/`, `comparisons/`, `queries/`, and `decisions/`.
4. **Retrieval Artifacts:** static retrieval manifests, chunks, and source maps under `indexes/`.
5. **Service Context Packages:** service-specific bundles and prompts under `packages/`.
6. **Operation Metadata:** `SCHEMA.md`, `index.md`, `log.md`, harness assets, and Spec Kit artifacts.

## Directory Roles

| Path | Role |
| --- | --- |
| `inbox/` | Temporary intake awaiting classification. Not evidence and not canonical. |
| `raw/public-tourism-api/` | Tourism public API briefings, manuals, policy notes, and response contracts. |
| `raw/weather-api/` | Weather API manuals, response samples, and weather-risk interpretation notes. |
| `raw/tourism-research/` | Tourism, congestion, weather, seasonality, and regional travel research records. |
| `raw/service-snapshots/` | Design, harness, and fixture snapshots from services that consume this wiki. |
| `raw/experiments/` | Public API verification results and response samples. |
| `raw/user-input/` | Sanitized, consented user-input captures only. No private history or precise private traces. |
| `raw/external-snapshots/` | File-based external API, document, or research snapshots captured by repo-local batch scripts. |
| `raw/project-guides/` | Captured notes from project guides, PRDs, mentoring material, and delivery requirements. Do not commit proprietary PDF bodies without permission. |
| `records/places/` | Derived place records normalized for service context. |
| `records/weather/` | Derived weather interpretation rules and backend fact requirements. |
| `records/congestion/` | Derived congestion grade and interpretation policies. |
| `records/events/` | Derived event and festival context records. |
| `records/regions/` | Derived regional context records. |
| `records/papers/` | Derived paper metadata and claim summaries. |
| `records/project-artifacts/` | Derived records for PRDs, GitHub issues, pull requests, evaluation reports, deployment URLs, and service packages. |
| `entities/` | Canonical pages whose `type` is `entity`. |
| `concepts/` | Canonical pages whose `type` is `concept`. |
| `comparisons/` | Canonical pages whose `type` is `comparison`. |
| `queries/` | Canonical pages whose `type` is `query`. |
| `decisions/` | Canonical pages whose `type` is `decision`. |
| `research/` | Staging area for human-reviewed research drafts. Not canonical. |
| `_archive/` | Fully superseded canonical pages removed from active navigation. Created on demand. |
| `indexes/` | Static retrieval manifests, chunks, source maps, and retrieval policy. |
| `packages/` | Service-specific context bundles and prompts. |
| `harness/` | Scenarios, fixtures, and smoke checks for this wiki. |
| `scripts/` | Repo-local batch scripts. Must run without secrets. |
| `templates/` | Record and page skeletons. Not evidence, not canonical, never a `sources` target. |
| `docs/` | Architecture notes, diagrams, and working plans. Deliverables only, never evidence. |
| `specs/` | Spec Kit feature specifications, plans, and task lists. |
| `.specify/` | Spec Kit SDD templates, scripts, and workflow metadata. |
| `.agents/` | Agent skill definitions used to operate this repository. |
| `.github/` | CI workflows that run the smoke and index checks. |

Any directory not listed here is undefined. Register a directory in this table
before adding files to it, and delete leftover directories that no longer have a
registered role.

## File Format Rules

- Markdown, JSON, JSONL, and shell files are UTF-8 with LF line endings, no
  byte-order mark, and a final newline. `.gitattributes` enforces the line
  endings; this section is the contract the checks read from.
- Canonical page filenames are lowercase kebab-case and end in `.md`.
- Files under `raw/` are exempt from the final-newline and line-ending rules.
  A capture is preserved byte-for-byte, so a missing final newline in a captured
  body is a documented format gap, not a defect to repair. `.gitattributes`
  marks `raw/**` as `-text` so git never rewrites those bytes.

Known format gaps:

- `raw/public-tourism-api/2026-openapi-briefing.txt` has no final newline, as captured.

## Canonical Frontmatter

Every canonical page must start at byte zero with YAML frontmatter:

```yaml
---
title: Example
created: 2026-08-03
updated: 2026-08-03
type: concept
tags:
  - travel-context
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
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
- `seasonality`
- `tourapi`
- `travel-context`
- `weather`
- `weather-aware-recommendation`

## Source Rules

- Do not edit raw source bodies after capture. Add a new source snapshot instead.
- Raw text, Markdown, JSON, and copied public documents are allowed if registered under `raw/`.
- Canonical pages may synthesize raw sources, but must not cite generated docs, templates, or other canonical pages as `sources`.
- If a canonical claim needs precise attribution, include an inline marker such as `^[raw/public-tourism-api/2026-openapi-briefing.txt]`.

## Normalized Record Rules

- `records/` files are derived data. They may support retrieval and packaging, but they are not raw evidence.
- Every record with a `source` field must point to an existing file under `raw/`.
- Weather records must separate backend facts from explanation rules. They must not invent live weather values.
- Region and place records may contain service-friendly classifications such as `indoorOutdoor`, `weatherSensitivity`, and `travelContext`.
- Project artifact records must link portfolio-relevant artifacts back to source evidence, canonical pages, and service packages when available.

## Batch Collection Rules

- Repo-local batch scripts live under `scripts/` and must be runnable without secrets.
- `scripts/collect-user-input.sh` may only capture sanitized inputs with `consentForWiki: true` and `containsPersonalData: false`.
- `scripts/collect-external-snapshot.sh` may only capture source-backed snapshots with `sourceUrl`, `license`, `collectedAt`, and `payload`.
- Live authenticated API polling, private user history, and operational recommendation logs belong in a consumer service backend, not in this public wiki.
- Batch-generated index artifacts must be checked with `scripts/build-index.sh --check`.

## Retrieval And Package Rules

- `indexes/manifest.json` lists canonical pages, records, and packages available for static retrieval.
- `indexes/chunks.jsonl` is JSON Lines: one valid JSON object per line.
- `indexes/source-map.json` maps raw source records to derived and canonical consumers.
- `packages/<service>/context-bundle.json` lists the canonical and record context a service may load.
- Packages must not include secrets, user travel history, or private location traces.

## Link Rules

- Canonical pages should use Obsidian-style `[[wikilinks]]` to connect related pages.
- Once three or more canonical pages exist, each canonical page should link to at least two other active canonical pages.
- Links to `raw/`, `templates/`, `_archive/`, or missing files do not count as canonical links.

## Index Rules

- `index.md` lists every active canonical page exactly once, under the section
  matching its `type`.
- Entries are sorted alphabetically by page slug within each section.
- The `Active canonical pages:` count must equal the number of canonical
  Markdown files on disk.
- Never list raw records, records, templates, docs, or archived pages as active
  canonical entries.
- Split a section once it exceeds 50 entries.

## Log Rules

`log.md` is append-only. Never rewrite or remove an earlier entry; correct a
mistake by appending a `repair` entry that states the correction.

Entry headings use this exact format:

```text
## YYYY-MM-DD - <action> - <subject>
```

Allowed actions:

| Action | Use |
| --- | --- |
| `ingest` | Captured new evidence under `raw/`. |
| `create` | Added canonical pages or records. |
| `update` | Changed existing canonical pages, records, or contracts. |
| `archive` | Moved a fully superseded canonical page to `_archive/`. |
| `delete` | Removed canonical pages or records. |
| `lint` | Recorded a validation outcome. |
| `repair` | Corrected an earlier log entry or a contract violation. |

Each entry lists every affected repository-relative path. Rotate to
`log-YYYY.md` after 500 entries and leave the completed file unchanged.

## Archive Rules

Archive a canonical page only when it is fully superseded. In one operation:
move it under `_archive/`, remove its `index.md` entry, repair any inbound
`[[wikilinks]]`, and append an `archive` entry to `log.md`. Archived pages are
never `sources` targets and never count toward link minimums.

## Index And Log Synchronization

For every canonical create, update, archive, or delete:

1. Update `index.md`.
2. Append one entry to `log.md`.
3. Run `./harness/scripts/smoke.sh`.
