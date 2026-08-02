# Travel Context Wiki

여행지, 관광 공공데이터, 날씨, 혼잡도, 지역 맥락, 연구 자료를 연결하는 범용 LLM wiki 레포지토리입니다.

이 레포는 특정 서비스의 코드를 대체하지 않습니다. 여행 서비스는 각자의 백엔드에서 결정적인 추천을 수행하고, 이 wiki는 그 추천을 설명하고 검증하는 컨텍스트 레이어로 사용합니다. 한적은 이 wiki를 사용하는 첫 번째 소비 서비스일 뿐, 유일한 목적이 아닙니다.

## Concept

**Travel Context Layer**

사용자가 여행 서비스에 목적지, 날짜, 시간대, 이동 반경, 여행 선호를 입력하면 서비스 백엔드는 관광지, 날씨, 혼잡도, 이동 조건을 기반으로 후보와 코스를 계산합니다. 이후 LLM은 이 레포의 canonical wiki를 검색해 다음 설명을 만듭니다.

- 오늘 이 여행지가 왜 적합한가
- 날씨가 코스 선택에 어떤 영향을 주는가
- 혼잡하면 어떤 대안지가 적합한가
- 실내/실외 대안은 어떤 기준으로 갈리는가
- 공공 API와 연구 자료의 근거는 어디에 있는가

## Knowledge Layers

```text
Layer 1: Evidence
  raw/public-tourism-api/     관광 공공 API 설명회, 매뉴얼, 정책 자료
  raw/weather-api/            날씨 API 문서와 검증 자료
  raw/tourism-research/       관광, 혼잡, 날씨 영향 관련 논문/리포트
  raw/service-snapshots/      이 wiki를 소비하는 서비스의 설계/하네스 스냅샷
  raw/experiments/            API 실호출 검증 결과

Layer 2: Canonical Memory
  entities/                   관광/날씨 API, 기관, 데이터셋, 주요 시스템
  concepts/                   날씨 인지 추천, 혼잡 회피, 계절성, 지역 맥락
  comparisons/                API/데이터소스/추천 정책 비교
  queries/                    재사용 가능한 근거 기반 질의응답
  decisions/                  LLM wiki 운영과 서비스 연동 의사결정

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
Travel service backend
  place candidates, weather context, congestion context, route generation
        |
        v
Travel context wiki retrieval
  tourism policy, weather effects, congestion research, data-source constraints
        |
        v
LLM explanation
  source-grounded travel explanation for users and service documentation
```

## MVP Scope

- Preserve the initial tourism OpenAPI briefing extract and first consumer-service snapshots as raw evidence.
- Maintain canonical wiki pages for tourism data, weather-aware recommendation, congestion-aware routing, and LLM explanation boundaries.
- Provide a deterministic smoke script that checks frontmatter, source paths, index entries, log entries, and Spec Kit files.
- Use Spec Kit for future feature work through `$speckit-specify`, `$speckit-plan`, `$speckit-tasks`, and `$speckit-implement`.

## Out Of Scope

- Letting an LLM decide the actual travel course.
- Real-time paper search per user request.
- Storing API keys, public-data service keys, Telegram tokens, or user travel history in Git.
- Replacing each consumer service's deterministic recommendation logic.

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

- `raw/public-tourism-api/2026-openapi-briefing.txt`
- `raw/service-snapshots/hanjeok/design-v3.md`
- `raw/service-snapshots/hanjeok/course-recommendation.md`
- `raw/service-snapshots/hanjeok/attractions.fixture.json`

## Recommended Repository Name

`travel-context-wiki`
