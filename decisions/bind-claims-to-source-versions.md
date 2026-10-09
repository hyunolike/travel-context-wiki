---
title: Bind Claims To Source Versions
created: 2026-10-09
updated: 2026-10-09
type: decision
tags:
  - evidence-wiki
  - data-lineage
sources:
  - raw/service-snapshots/hanjeok/design-v3.md
  - raw/public-tourism-api/2026-openapi-briefing.txt
confidence: medium
contested: false
contradictions: []
---

# Bind Claims To Source Versions

## Decision

출처 경로만으로는 문서 변경을 확인할 수 없다. `indexes/provenance.json`에
claim selector와 문서 hash, raw source hash, source의 Git revision을 연결한다.
이 파일은 출처 연결 계약이며 원문이 주장을 의미적으로 뒷받침한다는 승인이 아니다.
초기 이관은 `unverified`다. 변경은 `needs-review`로 전환하고 인간 검토 없이
`reviewed`로 승격하지 않는다. 원문을 덮어쓰지 않고 새 snapshot을 추가한다.

## Consequences

전체 정적 bundle과 Git/PR 검토를 유지한다. 번들 sidecar는 주장 상태와 정확한
source 버전을 보존하며 본문 hash에 연결한다. low/contested 자료는 삭제하지 않고
한정된 정책 맥락으로 포함한다. backend facts를 덮어쓰는 검증된 사실로 쓰지 않는다.
원문 없는 기존 모델 선택 기록 한 건은 명시적 미검증 예외로 남긴다.
새 empirical claim은 raw 증거 없이는 계약에 들어갈 수 없다.

이 설계는 로컬 구현 대상이다. 이전 실험의 출력이나 승인을 새로 만들지 않는다.
Hanjeok에 날씨 데이터를 공급하거나 도구를 추가하지 않는다.

## Related Pages

- [[raw-derived-data-separation]]
- [[choose-explanation-model]]
