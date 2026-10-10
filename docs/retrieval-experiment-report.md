# Consumer local retrieval experiment status

The following baseline results are preserved from the first local phase. The 2026-10-10 extensions below record actual semantic inference and completed isolated Neo4j integration. The intermediate approval-blocked phase remains labelled as historical.

The consuming hanjeok-agent implements a separate experiments/retrieval module over the existing pinned body and sidecar. Production remains FULL and uses the packaged complete manual. Neither wiki canonical/raw/records nor production consumer source/resources were changed for this experiment.

The implementation is local and unpushed. Agent experiments/retrieval/README.md has exact commands; experiments/retrieval/results/{results.json,dataset.jsonl,graph-snapshot.json,citation-validation.json,validation.json} preserve results and execution provenance. This document is a status report, not a new canonical travel claim.

## Boundaries

Eight mandatory policy documents always remain; the single optional document is the 경복궁 fixture-derived seed. Body/sidecar/document/claim hashes and five source identities at their declared Git revisions are verified before retrieval. This checks byte integrity, not the truth or review status of claims. The unsourced prompt remains policy and is excluded from separate search evidence.

VECTOR uses actual sparse character TF-IDF/cosine. It is lexical retrieval, not semantic embedding. HYBRID_GRAPH uses the actual in-process graph over verified Document/Source relationships and the seed's explicit Document/Place/Region relationships: 15 nodes, 22 edges, maximum 2 hops/9 documents. Seed relations retain their fixture origin. No transport/weather relationships or synthetic edges are promoted. This is direct relationship retrieval, not Microsoft's complete community detection/summarization GraphRAG.

The Neo4j 5.26.0 driver adapter uses a fixed parameterized read query with namespace, verified node/edge whitelist, timeout and source/document hash checks. Request/response contracts are mock-tested. No real Neo4j server/container, graph loader or live Cypher parsing was executed. READ_ACCESS is a routing choice, not an ACL.

FULL and fallback system bytes equal the existing full bundle. In retrieval arms, optional content is labelled untrusted evidence in user input; required policy stays in system input. Assistant history answers are ignored. A deterministic guard abstains on unsupported facts and rule overrides; this does not establish actual model adherence.

## Results

Actual RAGAS 0.3.9 IDBasedContextPrecision/Recall APIs scored 210 samples (candidate evidence and final context) across 105 arm executions: preserved 29 fixtures plus 6 graph-boundary cases. Responses are scripted; no LLM generation or judging ran. The oracle is each fixture's declared requiredEvidencePaths.

On the 24 retrieval-attempt cases per arm:

| Arm | Candidate precision (defined) | Candidate recall (defined) | Final-context recall |
| --- | --- | --- | --- |
| FULL | 0.166667 (24/24) | 1.000000 (24/24) | 35/35 |
| VECTOR | 0.431373 (17/24) | 0.395833 (24/24) | 35/35 |
| HYBRID_GRAPH | 0.227941 (17/24) | 0.708333 (24/24) | 35/35 |

Six conservative FULL fallbacks and five abstentions per arm are separate strata (four unsupported topics and one rule override). Empty-set metrics are undefined/null; precision excludes seven empty retrieval rows in the vector/hybrid arms. Precision denominators differ and must be read with the values. Hybrid expansion adds recall and unrelated source-neighbour documents, reducing precision. No answer correctness, semantic entailment or general retrieval superiority is inferred.

Policy retention, final fixture coverage and determinism are 105/105. Maximum original selected-context reduction is still 501/24,703 = 2.028% (about 2.03%). System, evidence-wrapper and assembled input bytes are separate; optional user evidence carries overhead. Tokens, cost, latency and model quality remain unmeasured. Nine documents with one optional seed cannot demonstrate general savings.

Executed validation: Python 29 tests; existing server 325 tests, 0 failures/errors/skips; original 29 x 2 scripted comparison; bootJar; actual production CitationValidator matching 105 exported rows, 210 empty/unknown and 29 omitted-seed probe rejections; wiki provenance 8 tests, smoke 18 canonical pages and index check. Packaged body/sidecar bytes are unchanged and new experiment entry points are absent from the bootJar.

Not executed: real Neo4j integration, semantic embedding inference, faithfulness/relevancy judge, paid APIs, external corpus upload, remote push/PR/merge or new deployment. Existing agent ea47917 rollout remains the previously deployed version; the separate Hanjeok DB/SMTP rollout remains held. New README diagrams remain IMAGE SLOT, not installed images. Opt-in local semantic and caller-supplied real RAGAS judge adapters are prepared but unexecuted; their scores remain null.


## 2026-10-10 local semantic extension and intermediate approval status

A separate .venv-semantic executes sentence-transformers 6.1.0 / transformers 5.19.0 / torch 2.14.1, while the baseline .venv/108-package freeze stays intact. The Apache-2.0 multilingual distiluse model revision is 826fee3d516ebb14987355af373f5b69101c7006, 512 dimensions. Thirteen existing cached artifacts are SHA-256-verified; no model download, custom model code or external inference request occurs. Only safetensors and built-in modules are accepted. CPU deterministic one-thread inference uses 41 token windows, at most 128 tokens including specials, 14-token overlap and adjusted boundaries, then normalized mean document pooling.

Actual RAGAS ID metrics on the same 24 supported attempts:

| Semantic arm | Candidate precision (defined) | Candidate recall (defined) | Complete final fixture coverage |
| --- | --- | --- | --- |
| FULL | 0.166667 (24) | 1.000000 (24) | 35/35 |
| VECTOR | 0.250000 (24) | 0.645833 (24) | 30/35 |
| HYBRID_GRAPH, in-process | 0.172619 (24) | 1.000000 (24) | 35/35 |

Five VECTOR rows miss the optional seed, including explicit-seed and poisoned-history fixtures; failures are retained without changing candidates from oracle IDs. Policies/determinism pass 105/105. Citation-valid scripted rows are FULL 34/35, VECTOR 27/35, HYBRID 32/35, including intentional invalid-citation fixtures. The actual Kotlin CitationValidator agrees on all 105 rows and rejects 210 empty/unknown and 25 omitted-seed probes. Contract agreement is not 105 valid answers. Python tests now pass 34/34 in both environments. Second-process results/dataset/graph bytes and the document matrix hash are identical. New result files are agent experiments/retrieval/results/semantic-in-process; model manifest, version freeze, commands and extension-validation.json are in that separate lab. Existing historical results remain untouched.

A dedicated cached Community image started Neo4j 5.26.31 using only loopback Bolt publication and an internal network, with anonymous experiment volumes, 2 GiB memory/2 CPUs and no existing service-container changes. Image digest: neo4j@sha256:5eb12ad77fa46ab73e23df9ea1f43f5c0f2a79523435577648e046be042b9b93. No pull occurred. The driver's actual managed-transaction API was checked: fixed tx.run uses a string query and unit_of_work(timeout=2), not a Query object.

Automatic approval review rejected fixture insertion/result saving because it judged the initial deferred-integration instruction as not clearly revoked by the later resume approval. Explicit confirmation is pending. Therefore no live Cypher parsing, traversal or tamper-rejection integration result exists. A localhost-only, foreign-database-rejecting loader and live-check helper are prepared, including comparison of 15 starts, max 2-hop/9-document limits, isolated synthetic negative edge and restored temporary hash/revision tampering. The Docker start helper is syntax-checked and unexecuted; its ownership-checked stop branch removed the experiment container/anonymous volumes/internal network. The live checks have not run.

Production still uses FULL; existing ea47917 rollout, DB/SMTP hold and IMAGE SLOTs remain as recorded. No answer generation, paid API, LLM faithfulness/relevancy judge, external corpus upload, remote push/PR/merge or new deployment occurred. No semantic/ID score is labelled LLM judging or answer correctness.


## Completed actual Neo4j integration

Follow-up authorization cleared the earlier approval conflict. The already-cached Community image and actual Python driver now execute localhost integration: Neo4j 5.26.31 / driver 5.26.0; 15 nodes/22 curated edges; all 15 singleton starts match the in-process graph. The two-hop region query returns the seed and excludes longer source-neighbour paths. A synthetic negative edge in a separate namespace is excluded. Actual SHA-256/source-signature tampering is rejected and restored. Mock foreign-database refusal is distinguished from these actual checks. The fixed read query still has max 2 hops/9 documents and managed transaction timeout 2 seconds.

The initial internal-network container had requested but no actual published ports; internal cypher-shell succeeded while the host driver was refused. The corrected helper uses a dedicated bridge with masquerading disabled, only 127.0.0.1:17687 published, HTTP/usage reporting off, 2 GiB/2 CPUs and owned anonymous volumes. It touches no existing bench-neo4j or operational DB. Start and ownership-checked cleanup were executed; the experiment container/volumes/network are removed. No image pull or new model download occurred.

Actual Neo4j TF-IDF and semantic comparisons each produce 105 rows/210 native RAGAS samples. Selections, samples and ID scores equal their preserved in-process counterparts, including the five semantic VECTOR seed omissions. Supported-attempt metrics remain TF-IDF VECTOR precision/recall 0.431373/0.395833 (17/24 defined precision), TF-IDF HYBRID 0.227941/0.708333 (17/24), semantic VECTOR 0.250000/0.645833 (24/24) and semantic HYBRID 0.172619/1.000000 (24/24). Complete final coverage is 35/35 in both lexical arms, 30/35 semantic VECTOR and 35/35 semantic HYBRID; policies/determinism pass all 210 primary Neo4j rows.

Each mode was rerun independently with byte-identical results.json/dataset.jsonl/graph-snapshot.json and unchanged semantic matrix hash. Real Kotlin citation contracts match 105 rows per mode with 210 empty/unknown rejections and 29/25 omitted-seed rejections. Invalid scripted citations remain failures. Current agent artifacts are experiments/retrieval/results/neo4j-{tfidf,semantic}, neo4j-integration.json and neo4j-validation.json. Exact commands are in the lab README; original baseline and semantic-in-process result files stay intact.

The earlier blocked-status files document an intermediate phase, not a current blocker. Production FULL, ea47917 rollout, DB/SMTP hold, approximately 2.03% byte ceiling and IMAGE SLOTs are unchanged. No LLM judge/generation, paid API, external corpus upload, credentials configuration, remote push/PR/merge or new deployment occurred. This is direct bounded provenance/entity retrieval, not Microsoft's complete community GraphRAG pipeline.
