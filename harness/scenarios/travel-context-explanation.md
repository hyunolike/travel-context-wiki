# Scenario: Travel context explanation

## Purpose

When a travel service generates a place or route recommendation, the service explains the result using deterministic backend facts and Travel Context Wiki.

## Given

- The user selects `경복궁`.
- The visit date is `2026-08-15`.
- The backend diagnoses the original destination as `VERY_CROWDED` at the 92nd percentile.
- The backend returns at least two alternative attractions, all graded `RELAXED` or `NORMAL`.
- The backend returns the course items in visit order, with the original destination first.
- Travel Context Wiki contains canonical pages for congestion diagnosis, alternative scoring, course generation, and LLM ranking boundaries.
- The explanation layer receives exactly the five facts named in `packages/hanjeok/context-bundle.json`; `timeSlot` and `weather` are not among them.

## When

- The explanation layer receives the backend responses in `harness/fixtures/course-explanation-request.json`.
- The retrieval layer loads the context bundle listed in `packages/hanjeok/context-bundle.json`.
- The LLM generates the user-facing explanation.

## Then

- The explanation states that the backend selected the course.
- The explanation mentions congestion, distance or relatedness, and visit ordering.
- The explanation does not claim that the LLM re-ranked attractions.
- The explanation does not say the crowded destination was moved to a later position. It is the first visit, and the backend's own `reason` string says so.
- The explanation does not give a time-of-day reason for any `timeLabel`.
- The explanation does not claim a weather condition, because no weather fact was supplied.
- The explanation can cite or trace back to at least one raw source snapshot.
- Every path the explanation cites exists in the assembled bundle.

## Verification Notes

- This scenario does not require live public API calls.
- The fixture must be deterministic.
- The first implementation should use static local wiki retrieval before adding embeddings or vector search.
- `weather` was removed from the contract because no consumer service produces it, not because weather is out of scope. `records/weather/rules.json` and `concepts/weather-aware-travel-recommendation.md` stay as evidence without a consumer.
- The fixture's `dailyForecasts` is truncated to three entries. The real response always returns thirty, counted from the request date rather than the queried date. Nothing in the explanation reads that field, so the truncation costs no coverage.
- The rule-based strings in the fixture are the actual template output — `CourseTextPolicy`, `CongestionMessagePolicy`, and `AlternativeTextPolicy` produce them without a model. They are the baseline any generated explanation should be compared against, which is the point of this scenario.
- **The five facts do not come from one call.** `GET /courses/{uuid}` supplies the visit date and the items and nothing else; the destination, the diagnosis, and the alternatives each need their own request. Any design that assumes a single fetch is under-specified.
