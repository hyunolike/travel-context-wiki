# AGENTS.md

이 레포는 한적 서비스의 LLM wiki와 증거 기반 설명 레이어를 관리한다.

## Project

Hanjeok Evidence Wiki는 한적 본 서비스와 분리된 Markdown/Git 기반 지식 레포지토리다. 한적 본 서비스는 추천을 결정하고, 이 레포는 추천 정책, OpenAPI 제약, API 검증 결과, 공모전 대응 근거를 보존한다.

## Operating Principles

- `raw/`는 증거 보존 계층이다. 원천 스냅샷은 수정하지 않고 새 스냅샷으로 갱신한다.
- canonical 문서는 `entities/`, `concepts/`, `comparisons/`, `queries/`, `decisions/`에만 둔다.
- canonical 문서를 만들거나 수정할 때는 `index.md`와 `log.md`를 같은 변경으로 갱신한다.
- 추천 결과 자체는 LLM이 결정하지 않는다. LLM wiki는 설명, 검증, 문서화에만 사용한다.
- 사용자 여행 입력, 위치정보, API 키, 서비스 키, 토큰은 Git에 저장하지 않는다.
- 한적 본 레포의 파일은 복사된 raw 스냅샷으로만 참조한다. 원본 레포를 이 레포 작업 중 수정하지 않는다.

## Hanjeok Domain Boundaries

- 공공데이터: TourAPI KorService2, 관광지 집중률 방문자 추이 예측, 관광지별 연관 관광지 정보.
- 정책: 원천/파생 분리, 로컬서버 저장 신청, 운영계정 전환, `MobileApp=hanjeok`, 위치기반서비스 MVP 제외.
- 추천: 혼잡도 진단, 대안지 스코어링, 코스 시간대 배치, 커버리지 밖 폴백.

## Harness First

새 기능은 먼저 `harness/scenarios/`에 Given/When/Then을 추가하고, 필요한 입력을 `harness/fixtures/`에 둔다. 이후 canonical 문서 또는 scripts를 수정한다.

## Spec Kit

큰 변경은 다음 순서로 진행한다.

```text
$speckit-specify -> $speckit-plan -> $speckit-tasks -> $speckit-implement
```

## Common Commands

```bash
./harness/scripts/smoke.sh
```

