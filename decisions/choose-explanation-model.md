---
title: Choose Explanation Model By Readability, Not By Rule Violations
created: 2026-09-03
updated: 2026-09-03
type: decision
tags:
  - llm-rag
  - evaluation
  - cost
sources:
  - packages/hanjeok/prompt.md
  - concepts/congestion-diagnosis.md
confidence: medium
contested: false
contradictions: []
---

# Choose Explanation Model By Readability, Not By Rule Violations

## Decision

설명 모델은 **금지 행동 위반율이 아니라 한국어 가독성으로 고른다.** 쇼케이스 배포에는 `gpt-4o`를 쓴다.

## Reason

Hermes Agent 하네스가 세는 금지 행동 7종은 모델을 가르지 못한다. 같은 프롬프트, 같은 픽스처, 각 5회 실행에서 **`gpt-4o-mini`와 `gpt-4o`가 모두 7종 전부 0%**였다. 위반율만 보면 두 모델은 구분되지 않고, 싼 쪽을 고르는 것이 당연해 보인다.

가르는 것은 규칙이 못 보는 축이었다. 같은 판정자(`gpt-4o`)로 잰 문장 가독성 지적:

| 모델 | 규칙 위반 7종 | 가독성 지적 | 실행당 |
| --- | --- | --- | --- |
| `gpt-4o-mini` | 0% (5/5 실행) | 6건 (판정 5/5) | 1.2 |
| `gpt-4o` | 0% (5/5 실행) | 2건 (판정 4/5) | 0.5 |

`gpt-4o-mini`가 실제로 낸 문장들이다. 어느 것도 일곱 규칙에 걸리지 않는다.

- `"b도 혼잡도가 '보통(62.0)%와 '여유(41.5)%로"` — 알파벳이 섞여 들어갔다
- `"congestion 진단 결과 백분위수 92에 해당하여"` — 영어 필드 이름을 그대로 옮겼다
- `"매우 붐비는 날으로"` — 조사가 어긋났다
- `"이들 대체지는"` — 없는 단어다

설명이 이 서비스의 **유일한 산출물**이다. 코스와 등급은 한적이 만들고, Hermes가 더하는 것은 문장뿐이다. 그 문장이 한국어로 읽히지 않으면 이 서비스가 하는 일이 없다. 위반율 0%는 "거짓말은 안 했다"는 뜻이지 "읽을 만하다"는 뜻이 아니다.

## Consequences

- **비용이 오른다.** `gpt-4o`는 `gpt-4o-mini`보다 비싸다. 프롬프트 캐시가 18KB 접두사를 잡아 주므로 증가분은 주로 출력 토큰이지만, 싼 쪽을 버리는 선택인 것은 분명하다.
- **작은 모델을 쓰려면 프롬프트가 아니라 다른 것을 바꿔야 한다.** 문체 지시를 세 번 조인 뒤에도 `gpt-4o-mini`의 가독성 결함은 줄지 않았다. 영어 토큰 누출은 닫혔지만 비문은 남았다. 프롬프트로 닫히지 않는 종류의 결함이다.
- **이 표는 픽스처 하나, 실행 5회짜리다.** 코스 종류가 늘면 다시 재야 한다.

## What This Decision Does Not Rest On

- **Anthropic은 재지 않았다.** 키가 없어 실행하지 못했다. `hermes-agent` 스펙 §6.1의 "Anthropic 직접" 결정은 **여전히 측정 근거가 없다** — 이 문서는 그 결정을 지지하지도 반박하지도 않는다.
- **판정자가 `gpt-4o`다.** 한쪽 실행에서는 같은 모델이 자기 출력을 검사했다. 편향은 `gpt-4o`에게 **유리한** 방향이므로 위 격차는 실제보다 크게 나왔을 수 있다. 격차의 방향은 사람이 문장을 읽어 확인했다(위 인용문이 그것이다).
- **판정자도 틀린다.** `gpt-4o-mini` 쪽 6건 중 하나는 이유란에 "읽기에는 문제가 없습니다"라고 스스로 적었다. 지적은 판결이 아니라 사람이 읽을 후보다.

## Related Pages

- [[keep-llm-out-of-ranking]] — LLM이 순위를 정하지 않는다는 결정. 이 문서는 그 LLM이 *어느 모델*이어야 하는가를 다룬다.
- [[why-this-place-today]] — 설명이 답해야 할 질의.
- [[congestion-diagnosis]] — 등급 어휘의 출처.
