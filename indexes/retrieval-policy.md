# Retrieval Policy

Travel Context Wiki starts with static local retrieval.

## Order

1. Use backend facts as the highest-priority context.
2. Retrieve service package files under `packages/<service>/`.
3. Retrieve canonical pages listed in `indexes/manifest.json`.
4. Use normalized `records/` only as derived context, never as raw evidence.
5. Cite `raw/` source paths when explaining public-data or research-backed claims.

## Boundary

The retrieval layer may select context. It must not select travel destinations, modify route order, invent weather, or override backend facts.

