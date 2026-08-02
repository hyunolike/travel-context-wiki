# Evidence-backed Course Explanation Plan

## Technical Context

The MVP is a Markdown/Git repository with a shell smoke harness and Spec Kit configuration. No runtime server, database, or embedding index is required.

## Architecture

Raw evidence is copied into `raw/`. Canonical pages synthesize this evidence in domain directories. `index.md` and `log.md` track active memory and changes. The harness validates repository consistency.

## Implementation Phases

1. Repository scaffold and Spec Kit setup.
2. Raw evidence snapshots.
3. Canonical wiki seed pages.
4. Harness smoke script.
5. Git initialization and verification.

## Verification

Run:

```bash
./harness/scripts/smoke.sh
```

Expected:

```text
smoke passed: 11 canonical pages checked
```

