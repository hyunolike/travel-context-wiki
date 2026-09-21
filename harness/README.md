# Harness

This harness fixes the expected behavior of Travel Context Wiki before automation is added.

## Assets

- `scenarios/travel-context-explanation.md`: user-facing service scenario.
- `scenarios/captured-evidence-reachability.md`: every captured `sourceKind` must be cited by a canonical page.
- `fixtures/course-explanation-request.json`: sample backend output and user preferences.
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
