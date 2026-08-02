# Hanjeok Evidence Wiki

한적 서비스의 공공데이터 활용 근거, 추천 정책, API 검증 기록을 보존하는 LLM wiki 레포지토리입니다.

이 레포는 한적 본 서비스의 코드를 대체하지 않습니다. 한적 백엔드는 집중률, 연관 관광지, TourAPI, PostGIS 기반으로 결정적인 추천을 수행하고, 이 wiki는 그 추천을 설명하고 검증하는 증거 레이어로 사용합니다.

## Concept

**Evidence-backed Course Explanation**

사용자가 한적 서비스에 목적지, 날짜, 시간대, 이동 반경, 여행 선호를 입력하면 한적 백엔드는 규칙 기반으로 혼잡도 진단과 우회 코스를 생성합니다. 이후 LLM은 이 레포의 canonical wiki를 검색해 다음 설명을 만듭니다.

- 왜 이 장소가 혼잡하다고 판단됐는가
- 왜 이 대안지가 추천됐는가
- 왜 이 시간대 순서가 선택됐는가
- 공공 API 제약 때문에 어떤 폴백이 적용됐는가
- 원천 데이터와 파생 데이터가 어떻게 분리되는가

## Knowledge Layers

```text
Layer 1: Evidence
  raw/openapi-briefing/       2026 OpenAPI 설명회 자료 추출본
  raw/hanjeok-design/         한적 설계문서 스냅샷
  raw/harness/                한적 하네스 시나리오와 fixture 스냅샷
  raw/api-spikes/             공공 API 실호출 검증 결과
  raw/competition/            공모전 제출 및 운영계정 관련 자료

Layer 2: Canonical Memory
  entities/                   공공 API, 도구, 기관, 주요 시스템
  concepts/                   혼잡도 진단, 대안지 스코어링, 코스 정책
  comparisons/                설계 대안 비교
  queries/                    재사용 가능한 근거 기반 질의응답
  decisions/                  한적 서비스의 ADR 형태 의사결정

Layer 3: Operation Metadata
  SCHEMA.md                   wiki 계약
  index.md                    active canonical catalog
  log.md                      append-only operation history
```

## Service Integration Model

```text
User input
  destination, date, time slot, radius, preferences
        |
        v
Hanjeok backend
  congestion diagnosis, alternative scoring, route generation
        |
        v
Evidence wiki retrieval
  policy, API constraints, research notes, decision records
        |
        v
LLM explanation
  source-grounded course explanation for users and competition docs
```

## MVP Scope

- Preserve the OpenAPI briefing extract, Hanjeok design snapshot, and harness scenario as raw evidence.
- Maintain canonical wiki pages for the recommendation policy and OpenAPI compliance decisions.
- Provide a deterministic smoke script that checks frontmatter, source paths, index entries, log entries, and Spec Kit files.
- Use Spec Kit for future feature work through `$speckit-specify`, `$speckit-plan`, `$speckit-tasks`, and `$speckit-implement`.

## Out Of Scope

- Letting an LLM decide the actual travel course.
- Real-time paper search per user request.
- Storing API keys, public-data service keys, Telegram tokens, or user travel history in Git.
- Replacing the Hanjeok backend's deterministic recommendation logic.

## Quick Start

```bash
./harness/scripts/smoke.sh
```

Open this folder as an Obsidian vault or in VS Code. Before adding or changing canonical pages, read `SCHEMA.md`, `index.md`, and the latest entries in `log.md`.

## SDD Workflow

This repository includes Spec Kit scaffolding.

```text
$speckit-constitution
$speckit-specify
$speckit-plan
$speckit-tasks
$speckit-implement
```

New runtime integration features must start with a scenario under `harness/scenarios/`, a fixture under `harness/fixtures/`, and a Spec Kit feature branch.

## Initial Source Snapshots

- `raw/openapi-briefing/2026-openapi-briefing.txt`
- `raw/hanjeok-design/design-v3.md`
- `raw/harness/course-recommendation.md`
- `raw/harness/attractions.fixture.json`

## Recommended Repository Name

`hanjeok-evidence-wiki`

