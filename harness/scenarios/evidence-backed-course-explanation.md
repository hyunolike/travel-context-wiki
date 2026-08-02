# Scenario: Evidence-backed course explanation

## Purpose

When Hanjeok generates a congestion-avoidance course, the service explains the result using deterministic backend facts and the Evidence Wiki.

## Given

- The user selects `경복궁`.
- The visit date is `2026-08-15`.
- The desired time slot is `AFTERNOON`.
- The backend diagnoses the original destination as `VERY_CROWDED`.
- The backend returns at least two alternative attractions.
- The Evidence Wiki contains canonical pages for congestion diagnosis, alternative scoring, course generation, and LLM ranking boundaries.

## When

- The explanation layer receives the backend course result.
- The retrieval layer searches the Evidence Wiki for related canonical pages.
- The LLM generates the user-facing explanation.

## Then

- The explanation states that the backend selected the course.
- The explanation mentions congestion, distance or relatedness, and time-slot ordering.
- The explanation does not claim that the LLM re-ranked attractions.
- The explanation can cite or trace back to at least one raw source snapshot.

## Verification Notes

- This scenario does not require live public API calls.
- The fixture must be deterministic.
- The first implementation should use static local wiki retrieval before adding embeddings or vector search.

