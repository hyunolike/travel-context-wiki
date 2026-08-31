# Operation Log

## 2026-08-03 - create - initial evidence wiki scaffold

- Created repository scaffold for the initial evidence wiki.
- Added OpenAPI briefing extract, first consumer-service design snapshot, harness scenario snapshot, and attraction fixture snapshot under `raw/`.
- Added initial canonical pages for recommendation policy, public API entities, LLM explanation, and architecture decisions.
- Added harness smoke check and Spec Kit scaffolding.

## 2026-08-03 - update - pivot to travel context wiki

- Reframed the repository from a Hanjeok-only evidence wiki into a general travel, tourism, weather, congestion, and regional-context wiki.
- Moved initial Hanjeok files under `raw/service-snapshots/hanjeok/` as first consumer-service snapshots.
- Replaced Hanjeok-specific canonical names with Travel Context Wiki concepts and queries.

## 2026-08-03 - update - add data layer and mermaid workflow

- Added `records/`, `indexes/`, and `packages/` as derived data layers inspired by the 2nd Brain template's evidence-to-canonical workflow.
- Added README Mermaid diagrams for data layers, service integration, operating workflow, and architecture.
- Extended smoke validation to check JSON records, JSONL chunks, manifest paths, package references, and record source paths.

## 2026-08-03 - update - add repo-local batch pipeline

- Added sanitized user-input and external snapshot capture contracts.
- Added repo-local batch scripts for user input capture, external snapshot capture, and deterministic retrieval index generation.
- Added GitHub Actions smoke/index workflow for scheduled and PR validation without secrets.

## 2026-08-03 - update - add project artifact linking model

- Added captured notes from the open source AI automation agent project guide.
- Added canonical project artifact linking rules for PRD, GitHub Issue/PR, RAGAS report, deployment URL, and service packages.
- Added project artifact records so portfolio deliverables can be traced through source evidence, canonical pages, indexes, and packages.

## 2026-08-06 - repair - restore git-tracked canonical directories

- `comparisons/`, `inbox/`, and `research/` were registered in `SCHEMA.md` but had no placeholder, so git did not track them and a fresh clone lacked all three.
- `./harness/scripts/smoke.sh` failed at the canonical `find` with exit 1 on any fresh clone, which also broke the `wiki-batch` workflow.
- Created: `comparisons/.gitkeep`, `inbox/.gitkeep`, `research/.gitkeep`.
- Updated: `harness/scripts/smoke.sh` to guard the three directories with `require_dir`.

## 2026-08-06 - update - align schema contract with the repository tree

- Registered previously undocumented directories in the `SCHEMA.md` role table: `scripts/`, `templates/`, `docs/`, `specs/`, `.agents/`, `.github/`, and on-demand `_archive/`.
- Removed empty pre-pivot directories that had no registered role: `raw/api-spikes/`, `raw/competition/`, `raw/hanjeok-design/`, `raw/harness/`, `raw/openapi-briefing/`.
- Added `SCHEMA.md` sections for file format rules, index rules, log rules, and archive rules. The log heading grammar and its action vocabulary were previously used but never defined.
- Recorded the missing final newline in `raw/public-tourism-api/2026-openapi-briefing.txt` as a known format gap rather than repairing immutable evidence.
- Created: `.gitattributes`, pinning LF and marking `raw/**` as `-text` so captured bytes are never rewritten.
- Updated: `index.md` to sort the Concepts section alphabetically; `.specify/workflows/workflow-registry.json` to end with a newline.
- Updated: `harness/scripts/smoke.sh` with checks for kebab-case page names, index section membership and ordering, index/filesystem slug parity, log heading grammar, and BOM/CRLF/final-newline hygiene outside `raw/`.
- Canonical pages unchanged at 13.

## 2026-08-06 - update - document the knowledge store boundary

- Recorded why the knowledge layer lives in git while automated high-frequency collection does not: commit history growth, push contention on concurrent writers, and the inability to delete personal data once committed.
- Added a README `Knowledge Store Boundary` section comparing this repository against service-side object storage across write owner, write frequency, validation gate, history, deletability, and personal data.
- Added an `Agent Delivery` table for the three ways a running agent can consume this repository, recommending the build-time bundle so runtime has no network dependency or request ceiling.
- Updated: `README.md` only. No canonical page, record, index, or package changed.

## 2026-08-06 - update - allow scheduled public reference data collection

- Added `SCHEMA.md` "Scheduled Collection Rules" as a narrow exception to the live-polling ban: public reference data only, at most daily, secrets confined to the workflow fetch step, no request URL in logs, commit only on payload change, evidence stops at `raw/`, and pull request only.
- Updated: `scripts/collect-external-snapshot.sh` with `--skip-unchanged`, which compares the `payload` object and leaves the stored capture untouched when only envelope metadata such as `collectedAt` moved. Without the flag the previous always-write behaviour is unchanged.
- Updated: `harness/scripts/smoke.sh` to assert both directions of that flag, so a re-timed capture cannot rewrite the file and a real payload change cannot be swallowed.
- Created: `.github/workflows/collect-air-quality-stations.yml`, capturing the air-quality monitoring station list so a region record can cite the station its air-quality claims come from.
- Deliberately not collected: live concentration readings. Those are live data owned by the consumer backend, and rule 1 of the new section excludes them.
- Endpoint path, parameter names, and licence label in that workflow are unverified against data.go.kr and must be confirmed before the secret is configured.
- Canonical pages unchanged at 13.

## 2026-08-12 - update - make the scheduled air-quality collector able to finish

- The collector had run weekly since 2026-08-06 and never collected anything: no `DATA_GO_KR_SERVICE_KEY` secret exists, so every run took the guard branch, emitted a skip notice, and reported success. A green run history meant nothing had happened.
- Updated: `.github/workflows/collect-air-quality-stations.yml` with a `totalCount` guard. The request asks for a single page of 1000 rows and never checked how many rows exist, so a station list that outgrew that page would have been captured truncated and stored as if complete. The run now fails instead of paginating, because crossing that line is rare enough to deserve a human decision about whether the extra pages are still one snapshot.
- Updated: the same workflow to stop calling `scripts/build-index.sh` and to stop staging `indexes/`. That script reads canonical pages, `records/`, and `packages/` only, so a capture under `raw/` cannot move any index artifact until a human writes a record citing it. The rebuild was always a no-op and falsely implied retrieval had been refreshed.
- Updated: the pull request body to state that no checks will appear on it. A pull request opened with `GITHUB_TOKEN` does not trigger other workflows, so `Wiki Batch Checks` stays idle there; the collecting run executes `./harness/scripts/smoke.sh` against the same tree before opening it.
- Outstanding, and required before the collector can succeed: the repository setting "Allow GitHub Actions to create and approve pull requests" is off (`can_approve_pull_request_reviews: false`), which makes the final `gh pr create` step fail. Rule 7 of "Scheduled Collection Rules" cannot be satisfied until it is on.
- Endpoint path, parameter names, and licence label remain unverified against data.go.kr. They are checked with a throwaway script outside this repository, since rule 3 forbids a secret-dependent script under `scripts/`.
- Canonical pages unchanged at 13.

## 2026-08-12 - repair - correct the air-quality licence label

- The previous entry recorded the licence label as unverified. It was verified against dataset 15073877 on data.go.kr and found wrong: the workflow declared `공공누리 제1유형`, but the dataset is `공공누리 제3유형` (출처표시 + 변경금지).
- Updated: `.github/workflows/collect-air-quality-stations.yml`, correcting the `LICENSE` value that is written into every captured envelope, and replacing the "verify before enabling" header with the confirmed contract. No capture had been made under the wrong label, so no stored evidence needs repair.
- Also confirmed on the same page: the endpoint path `MsrstnInfoInqireSvc/getMsrstnList` and the parameter name `returnType`. Other AirKorea services use `_returnType` and answer XML when the name is wrong, so the name is now recorded in the workflow header rather than left to memory.
- Type 3 forbids distributing a modified version of the work. Capturing the response verbatim with attribution is squarely inside the licence; deriving `records/` from it is a judgement call that has not been made yet and is not made here.
- Canonical pages unchanged at 13.

## 2026-08-13 - repair - stop the air-quality capture rewriting itself every run

- The first two real runs of the collector produced captures of identical byte length whose contents differed on 9040 diff lines. The endpoint returns the same 673 stations in a different order on every call. `jq -S` sorts object keys but leaves array order alone, so `--skip-unchanged` compared identical data as changed and opened a pull request that changed nothing. Left alone this would have queued one empty pull request per week and made rule 5 meaningless.
- Verified before fixing: normalising both captures made them byte-identical, item counts matched at 673, and everything outside the items array was already identical. The data had not moved at all.
- Updated: `scripts/collect-external-snapshot.sh` with `--sort-arrays`, which canonicalises object keys and then sorts every array in the payload before both comparing and storing. Sorting happens on the stored file, not only on the comparison, because comparison-only sorting would keep the first capture's arbitrary order forever and render a single added station as a 9000-line diff no reviewer could read.
- The flag is opt-in. Array order carries meaning in rankings, time series, and paginated sequences, so a blanket sort in a shared script would corrupt a future collector. The judgement stays with each collector.
- Updated: `harness/scripts/smoke.sh` with four assertions: a reordered payload must not rewrite under `--sort-arrays`, a real addition must still rewrite under it, and the same reordering must still count as a change without it, so the default behaviour is pinned as well as the new one.
- Updated: `SCHEMA.md` with "Scheduled Collection Rules" rule 6, renumbering the former rules 6 and 7 to 7 and 8. Also clarified in "File Format Rules" that byte-for-byte preservation covers captured bodies and not the JSON envelopes this script builds, which have always been written with sorted keys.
- Updated: `.github/workflows/collect-air-quality-stations.yml` to pass `--sort-arrays`, with the reason recorded at the call site.
- The snapshot already on `main` was stored unsorted, so the next run will propose one pull request that normalises it and then go quiet.
- Canonical pages unchanged at 13.

## 2026-08-19 - update - cut the hanjeok contract to what exists and make the bundle assemblable

- The Hermes Agent design specified a five-fact contract on 2026-08-17 and nothing was changed to match. `packages/hanjeok/context-bundle.json` still declared seven `requiredBackendFacts`, and `harness/fixtures/course-explanation-request.json` still carried `weather` and `timeSlot`. Anything built against the stated contract would have demanded facts nobody produces.
- Updated: `packages/hanjeok/context-bundle.json`, removing `timeSlot` and `weather` from `requiredBackendFacts` and dropping `concepts/weather-aware-travel-recommendation.md` and `records/weather/rules.json` from the context lists. Neither file is deleted — the evidence outlives the absence of a consumer, the same reason `raw/` is preserved.
- Updated: the same file to **add** `concepts/congestion-diagnosis.md` and `decisions/keep-llm-out-of-ranking.md`, which were missing. Three independent things asked for them: `packages/hanjeok/prompt.md` requires explaining the congestion diagnosis and stating that the LLM did not rank; `harness/fixtures/wiki-retrieval-context.json` already listed both under `expectedPages`; and the design document's own response example cites `concepts/congestion-diagnosis.md`, which its own harness check ("every cited path exists in the bundle") would have failed. `packages/generic-travel/` had both all along; only hanjeok was missing them.
- Updated: `packages/hanjeok/prompt.md`, removing the instruction to explain whether weather changes the experience. Asking for an explanation of a fact that is never supplied is an invitation to invent one.
- Updated: `queries/why-this-place-today.md` and `concepts/weather-aware-travel-recommendation.md` for the same contract. The weather page now states plainly that no running service produces these facts and that nothing on it may be asserted until one does. The `packages/generic-travel/` package still lists it, but no service implements that package.
- Added: `scripts/build-bundle.sh`, which assembles a package's context into one deterministic string. The measured bundle is 9 files and 10,309 bytes — roughly 2,700 to 3,400 tokens, comfortably above the 512-token minimum cacheable prefix and far below any size that would justify vector search. `indexes/retrieval-policy.md` already preferred static local retrieval; the measurement now backs it.
- Added: `harness/scenarios/context-bundle-assembly.md` and four `harness/scripts/smoke.sh` assertions. Determinism is checked by comparing two consecutive runs byte for byte, because a timestamp in the bundle would silently drop the cache hit rate to zero, cost money, and fail no test.
- Added: `harness/scripts/explain-spike.sh`, which sends the bundle plus fixture facts to the API and prints the explanation and cache figures. It is under `harness/` and not `scripts/` because "Batch Collection Rules" requires every script under `scripts/` to run without secrets and this one needs `ANTHROPIC_API_KEY`. With no key it prints the request body and exits clean; smoke runs it with the key explicitly unset so a key in the environment can never turn a check into a billed call.
- Raised the spike's `max_tokens` from the design document's 4,096 to 8,192. That limit covers thinking and response text together and thinking is on by default on this model, so 4,096 risks a truncated answer rather than a cheap one.
- Not verified, and load-bearing for the next step: the claim that `timeSlot` was deleted in hanjeok's v4 contract. The snapshot preserved here is `design-v3.md` and it still carries `timeSlot`; the deletion is asserted by the design document and has no evidence under `raw/`. The five hanjeok endpoints the design names are likewise unconfirmed against the running service.
- Not done: the spike has never been executed against the API. No credential is available in this environment, so `effort: low` remains untested and the design document's first open question is still open.
- Canonical pages unchanged at 13.

## 2026-08-19 - repair - correct four canonical pages that contradicted the v4 API contract

- The previous entry recorded two claims as unverified. Both were checked against the consumer service's source, read-only, and both hold: `timeSlot`/`time_slot` appears zero times in the backend, `weather` appears zero times, and all five endpoints the design names exist. What the check also found is that four canonical pages describe a version of the service that no longer runs — and all four are in the hanjeok bundle, so an explanation grounded on them would have been confidently wrong.
- Added: `raw/service-snapshots/hanjeok/api-contract-v4.md`, a byte-identical copy of the service's contract document. `design-v3.md` is untouched — raw is append-only, and keeping both is what makes the contradictions below expressible rather than lost in an overwrite.
- Repaired: `concepts/course-generation-policy.md`. It said each place is assigned to the time slot where its congestion is lowest. In v4 `timeLabel` is departure at 10:00 plus ninety minutes per place plus measured travel time, and has nothing to do with congestion. It also described greedy placement with local swapping; v4 does exhaustive search over at most six permutations and the swap step no longer exists as a concept.
- Repaired: `concepts/travel-context-layer.md`. Its **allowed** list contained "explain why a crowded destination is delayed to a later slot". `CourseRoutePolicy.bestOrder` returns `listOf(originId) + best` — the original destination is always the first visit and is never deferred. The page that defines what the explanation layer may say was authorising a sentence that is false in every course the service produces, and the backend's own `reason` string for that item says the opposite ("첫 방문지로 두었어요").
- Repaired: `concepts/congestion-diagnosis.md`. It listed time slot as a primary input and marked itself contested pending a spike on time granularity. The spike ran on 2026-08-03 and settled it — the public congestion API carries a date and no time field — so the slot axis was deleted from the contract rather than left unimplemented. Also recorded that the grade comes from the percentile and not the raw concentration, an error the consumer service made once and corrected.
- Repaired: `concepts/alternative-scoring.md`. The formula was abstract weights; v4 fixes them at 0.4/0.4/0.2 and states plainly that the values were chosen without data. Added the filter the page was missing: only `RELAXED` and `NORMAL` candidates are ever returned, so an explanation cannot describe an offered alternative as busy, and an empty list means no quiet covered candidate existed rather than that scoring rejected them.
- Updated: `queries/why-this-place-today.md` to name the endpoint each of the five facts comes from, and to forbid the two sentences the repairs above make impossible — moving the destination later, and giving a time-of-day reason for a visit time.
- Replaced: `harness/fixtures/course-explanation-request.json`. The previous version was written from the design document and was wrong in shape and in content: it omitted the `ApiResponse` envelope, used string ids where the contract uses `number`, invented `slot` values, and put the crowded destination last. It now carries all four real responses with the actual rule-based strings the service emits, which also gives the harness its comparison baseline for free.
- The bundle grew from 10,309 to 15,681 bytes on this repair. Still one prompt, still far below the point where retrieval would beat sending it whole.
- Repaired: `harness/scripts/smoke.sh`, which sent `build-index.sh --check` output to `/dev/null`. A stale index therefore failed with exit 1 and no message. It now prints the diff and says what to run.
- Outstanding, and a decision rather than a defect: **`GET /courses/{uuid}` does not return five facts.** It returns the visit date and the items; the destination, the diagnosis, and the alternatives each need their own request. The design document's data flow shows one call. Either it becomes four, or the contract shrinks to what the course response already carries — the course items do carry a per-item grade and a rule-based reason, so a narrower explanation is possible without the extra calls. This is not decided here.
- Canonical pages unchanged at 13.

## 2026-08-20 - update - make the spike runnable against two providers on one fixture

- The provider question kept being argued from opinion because nothing had ever been run. `harness/scripts/explain-spike.sh` now takes `--provider anthropic|openrouter` and builds the request for either from the same bundle and the same fixture, so the comparison can be measured instead of debated.
- The output contract is identical on both paths: `{ explanation, citations }`. Anthropic enforces it with `output_config.format`. OpenRouter's free Nemotron does not support `response_format` — verified on the model's own page, which states JSON output is not enforced — so the same schema is forced through a `tool_choice`-pinned function call. Same guarantee, one more layer of indirection, and a concrete instance of what the design document meant by a shim turning first-class parameters into workarounds.
- No `cache_control` on the OpenRouter path. Prompt caching is a cost lever and the free tier has no cost to lower, so the bundle is reprocessed on every call. What that spends is latency and a rate-limit slot, not money. This also weakens the strongest argument the design gave for calling Anthropic directly, which was that caching is the whole cost story.
- Added four `harness/scripts/smoke.sh` assertions. Two check that the schema is still forced on the OpenRouter path — if `tool_choice` stops pinning the function the model may answer in prose and the contract is gone with no error. The other two compare checksums of the bundle and the facts across both request bodies, because a comparison run on two different prompts measures the prompt rather than the model.
- Recorded for the decision, not decided here: free access is real but shaped differently by vendor. NVIDIA's build.nvidia.com issues a finite credit pool that does not refill; OpenRouter's free tier resets daily at 50 requests, or 1,000 after a one-time credit purchase. For anything that has to keep running, the daily reset is the usable shape and the credit pool is a trial.
- The remaining risk is unchanged and unmeasured: a rate limit is a safe failure and this design already tolerates it, since a 503 costs a feature rather than the service. Confident fabrication is not safe, and it is the failure this repository exists to prevent. `harness/scenarios/travel-context-explanation.md` names six forbidden behaviours; counting them on each provider is what settles this.
- Canonical pages unchanged at 13.

## 2026-09-01 - repair - refuse to build a bundle a consumer cannot parse back

- `scripts/build-bundle.sh` separates documents with `----- FILE: <path> -----` lines and never checked whether a source file carries such a line itself. One that did would make the output genuinely ambiguous: a consumer parsing it back gets a document whose path was fabricated by the source text, and that fabricated path then reads as a real member of the bundle's path set. That set is exactly what a citation is validated against, so the hole runs straight through the guarantee this repository exists to hold — a model could cite a document that does not exist and pass.
- Found while building the first consumer of these bundles. Its loader was given a guard against the same shape, which is where the limit showed: a consumer can catch a marker-shaped fragment embedded mid-line, but never a clean marker line, because that line has already been consumed as a document boundary before any check can look at it. Only the generator sees the files before they are concatenated.
- Updated: `scripts/build-bundle.sh`, rejecting any listed file that carries a marker-shaped line, inside the existing validate-everything-before-emitting loop so a rejected package produces no output at all.
- Updated: `harness/scripts/smoke.sh` with an assertion that builds a throwaway package whose prompt carries such a line and requires the script to refuse it. Verified the other way too: appending a marker line to `packages/hanjeok/prompt.md` made the script exit 1 naming that file, and removing it restored the same 9 files and 15,681 bytes as before.
- Updated: `harness/scenarios/context-bundle-assembly.md`, adding the precondition and the outcome, and recording why the check cannot live in the consumer.
- No canonical page, record, or package changed, so no bundle content moved. Canonical pages unchanged at 13.
