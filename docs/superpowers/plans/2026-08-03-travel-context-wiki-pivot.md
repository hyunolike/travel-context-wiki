# Travel Context Wiki Pivot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pivot the repository into a general Travel Context Wiki with README, raw evidence snapshots, canonical seed pages, harness validation, and Spec Kit SDD scaffolding.

**Architecture:** The repository is a Markdown/Git knowledge base. Raw evidence lives under `raw/`, canonical pages live under domain directories, and `index.md` plus `log.md` track active memory and changes. A shell smoke script validates consistency without external dependencies.

**Tech Stack:** Markdown, Git, Bash, Spec Kit, Obsidian-compatible wikilinks.

## Global Constraints

- Do not modify consumer-service repositories while curating this wiki.
- Do not commit API keys, tokens, user travel history, or private location data.
- The LLM wiki explains backend recommendations but does not decide ranking.
- Run `./harness/scripts/smoke.sh` before considering the scaffold complete.

---

### Task 1: Repository Scaffold

**Files:**
- Create: `README.md`
- Create: `AGENTS.md`
- Create: `SCHEMA.md`
- Create: `index.md`
- Create: `log.md`
- Create: `.gitignore`
- Create: `.editorconfig`

**Interfaces:**
- Produces: repository contract and operating documentation for all later tasks.

- [x] Create base directory structure.
- [x] Initialize Spec Kit with `specify init --here --integration codex --force`.
- [x] Add top-level repository documentation.

### Task 2: Evidence Snapshots

**Files:**
- Create: `raw/public-tourism-api/2026-openapi-briefing.txt`
- Create: `raw/service-snapshots/hanjeok/design-v3.md`
- Create: `raw/service-snapshots/hanjeok/course-recommendation.md`
- Create: `raw/service-snapshots/hanjeok/attractions.fixture.json`

**Interfaces:**
- Produces: raw source paths used by canonical `sources` frontmatter.

- [x] Extract OpenAPI PDF text.
- [x] Copy first consumer-service design and harness snapshots.

### Task 3: Canonical Seed Pages

**Files:**
- Create: `concepts/*.md`
- Create: `entities/*.md`
- Create: `queries/*.md`
- Create: `decisions/*.md`

**Interfaces:**
- Consumes: raw source paths from Task 2.
- Produces: searchable LLM wiki context for future service integration.

- [x] Add source-backed canonical pages.
- [x] Update `index.md`.
- [x] Append `log.md`.

### Task 4: Harness And SDD

**Files:**
- Create: `harness/scenarios/travel-context-explanation.md`
- Create: `harness/fixtures/course-explanation-request.json`
- Create: `harness/fixtures/wiki-retrieval-context.json`
- Create: `harness/scripts/smoke.sh`
- Modify: `.specify/memory/constitution.md`
- Create: `specs/001-travel-context-layer/*`

**Interfaces:**
- Produces: deterministic verification entrypoint.

- [x] Add scenario and fixtures.
- [x] Add smoke validation.
- [x] Add initial Spec Kit feature artifacts.

### Task 5: Verification And Git

**Files:**
- Modify: repository `.git/` metadata through `git init`, `git add`, and `git commit`.

**Interfaces:**
- Consumes: all scaffold files.
- Produces: initial committed local repository.

- [ ] Run `chmod +x harness/scripts/smoke.sh`.
- [ ] Run `./harness/scripts/smoke.sh`.
- [ ] Run `git init`.
- [ ] Run `git add .`.
- [ ] Run `git commit -m "feat: scaffold hanjeok evidence wiki"`.
