# Local consumer retrieval API follow-up (2026-10-10)

This wiki continues to provide reviewed Git-based documents, normalized records, package lists and source metadata. It does not host the retrieval API or runtime backend facts. The API/Kotlin implementation is approved for a new Draft PR on `pr/retrieval-api-readiness`; its original local branch `local/retrieval-deployment-ready` is preserved at `245d109f676ba4e47470bf54d4140837c8c4c638` in the sibling `hanjeok-agent` worktree; the latest reviewed code commit is `fa0ccce391b85a8a9b354e1af565d5d84fe451e5`, followed by reporting regression fix `76959aa26b20f2a3f87dbaa20883019d31b13832` and documentation commits. [Verification snapshot](retrieval-api-followup-verification.json) contains the consumer evidence copied for this documentation update. It is an operator record, not an independent signed attestation or a claim of deployment.

## Implemented consumer components

- `retrieval-service/retrieval_service/`: immutable Git-verified index, metadata-only bounded ASGI API, lexical/semantic adapters and Neo4j integration. Runtime model downloads, remote model code and query logs are disabled.
- `deployment/retrieval/`: local preparation, pinned Linux package/base, manual registry publication/rollback and local owned-fixture smoke. Publication does not hot-reload or change cloud traffic.
- Kotlin request-scoped selection: always eight policy documents, local verified seed text, citation allowlist and repair, context-specific cache/single-flight and verified FULL recovery. FULL stays the default and retains its exact previous prompt bytes.
- `experiments/retrieval/`: separately executed RAGAS 0.3.9 ID metrics and original fixtures/results, including five semantic VECTOR seed omissions. No response quality/judge inference.

## Reproduction entry points in the consumer checkout

```sh
export PYTHONPATH=retrieval-service:experiments/retrieval
experiments/retrieval/.venv-semantic/bin/python -m unittest discover -s retrieval-service/tests -v
./gradlew --offline --no-daemon test bootJar offlineContextEval
# Run only after a pinned candidate and local API have been prepared:
./gradlew --offline --no-daemon retrievalServiceE2e --args='INDEX_DIR http://127.0.0.1:17880 /tmp/graph-e2e.json HYBRID_GRAPH'
```

For index build/validate/publish/rollback, model/wheel pinning and local graph startup, use `deployment/retrieval/README.md` in that consumer checkout. The implementation is a Draft PR follow-up and is not merged into remote main; use its feature branch for reproduction.

## Actual versus held checks

Actual Python 19/19 and JVM 339/339 (56 suites) pass; original 29 fixtures/58 rows are preserved. Native lexical, pinned native CPU semantic and Linux ARM64 lexical image each passed real API/Neo4j/Kotlin citations over 35 fixtures/105 routes plus one actual-facts EXPLAIN. Real Neo4j Community 5.26.31 has 15 nodes/22 edges; source/hash tampering, synthetic isolation and 2-hop/9-document bounds pass. Actual corrupt graph makes readiness DOWN and retrieval fail, and Kotlin returns exact verified FULL. Own local servers, labelled containers/network and temporary images were removed; unrelated services remain.

Cloud IAM/private network/invoker and production Enterprise reader ACL checks remain held. Full Linux semantic image remains unrun: official `torch 2.14.1+cpu` requires a fresh Linux CPU candidate rather than changing the saved exact `2.14.1` pin. No paid models/judges, corpus upload, new credentials, cloud deployment/traffic switch or separate DB/SMTP rollout. The last historical FULL production check was `ea47917`; prior PR #13/#32 were observed merged outside the follow-up, with no new production-revision inference.

The graph contains only verified document/source and declared seed place/region relations. It is not Microsoft's full community GraphRAG and imports no invented weather/transport or synthetic relation. With just one optional 501-byte seed among 24,703 bytes, source selection has about a 2.03% ceiling; no total token/cost or answer-quality improvement has been established.
