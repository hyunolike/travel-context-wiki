# API 계약 — 프론트엔드 인계 문서

> 이 문서는 `frontend/mocks/handlers.ts`의 목 구현으로 확정된 계약이다.
> 백엔드는 이 응답 형태를 그대로 만족해야 프론트엔드가 무수정으로 붙는다.
> 상위 설계는 `docs/design.md`(v4), 도출 과정은
> `docs/superpowers/specs/2026-08-02-frontend-mock-design.md`를 참조한다.
>
> **v4에서 시간대(슬롯) 축이 전부 빠졌다.** `slot` 쿼리 파라미터, `timeSlot`/`timeRange`,
> `slotForecasts`, `waitMinutes`는 계약에서 삭제됐다 — 미구현이 아니라 폐기다. 근거는
> 스파이크 `docs/spikes/2026-08-03-openapi-REPORT.md` B2: 집중률 API 응답에 시간대
> 필드가 아예 없고 날짜(`baseYmd`)만 있다. 무엇이 왜 바뀌었는지는 `docs/design.md`
> 부록 C를 참조한다.

이 문서는 **프론트엔드가 소비하는 계약만** 다룬다. `backend/src/main/kotlin/com/hanjeok/external`의
`TourApiClient`나 공공 TourAPI 원본 응답 형태로의 매핑은 범위 밖이다 (사용자 스코프 결정).

검증 근거: `frontend/mocks/handlers.ts`, `frontend/mocks/db.ts`, `frontend/mocks/course.ts`,
`frontend/mocks/fixtures/*.json`, `frontend/src/entities/*/model/types.ts` (zod 스키마).
스펙 문서(`docs/superpowers/specs/2026-08-02-frontend-mock-design.md` §4)와 다른 부분은
**구현이 확정본**이며, 아래에 발산 지점을 명시했다.

모든 엔드포인트는 `/api/v1` 아래에 있고, 응답은 `ApiResponse<T>` 봉투로 감싸진다:

```ts
{ success: boolean, data: T | null, error: { code: string, message: string } | null }
```

`frontend/src/shared/api/http-client.ts`의 axios 인터셉터가 `success: false`면 `ApiError`를
throw하고, `success: true`면 `data`를 언래핑해 돌려준다. **에러 봉투는 실제 오류에만 쓴다** —
아래 2번 항목이 이 규칙의 핵심 예외 사례다.

---

## 0. 반드시 지킬 것 (요약)

1. **등급은 백분위에서 나온다, 집중률 원값이 아니다.** `docs/design.md` §6.1은 "백분위
   기반으로 설계해 절대값 스케일 변동에 강건하게 만든다"고 명시하고, §8 예시도
   `{ concentration: 87.3, percentile: 92, grade: "VERY_CROWDED" }`로 percentile을 등급의
   입력으로 쓴다. 목 구현(`db.ts`의 `gradeFromConcentration`)은 `percentileOf(concentration)`을
   거쳐서만 `gradeOf(percentile)`을 호출한다 — **집중률을 곧바로 등급 컷(50/75/90)에
   넣으면 안 된다.** 이 실수는 구현 중 실제로 한 번 발생했다가 수정되었다
   (§6.1 주석 참조).
2. **`hasCongestionData: false`는 HTTP 200 + `success: true`다.** 진단 불가는 에러가
   아니라 정상 제품 상태다. `ApiResponse.error`를 쓰지 않는다.
3. **`summary`와 `recommendReason`은 다른 화면용이며 합치면 안 된다.** `summary`는
   장소 자체 소개(코스 만들기 화면 ④), `recommendReason`은 시점 기반 추천 사유(진단
   결과 화면 ②)다. 한 필드로 묶으면 한쪽 화면의 문구가 어색해진다.

---

## 1. 엔드포인트 목록

| 엔드포인트 | 화면 |
|---|---|
| `GET /api/v1/attractions/search?keyword=` | ① 홈 검색 |
| `GET /api/v1/attractions/popular?limit=` | ① 홈 인기 캐러셀 |
| `GET /api/v1/attractions/{id}` | ②④ 관광지 상세 |
| `GET /api/v1/attractions/{id}/congestion?date=` | ②③ 혼잡도 진단 |
| `GET /api/v1/attractions/{id}/alternatives?date=&radius=` | ②④ 대안지 |
| `POST /api/v1/courses` | ④ 코스 생성 |
| `GET /api/v1/courses/{uuid}` | ⑤ 코스 상세 (공유) |

`slot` 쿼리 파라미터는 v4에서 계약 자체에서 삭제됐다(위 안내 참조) — 혼잡도 진단과
대안지 두 엔드포인트 모두 이제 `date`만 시점 파라미터로 받는다.

**프론트엔드가 실제로 보내는 쿼리 파라미터와 목이 실제로 읽는 파라미터가 다르다** —
백엔드는 프론트가 보내는 파라미터를 전부 받아야 하지만(무시하더라도 400을 내면 안 됨),
목은 그중 일부만 필터링에 사용한다:

| 엔드포인트 | 프론트가 보내는 파라미터 | 목이 실제로 쓰는 파라미터 |
|---|---|---|
| `attractions/search` | `keyword`, `ldongRegnCd` | `keyword`만. `ldongRegnCd`는 무시 — 부록 B5 검증 대기(§2 참조) |
| `attractions/{id}/alternatives` | `date`, `radius` | `date`만. 후보별 집중률·등급·점수가 `date`에 따라 달라진다(`concentrationOn`). `radius`는 무시 |
| `attractions/{id}/congestion` | `date` | `date`가 `diagnosis`(집중률·등급·percentile)와 `betterDates` 산출에 실제로 쓰인다. 단 `dailyForecasts`는 예외로 **항상 "오늘"부터 30일**이다 — 조회한 `date`가 아니라 요청 시점 기준으로 고정된다(`dailyForecasts(attractionId)` 구현) |

백엔드 구현 시 `radius`를 실제로 필터링에 반영할지는 실데이터 확인 후 결정할 사항이다.
목은 결정적 재현을 위해 최소한만 구현했다.

**목의 silent default(파라미터 생략 시 대체값)** — 실백엔드는 그대로 따라 하면 안 되는
목 전용 편의다. 실API는 누락된 필수 파라미터를 400으로 거부하는 것이 정상이다:

| 파라미터 | 생략 시 기본값 | 비고 |
|---|---|---|
| `attractions/{id}/congestion`의 `date` | 요청 시점의 오늘(`todayIso()`, UTC 기준 연-월-일) | 고정 문자열이 아니라 호출 시점마다 달라진다 |
| `attractions/{id}/alternatives`의 `date` | 요청 시점의 오늘(`todayIso()`) | 위와 동일한 함수를 쓴다 |
| `attractions/popular`의 `limit` | `10` | |

---

## 2. 코드 체계 — 부록 B5 검증 대기

`ldongRegnCd`(법정동 광역코드), `ldongSignguCd`(법정동 시군구코드),
`lclsSystm1`/`lclsSystm2`/`lclsSystm3`(분류체계 코드 1~3단계)는 폐기 예정인
`areaCode`/`sigunguCode`/`category`를 대체하는 필드다. `docs/design.md` §5.3이
"KorService2 매뉴얼 확인 전 잠정 표기"라고 명시한 값이므로 **이 필드명·구조는 부록 B5
검증 후 바뀔 수 있다.** 프론트는 이 변경 지점을 `entities/attraction/model/types.ts`
한 곳으로 격리해 뒀다 — 백엔드 필드가 바뀌면 이 파일만 갱신하면 된다.

zod 스키마(`attractionSchema`)는 `lclsSystm2`/`lclsSystm3`를 `nullable`로 선언한다. 목
fixture는 실제로는 항상 문자열 값을 채워 두지만, 스키마는 이 필드들이 없을 수 있다고
가정한다 — 백엔드가 항상 값을 채울 수 있다는 보장이 없기 때문이다(§4.1 원본 spec).

---

## 3. 관광지 요약 — 검색·인기 공통

```ts
AttractionSummary {
  id: number
  contentId: string
  name: string
  areaLabel: string          // "경북 경주시" — 표시용. 백엔드가 법정동 코드로부터 조립
  imageUrl: string | null
  hasCongestionData: boolean // 집중률 커버리지 플래그 (docs/design.md §2.1)
}
```

### `GET /attractions/search?keyword=`

→ `AttractionSummary[]`. `keyword`가 빈 문자열이면 빈 배열을 반환한다(목 구현
`searchAttractions`의 `trimmed.length === 0` 분기). 매칭은 `name.includes(keyword)` —
부분 문자열 포함, 대소문자·자모 정규화 없음.

### `GET /attractions/popular?limit=`

→ `PopularAttraction[]` = `AttractionSummary & { grade: CongestionGrade }`.

`grade`는 **특정 날짜 조회가 아니라, 관광지별 기준선 집중률(`congestion.json`
fixture의 `baseConcentration`)로 산출한 대표 등급**이다(`db.ts`의 `popularAttractions`가
`baselineOf` → `gradeFromConcentration`으로 직접 계산). **정렬은 기준선 집중률
오름차순(=한적한 순)이며, 등급 자체로 정렬하지 않는다.** 커버리지 밖
관광지(`hasCongestionData: false`)는 이 목록에서 완전히 제외된다.

---

## 4. 관광지 상세

### `GET /attractions/{id}`

```ts
Attraction {
  id: number
  contentId: string
  name: string
  ldongRegnCd: string
  ldongSignguCd: string
  areaLabel: string
  lclsSystm1: string
  lclsSystm2: string | null
  lclsSystm3: string | null
  latitude: number
  longitude: number
  imageUrl: string | null
  overview: string | null
  hasCongestionData: boolean
}
```

관광지를 찾지 못하면 `404 ATTRACTION_NOT_FOUND`.

---

## 5. 혼잡도 진단 — 판별 유니온

### `GET /attractions/{id}/congestion?date=`

`hasCongestionData`를 판별자로 하는 유니온이다. **두 분기 모두 HTTP 200 + `success:
true`다.** 커버리지가 없는 것은 에러가 아니라 정상 제품 상태이기 때문이다 — 프론트는
`z.discriminatedUnion("hasCongestionData", [...])`로 파싱한다(`congestionResultSchema`).

```ts
// hasCongestionData: true
{
  hasCongestionData: true
  attraction: { id: number, name: string, imageUrl: string | null }
  diagnosis: {
    date: string                  // "2026-08-15" — 조회 기준 날짜. 시간대 축은 없다
    concentration: number          // 0~100 원값
    percentile: number             // 전국 분포 대비 백분위 — grade의 실제 입력
    grade: "RELAXED" | "NORMAL" | "CROWDED" | "VERY_CROWDED"
    message: string
  }
  dailyForecasts: [                // "오늘"부터 30일치(오늘 포함) 일별 예보. 항상 이 길이
    { date: string, concentration: number, grade }
  ]
  betterDates: [                   // date보다 뒤이면서 더 한적한 날 중 집중률이 가장 낮은 순 최대 3개. 없으면 []
    { date: string, concentration: number, grade }
  ]
}

// hasCongestionData: false
{
  hasCongestionData: false
  attraction: { id: number, name: string, imageUrl: string | null }
  message: string                  // "이 장소는 집중률 예측 데이터가 제공되지 않아요"
  nearbyDiagnosable: [              // 커버리지 있는 인근 장소, 거리 오름차순
    { id: number, name: string, imageUrl: string | null, travelMinutes: number }
  ]
}
```

세부 규칙:

- **등급은 percentile의 함수다, concentration이 아니다.** 목 구현: `percentileOf(c) =
  min(99, round(c * 1.05))`, `gradeOf(percentile)`은 `<50 RELAXED / <75 NORMAL / <90
  CROWDED / else VERY_CROWDED`. 실데이터에서는 percentile을 "전국(또는 동일 지역) 분포
  대비 산출"(§6.1)하는 실제 통계 계산으로 대체되지만, **등급 컷은 percentile 위에서
  적용된다는 구조는 유지해야 한다.**
- `dailyForecasts`와 `betterDates`는 둘 다 `date`(zod `dailyForecastSchema`)를 요소로
  갖는 배열이지만 **기준점이 다르다.** `dailyForecasts`는 조회한 `date`와 무관하게
  항상 "오늘부터 30일"이고(`db.ts`의 `dailyForecasts` 구현), `betterDates`는 조회한
  `date` 이후 날짜 중 그 `date`보다 집중률이 낮은 날을 최대 3개 고른 것이다
  (`betterDatesAfter`). 예측 창(오늘~+29일) 밖에서는 데이터 자체가 없다.
- `nearbyDiagnosable`은 **선택된 관광지의 좌표를 기준점**으로 한 결과다. 사용자 단말
  GPS를 쓰지 않는다(§10.4). 백엔드는 위치 권한 관련 파라미터를 요구하면 안 된다.
  목 구현은 `related.json`에서 커버리지 있는 대상만 걸러 거리순 정렬한다
  (`nearbyDiagnosable` in `db.ts`).
- 관광지를 찾지 못하면 `404 ATTRACTION_NOT_FOUND` (이건 진짜 에러이므로 에러 봉투 사용).

### `waitMinutes`는 삭제됐다 — 미구현이 아니라 폐기

v3까지는 `diagnosis.waitMinutes`(등급 기반 식당 대기 추정, `VERY_CROWDED`→50분/
`CROWDED`→25분/그 외 `null`)가 있었다. **이 필드는 계약에서 완전히 빠졌다.** 슬롯별
집중률이 있을 때는 "이 시간대 집중률이 높으니 대기도 길 것"이라는 추정 근거가 있었지만,
집중률 API가 날짜 단위로만 데이터를 주는 지금은 그 근거 자체가 없다(`docs/design.md`
부록 C). 시간대 축 없이 대기 시간 숫자를 계속 보여주면 근거 없이 지어낸 값을 사실처럼
내보내는 셈이라, 있어도 틀린 숫자보다 아예 없는 편이 낫다고 판단해 필드를 삭제했다.
UI는 대기 시간 문장을 렌더링하지 않는다 — `null` 처리로 숨기는 것이 아니라 애초에
그 문장 자체가 없다.

### `slotForecasts`·`timeSlot`·`timeRange`는 삭제됐다

같은 이유(집중률 API에 시간대 필드가 없음, 부록 B2)로 `diagnosis.timeSlot`,
`diagnosis.timeRange`, 응답의 `slotForecasts`(4슬롯 고정 배열), 쿼리 파라미터 `slot`이
전부 계약에서 빠졌다. `docs/design.md` v3까지는 이 4슬롯 구조가 §12 R3 / 부록 B2가
**미검증** 상태에서의 가정이었는데, 1주차 스파이크에서 실API가 일 단위로만 집중률을
제공하는 것으로 **확정**됐다(`docs/spikes/2026-08-03-openapi-REPORT.md`). 대체 필드는
위 `dailyForecasts`/`betterDates`다.

---

## 6. 대안 관광지

### `GET /attractions/{id}/alternatives?date=&radius=`

```ts
Alternative {
  attractionId: number
  name: string
  imageUrl: string | null
  grade: "RELAXED" | "NORMAL"      // CROWDED/VERY_CROWDED는 여기 나타나지 않는다
  concentration: number
  distanceKm: number
  relationScore: number             // 부록 B4/R2: API 미제공 시 이진 가중치로 대체 가능
  score: number                     // 아래 스코어링 결과. 내림차순 정렬
  summary: string                   // 장소 자체 소개 — 코스 만들기 화면(④)용
  recommendReason: string           // 시점 기반 추천 사유 — 진단 결과 화면(②)용
  travelMinutes: number             // 원 목적지에서 자동차 기준. UI 표기 "차로 8분"
  rating: number | null             // TourAPI 미제공 시 null → UI에서 별점 숨김
}
```

규칙:

- **`RELAXED`/`NORMAL` 등급만 반환한다.** `docs/design.md` §6.2 3단계 "각 후보의 동일
  날짜 집중률 조인 → '여유/보통' 등급만 통과"를 목 구현이 `.filter((item) => item.grade
  === "RELAXED" || item.grade === "NORMAL")`로 그대로 구현했다. 커버리지 밖 후보도
  `relatedWithCongestionData`에서 이미 제외된다.
- **`score` 내림차순 정렬.**
- **스코어링 가중치 `0.4 / 0.4 / 0.2`는 임시값이다, 실데이터로 조정 대상.**
  ```
  score = 0.4 · relationScore + 0.4 · (1 - concentration/100) + 0.2 · (1 - min(distanceKm, 15)/15)
  ```
  `docs/design.md` §6.2의 `w1·연관도 + w2·(1-집중률정규화) + w3·(1-거리정규화)` 공식을
  가중치 0.4/0.4/0.2로 구체화한 것이며, 근거 데이터 없이 정한 값이다. §6.2는 연관도가
  API에서 제공되지 않으면 "이진 가중치로 대체" 가능하다고도 명시한다. 거리 정규화는
  15km 상한으로 클램프한다(`Math.min(distanceKm, 15) / 15`) — `maxDistanceKm` 기본값과
  일치.
- **`summary` vs `recommendReason`은 서로 다른 필드이며 절대 하나로 합치지 않는다.**
  `summary`는 fixture의 장소 소개 문구를 그대로 쓰고, `recommendReason`은 fixture의
  장소별 문구(`recommendReason` 필드)를 우선 쓰되 없으면 등급 기반 문구
  (`RELAXED`→"지금 가면 조용히 산책하기 좋아요.", `NORMAL`→"붐비지 않는 편이라
  둘러보기 무난해요.")로 폴백한다. 등급만으로 문구를 생성하면 같은 등급의 대안지들이
  전부 동일 문장을 갖게 되어 "장소마다 다른 사유"라는 제품 의도와 어긋난다 — 이 이유로
  fixture에 장소별 `recommendReason`이 추가됐다(스펙 대비 발산 지점, §8 참조).
- `rating`은 `null` 허용 — TourAPI가 평점을 주지 않을 경우 UI가 별점 표시를 생략한다.

---

## 7. 코스

### `POST /courses`

```ts
Request {
  attractionId: number       // 원 목적지
  alternativeIds: number[]   // 1~3개. 0개 또는 4개 이상은 400
  targetDate: string         // "2026-08-15"
}
```

검증 실패 시 `400` (아래 순서로 검사하며, 먼저 걸리는 조건이 응답된다). 1~5번은
`INVALID_REQUEST`, 6번만 별도 코드다:
1. `attractionId`가 존재하지 않는 관광지면 "존재하지 않는 관광지입니다."
2. `alternativeIds`가 빈 배열이면 "대안 관광지를 1개 이상 선택해 주세요."
3. `alternativeIds.length > 3`이면 "대안 관광지는 최대 3개까지 선택할 수 있어요."
4. `alternativeIds`에 중복된 id가 있으면 "대안 관광지가 중복되었습니다." **`attractionId`
   자신이 `alternativeIds`에 섞여 있는 것도 이 조건에 포함된다** — 원 목적지를 자기
   대안으로 넣으면 같은 장소를 두 번 방문하는 코스가 되므로, 중복 판정은
   `alternativeIds` 내부뿐 아니라 `attractionId`까지 함께 본다.
5. `alternativeIds` 중 존재하지 않는 관광지가 하나라도 있으면 "존재하지 않는 대안
   관광지가 포함되어 있습니다."
6. `targetDate`가 `attractionId`(원 목적지)의 예측 가능 날짜 범위 밖이면
   `400 FORECAST_DATE_OUT_OF_RANGE`("예측 가능한 날짜 범위를 벗어났습니다."). 범위 판정은
   `GET /attractions/{id}/congestion`(§5)이 창 밖 날짜를 거부할 때 쓰는 것과 같은
   기준(그 관광지에 예보가 존재하는 날짜의 최솟값~최댓값)이다. 원 목적지에 예측
   커버리지가 아예 없으면(예보 자체가 없음) 이 검증은 통과시킨다 — 그 경우는 에러가
   아니라 원 목적지 무데이터로 감소율이 0%가 되는 정상 케이스다.

목 구현(`frontend/mocks/handlers.ts`)은 **1~6번을 전부** 통과해야 `buildCourse`를
호출한다 — 회귀 이력: 이전에는 `findAttraction(id)!`로 강제 단언해, 존재하지 않는
`attractionId`(예: 손으로 수정한 `/course/new?attractionId=abc` 접근)가 핸들러 내부에서
예외를 던져 MSW가 처리되지 않은 `500`을 그대로 반환했다. **6번(targetDate 범위 검증)은
이제 목에도 구현되어 있다** — `isWithinForecastWindow`(`mocks/db.ts`, 오늘~+29일 예보
창 여부)로 창 밖 `targetDate`를 거부한다. 이전 초안에서는 "목이 6번을 아직 구현하지
않았다"고 적었으나 더 이상 사실이 아니다. 코드값도 실백엔드와 같은
`FORECAST_DATE_OUT_OF_RANGE`다(`ErrorCode.FORECAST_DATE_OUT_OF_RANGE`, `CourseService`가
`CongestionController`의 진단 API와 같은 판정을 재사용한다) — 나머지 1~5번의
`INVALID_REQUEST`와 코드값이 다르다.

### `GET /courses/{uuid}` (응답은 POST와 동일 스키마)

```ts
Course {
  uuid: string
  targetDate: string
  title: string                          // 규칙 기반 문장. 예: "한적한 경주 나들이"
  congestionReductionRate: number        // 원 목적지 단독 방문 대비 낮아진 혼잡도 비율(%)
  summary: string                        // "가장 붐비는 '황리단길'을 다른 장소들과 묶어…"
  items: CourseItem[]
  recommendedDate: {                     // targetDate보다 5%p 이상 한적한 날짜 제안. 없으면 null
    date: string
    congestionReductionRate: number
  } | null
}

CourseItem {
  attractionId: number
  name: string
  visitOrder: number
  timeLabel: string                      // "오전 10:00" — 타임라인 표시용. 근거는 아래 참조
  grade: CongestionGrade                 // 타임라인 등급 배지
  reason: string                         // §6.3 배치 사유. 규칙 기반 문장(LLM 제외, §11)
  latitude: number
  longitude: number
  imageUrls: string[]                    // 0~2장. 목은 방문 1번째 장소에만 1장을 채운다
  travelMinutesFromPrev: number | null   // 직전 방문지로부터의 이동 분. 첫 항목은 항상 null,
                                          // 이후는 항상 양수. 키는 항상 오므로 optional이 아니라 nullable
}
```

**`timeLabel`의 근거가 바뀌었다.** v3까지는 "그 시간대 슬롯 중 집중률이 가장 낮은
시간"을 뜻했다. **지금은 집중률과 무관하다** — `10:00 출발 + 장소당 체류 90분 + 구간
실측 이동시간을 누적`한 결과다(`mocks/course.ts`의 `formatTimeLabel`/`START_MINUTES`/
`STAY_MINUTES`, 백엔드는 `CourseRoutePolicy.timeLabels`로 동일 규칙). 옛 의미로 읽으면
"오전 10:00"이 왜 항상 첫 방문지에 붙는지, 왜 두 번째 방문지의 시각이 이동시간에 따라
달라지는지를 오해하게 된다.

배치 로직은 §6.3(v4 개정)을 구현한다. 설계(`docs/design.md` §6.3)와 실백엔드
(`CourseRoutePolicy.bestOrder`)는 원 목적지를 시작점으로 고정하고 나머지 방문지(최대
3개)의 순열을 전부 탐색(최대 3! = 6가지)해 총 이동시간이 최소인 순서를 고르는
**완전탐색**이라 항상 최적해를 낸다. 목(`mocks/course.ts`의 `buildCourse` →
`bestOrder`)도 같은 완전탐색을 구현한다 — 장소가 최대 4곳뿐이라 이 규모에서 근사를
쓸 이유가 없다. "4. LLM 문장 생성"은
**여전히 구현되어 있지 않다** —
`title`/`summary`/`reason`은 전부 한국어 조사 처리를 포함한 규칙 기반 템플릿 문자열이다
(발산 지점, §8 참조). "이동 동선 보정(순서 스왑)" 단계는 v4에서 완전탐색 자체로
대체돼 개념이 없어졌다 — 상세는 `docs/design.md` §6.3 참조.

`uuid`를 찾지 못하면 `404 COURSE_NOT_FOUND`.

**영속성 주의**: 목 구현은 생성된 코스를 `Map<string, Course>`(`courseStore`, 프로세스
메모리)에만 저장한다 — 새로고침해도 같은 MSW 워커 세션 안에서는 유지되지만 서버 재시작
시 사라진다. 실백엔드는 `docs/design.md` §5.2 스키마에 따라 DB에 영속화해야 한다(공유
링크가 장기간 유효해야 하므로).

---

## 8. 스펙 대비 발산 지점 정리

구현 중 `docs/superpowers/specs/2026-08-02-frontend-mock-design.md` §4의 원안과
달라진 부분. **아래는 전부 구현이 확정본이다.**

| 항목 | 원안(§4) | 구현 확정 | 이유 |
|---|---|---|---|
| 대안지 `summary`/`recommendReason` | 등급 기반 템플릿 문구만 | fixture에 장소별 `recommendReason` 필드 추가, 없을 때만 등급 폴백 | 같은 등급 대안지들이 동일 문장을 갖는 문제 수정 (커밋 `6532842`) |
| fixture 이미지 | 원격 URL(TourAPI 실제 이미지 가정) | 로컬 `/images/attractions/*.svg` placeholder | 실API 이미지 접근 전 결정적 재현을 위한 임시 자산 |
| 관광지 수(경주) | 미지정 | 7개 (경주 첨성대 포함) | 대안지 스코어링 테스트 커버리지 확장 |
| `courseItem.imageUrls` | 명시 없음 | 첫 방문 장소만 1장, 나머지는 0장 | 동일 placeholder 이미지가 나란히 중복 표시되는 문제 수정 |
| `alternatives` 요청 파라미터 `date`/`radius` | 필터에 사용 가정 | 목은 `date`만 사용(후보별 집중률·등급·점수 산출), `radius`는 무시 | v4에서 `slot`이 계약에서 삭제되며 `date`가 그 자리를 흡수했다. `radius`는 여전히 최소 구현 — 실데이터 확인 전 결정 보류 |
| `search` 요청 파라미터 `ldongRegnCd` | 필터에 사용 가정 | 목은 `keyword`만 사용 | 위와 동일 |

---

## 9. 전환 방법

프론트는 `NEXT_PUBLIC_API_MOCK=off` + `NEXT_PUBLIC_API_BASE_URL`을 실제 백엔드 주소로
설정하는 것만으로 이 문서의 7개 엔드포인트에 무수정으로 연결된다. 애플리케이션 코드는
`ApiResponse` 봉투와 zod 스키마 형태가 유지되는 한 변경할 필요가 없다.
