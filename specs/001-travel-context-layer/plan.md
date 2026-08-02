# Travel Context Layer Plan

## Technical Context

The MVP is a Markdown/Git repository with a shell smoke harness and Spec Kit configuration. No runtime server, database, weather API client, or embedding index is required.

## Architecture

Raw evidence is copied into domain-specific `raw/` directories. Canonical pages synthesize tourism, weather, congestion, and regional-context evidence in domain directories. `index.md` and `log.md` track active memory and changes. The harness validates repository consistency.

## Implementation Phases

1. Repository scaffold and Spec Kit setup.
2. Raw evidence snapshots for public tourism API and first consumer service.
3. Canonical wiki seed pages for travel context, weather, congestion, and explanation boundaries.
4. Harness smoke script.
5. Git initialization and verification.

## Verification

Run:

```bash
./harness/scripts/smoke.sh
```

Expected:

```text
smoke passed: 12 canonical pages checked
```
