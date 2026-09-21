# Captured evidence reachability

예약 수집기가 `raw/external-snapshots/`에 쌓는 증거는 canonical 문서가 인용해야
위키에 들어온다. 인용하는 문서가 없으면 데이터는 커밋돼 있어도 검색, 번들, 설명
어디에서도 닿지 않는다. 대기질 측정소 목록과 지역 방문자 수가 수집 파이프라인이
정상인 채로 몇 주 동안 이 상태였다.

## Scenario: 수집된 종류마다 인용하는 문서가 있다

- **Given** `raw/external-snapshots/` 아래에 `sourceKind`를 가진 스냅샷이 있고
- **When** `./harness/scripts/smoke.sh`를 실행하면
- **Then** 각 `sourceKind`마다 그 종류의 파일을 `sources`에 올린 canonical 문서가
  하나 이상 있어야 통과한다
- **And** 인용이 없는 종류가 있으면 그 `sourceKind`를 이름으로 대며 실패한다

  검사 단위는 파일이 아니라 종류다. 기간별 수집기는 매달 새 파일을 만들고, 새 달이
  들어올 때마다 문서를 고치게 하면 수집 PR이 매번 막힌다. 새 달은 기존 entity 문서가
  설명하는 같은 데이터셋의 연장이다.

## Scenario: 새 종류의 첫 수집은 entity 문서와 함께 머지된다

- **Given** 새 수집기가 처음 연 PR이 아직 아무도 인용하지 않은 `sourceKind`를 담고
- **When** 그 PR에서 스모크를 실행하면
- **Then** 실패한다
- **And** 리뷰어가 같은 PR에 entity 문서를 추가해야 머지할 수 있다

  수집 워크플로는 사람이 설계해서 추가한다. 그 데이터가 무엇이고 어디까지 믿을 수
  있는지 적는 일도 첫 수집을 받아들이는 시점에 끝내야 한다. 미루면 이번처럼
  아무도 적지 않는다.
