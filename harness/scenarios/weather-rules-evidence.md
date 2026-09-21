# Weather rules evidence

`records/weather/rules.json`은 스스로 "raw 날씨 API 기록이나 관광 연구로 뒷받침되기
전에는 근거로 쓰지 않는다"고 적어 두었다. 그런데 그 조건을 확인하는 곳이 없었고,
`raw/weather-api/`는 비어 있었다. 날씨 concept 문서가 인용한 유일한 원천에는 날씨
이야기가 한 줄도 없었다.

## Scenario: 규칙마다 날씨 원천을 인용한다

- **Given** `records/weather/rules.json`에 규칙이 있고
- **When** `./harness/scripts/smoke.sh`를 실행하면
- **Then** 모든 규칙의 `source`가 `raw/weather-api/` 아래에 실제로 있는 파일을
  가리켜야 통과한다
- **And** 그렇지 않은 규칙이 있으면 그 규칙의 `id`를 대며 실패한다

## Scenario: 원천이 정의하지 않은 판단은 판단으로 남는다

- **Given** 규칙이 요구하는 백엔드 사실 가운데 원천에 정의가 없는 것이 있고
- **When** 규칙을 읽으면
- **Then** 그 사실은 `unsourcedFacts`에 따로 적혀 있다

  단기예보는 기온(`TMP`, `TMX`)을 주지만 폭염 여부는 주지 않는다. `heatRisk`를
  기온에서 어떻게 끌어낼지는 이 레포의 어떤 원천에도 없다. 그 공백을 규칙 안에
  이름으로 남겨야, 누군가 기준값을 지어내서 채우는 일을 막을 수 있다.
