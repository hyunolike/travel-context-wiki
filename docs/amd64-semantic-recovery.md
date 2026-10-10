# Interrupted Linux amd64 verification (2026-10-10)

The consumer's existing linux/amd64 builder `sha256:2069dee76d031e22f5b2b59d39d59ea8104919d6a5bba680b7f004d2e231e03c` built successfully and ran x86_64 Python, offline pip check and real local-model weight loading (100/100). All 43 wheel hashes match the preserved wheelhouse. The executed script's initial architecture assertion and subsequent output establish x86_64 execution; no Python version is printed.

New amd64 index generation/validation, health and final fixtures remain **unconfirmed**. The stopped container has no final `/tmp/amd64-build-proof.json`. It still contains the old Mac index with torch 2.14.1, while Linux wheels use 2.14.1+cpu, so the builder is **not deployable**. ARM64 HYBRID/VECTOR 35-fixture/105-route results remain separate.

Recovery preserved output and source hashes before stopping only `hanjeok-semantic-amd64-builder-task8`. It is exited with code 137 after the requested 20-second stop timeout; this records cleanup, not a successful validation run. The container/image and source files remain preserved. No large build or container restart occurred.

[Mirrored summary](amd64-semantic-recovery.json) records actual stages and source SHA256 hashes. The [consumer record and raw public outputs](https://github.com/hyunolike/hanjeok-agent/blob/codex/linux-semantic-readiness-followup/docs/retrieval-deployment/amd64-semantic-recovery.md) are on the separate follow-up branch for Draft PR review. Original ARM64 JSON snapshots retain their earlier architecture/publication flags.

Production remains ea47917 FULL; operational deployment and the separate Hanjeok backend rollout remain held. This work changed no IAM/Neo4j ACL/credential, provisioned no paid resource and uploaded no external corpus.
