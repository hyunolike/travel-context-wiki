# Consumer local retrieval experiment status

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
