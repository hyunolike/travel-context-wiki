# Harness

This harness fixes the expected behavior of Hanjeok Evidence Wiki before automation is added.

## Assets

- `scenarios/evidence-backed-course-explanation.md`: user-facing service scenario.
- `fixtures/course-explanation-request.json`: sample backend output and user preferences.
- `fixtures/wiki-retrieval-context.json`: expected wiki pages to retrieve.
- `scripts/smoke.sh`: deterministic repository health check.

## Run

```bash
./harness/scripts/smoke.sh
```

The smoke check verifies:

- required repository files exist
- raw source snapshots exist
- canonical pages have basic frontmatter
- canonical `sources` point to existing raw files
- `index.md` count matches the filesystem
- `log.md` has an initial operation entry
- Spec Kit files exist

