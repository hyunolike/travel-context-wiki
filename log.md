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

## 2026-08-17 - create - draw the collection coverage on the README

- Added: `scripts/build-collection-stats.sh` and `scripts/collection-stats.jq`, which read `raw/external-snapshots/` and render `docs/collection-stats.svg` — periods stored, daily rows, 기초지자체 covered in the latest period, and the air-quality station count. The README previously stated what the wiki intends to collect and nothing about what it holds.
- The renderer is a pure function of the metrics. Its hand-drawn wobble comes from a Lehmer generator seeded by a hash of those metrics, not from a random source, and the footer carries the newest `collectedAt` rather than the current date. Both follow from the refresh policy: the workflow runs daily and commits only when the picture changes, so any non-determinism would produce one meaningless commit per day.
- 기초지자체 coverage is counted in the newest period only. Unioning every period would report which regions have ever appeared, which is a more flattering number and a different claim.
- Added: `.github/workflows/collection-stats.yml`, which redraws daily, on a push to `main` under `raw/external-snapshots/`, and on demand. It fails if any path other than the artifact is dirty after generation, and pushes to `main` rather than opening a pull request.
- Added: `SCHEMA.md` "Generated Artifact Rules", which is what makes that push legal. Rule 8 of "Scheduled Collection Rules" exists because a capture brings in something no human has seen; this artifact brings in nothing of its own, so a pull request would ask for a judgement that does not exist. The new rules keep the exception narrow: one fixed path, no API, no secret, not citable as a source, and pure.
- `--check` is deliberately not wired into `harness/scripts/smoke.sh`. `wiki-batch.yml` runs smoke on every push and the stats workflow runs it before pushing, so asserting there would turn the interval between a merged capture and the next redraw into a contract failure, and would deadlock the workflow against its own output. The `push` trigger closes that interval instead.
- The first committed version renders the empty state, because no visitor period has been captured yet. That is the accurate picture.
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

## 2026-09-13 - ingest - first regional visitor periods, minus the month the source had not finished

- Merged the first real capture of the visitor series: `raw/external-snapshots/tourism-visitors/2026-06.json` and `2026-07.json`, 49,137 daily rows across 270 기초지자체, stored unaggregated as the source returned them. The pull request had been open since 2026-09-07.
- Dropped `2026-08.json` from that pull request before merging. The source had published 08-01 through 08-09 — nine days of thirty-one — and rule 9 makes a stored period immutable, so merging it would have frozen August at 29% and then refused the complete month for as long as the file existed. The two rules that each make sense alone combine into a permanent hole in the evidence layer.
- Measured, and it contradicts the design: the daily series does not lag four days. On 2026-09-07 the newest published day was 2026-08-09, a lag of about twenty-nine. `.github/workflows/collect-regional-visitors.yml` said four in the comment that justifies its cron date; the comment now records what was observed. The schedule itself is kept — requesting three months means a month too fresh for one run is complete by the next.

## 2026-09-13 - update - refuse to store a period the source has not finished publishing

- Added rule 10 to "Scheduled Collection Rules" in `SCHEMA.md`. A period-partitioned envelope declares `coverage.dayField`, and `scripts/collect-period-snapshot.sh` admits the period only when the distinct days in its payload cover the calendar month.
- The count is taken from the payload, not from a number the collector declares, so a collector cannot assert coverage it does not have. Expected days are computed from the period rather than asked of `date`, whose `-d` spelling differs between the GNU date in CI and the BSD date on a developer's machine.
- A short period is skipped and reported, not failed. The newest month is partially published on every scheduled run; painting the workflow red for that would train the reader to ignore it. A period carrying days its month does not have fails, because that is the source or the query being wrong.
- Added `harness/fixtures/period-snapshot.complete.json` and `period-snapshot.incomplete.json`, the second shaped like the August that caused this. Seven assertions in `harness/scripts/smoke.sh` pin the rule, including February in a common year and in the 2028 leap year, and the break-it check: the same nine-day payload with `coverage` deleted is stored, which shows it is the rule doing the refusing.
- Verified against the real captures rather than only the fixtures: the 24,120-row June file is stored, and the nine-day August file is refused, both through the envelope the workflow itself builds.
- Existing behaviour is unchanged for a source that declares no coverage, which is why `period-snapshot.valid.json` and its assertions needed no edit.
- Canonical pages unchanged at 14.

## 2026-09-13 - update - say when a capture is waiting

- Added `.github/workflows/stale-capture-check.yml`, failing daily while a `collect/*` pull request has been open more than three days. The first visitor capture sat for six days: a collector opens its pull request with `GITHUB_TOKEN`, which by design triggers no other workflow, so the pull request carries no checks — and a pull request with no checks is also what an abandoned one looks like. Nothing was wrong, and nothing said so.
- It is a separate workflow rather than a step in `collection-stats.yml`, which already runs daily. That workflow may push to `main` without review only because it redraws committed evidence and adds no claim of its own; a failure condition about pull request state is a claim of its own, and it would also block the redraw whenever a capture was waiting.
- Evidence captured but not merged is evidence this repository does not have. `docs/collection-stats.svg` counts committed files, so an unmerged capture reads there as a month that was never collected — which is precisely what it showed for the six days.

## 2026-09-14 - update - stop requiring the sentence the prompt forbids

- `harness/scenarios/travel-context-explanation.md` required, under **Then**, that "the explanation states that the backend selected the course". `packages/hanjeok/prompt.md` forbids exactly that: the traveller is reading about their day, not about a backend. An implementation satisfying the scenario failed the prompt and the other way round, and the scenario is the contract.
- Repaired: the scenario. The clause is gone, and the narrow one beside it — "does not claim that the LLM re-ranked attractions" — is now the rule it should always have been, because forbidding only that claim still permitted naming the backend, which a live run did, by a mangled transliteration of the backend's own name.
- Repaired: `packages/generic-travel/prompt.md`, whose first required behaviour instructed the same sentence. It has no consumer, so nothing had failed yet; the contradiction was waiting rather than absent.
- Repaired: `queries/why-this-place-today.md`. "avoid claiming that the LLM selected or ordered anything" sat in the **should** list — a prohibition among things to do, inside a document that ships in the bundle. `1c12819` diagnosed this shape: reading such a line reads as an instruction to make the denial, and two of three live explanations ended in a spiral of them. The item moved to **must not**, where it belongs.
- Recorded: `NO_SYSTEM_NAME` in `packages/explanation-rules.json`, with all four documents as its homes. The two that contradicted it are pinned by `mustNotContain`, so the contradiction cannot come back quietly.
- Canonical pages unchanged at 14.

## 2026-09-14 - delete - retire the retrieval-context fixture

- Deleted `harness/fixtures/wiki-retrieval-context.json`. No script read it, so it could not drift *into* anything — but its `forbiddenBehavior` array listed three rules where `packages/explanation-rules.json` now lists eight, and it is the first thing a reader greps for. A stale count nothing enforces is worse than no count.
- `harness/README.md` no longer names it. `docs/superpowers/plans/2026-08-03-travel-context-wiki-pivot.md` still does, and stays as written: it records what was planned on that day.
- The registry is now the only place that answers how many forbidden behaviours there are. The counts in the plans and in `decisions/choose-explanation-model.md` record what was measured when they were written and are left alone.

## 2026-09-21 - create - explain the two scheduled captures no page cited

- Added `entities/regional-visitor-api.md` and `entities/air-quality-station-api.md`. Both collectors had been landing evidence for weeks, and until now no canonical page cited `raw/external-snapshots/tourism-visitors/` or `raw/external-snapshots/air-quality-airkorea-station-list.json`, so no retrieval, bundle, or explanation could reach them.
- Found while writing them: district codes changed on 2026-07-01. The 5 Gwangju (`29xxx`) and 22 South Jeolla (`46xxx`) codes became 27 codes under `12`, and Incheon's 중구, 동구, and 서구 were reorganised into 제물포구, 영종구, 서해구, and 검단구, with `28260` 서구 lingering for five days of July. July passed the completeness rule anyway, because that rule counts days across the month, not per district. Both facts are recorded on the visitor page.
- Also recorded: `signguNm` is not unique, `touNum` is a fractional estimate, `dmX` in the station list is latitude, station addresses are not normalised, and the station list's no-modification license has not been checked against derived records, which is why that page is contested.
- Updated `concepts/congestion-diagnosis.md` to say the district series cannot stand in for a per-attraction grade, and `concepts/weather-aware-travel-recommendation.md` to say air-quality readings are not collected here.
- Added `harness/scenarios/captured-evidence-reachability.md`, a smoke check that fails while any captured `sourceKind` has no citing page, and rule 11 of "Scheduled Collection Rules" in `SCHEMA.md`. The check failed on `air-quality` before these pages existed.
- Updated `index.md`, `harness/scripts/smoke.sh`, `harness/README.md`, and the files under `indexes/`.
- Canonical pages 14 → 16.

## 2026-09-22 - ingest - the KMA short-term forecast guide

- Added `raw/weather-api/kma-vilage-fcst-guide-260623.docx` and `raw/weather-api/kma-vilage-fcst-guide-260623.txt`, the provider's guide from the `.zip` attached to dataset 15084084 on data.go.kr, downloaded 2026-09-22 (zip SHA-256 `07f53cd9…8842e`). The `.docx` is the original; the `.txt` is a `textutil` conversion kept so pages can cite something readable. It is the first file ever stored under `raw/weather-api/`.

## 2026-09-22 - create - ground the weather pages in a weather source

- Added `entities/kma-short-term-forecast-api.md`: operations, the eight daily base times, the 2024-11-28 extension that turns `PCP`, `SNO`, and `WSD` into qualitative codes on the far days, the `SKY` and `PTY` code tables, `PCP` as a string, and result codes.
- Repaired: `concepts/weather-aware-travel-recommendation.md` cited `raw/service-snapshots/hanjeok/design-v3.md` as its only source, and that file has no weather content. The citation is replaced by the guide and recorded under `contradictions`. The page stays `low` and contested, because the guide supports the forecast fields, not the explanation policy.
- Updated `records/weather/rules.json`: each rule now names its `source`, the forecast fields it reads, and `unsourcedFacts`. `outdoorSuitability` and `heatRisk` are unsourced. The guide gives temperatures, not heat risk, and no file here sets a threshold.
- Added `harness/scenarios/weather-rules-evidence.md` and a smoke check that fails while a weather rule cites nothing under `raw/weather-api/`. It failed on `weather:rain:outdoor-limited` before this change.
- Added `.github/workflows/capture-weather-forecast-sample.yml`, manual only, to capture one `getVilageFcst` response for 종로구 (grid 60, 127) as a response sample. A forecast is live data, so it has no schedule. It cannot run until this lands on `main`.
- Not repaired, noted: `records/places/gyeongbokgung.json` and `records/regions/seoul-jongno.json` carry weather sensitivity notes whose `source` is the same weather-free `design-v3.md`.
- Updated `index.md`, `harness/scripts/smoke.sh`, `harness/README.md`, and the files under `indexes/`.
- Canonical pages 16 → 17.

## 2026-09-22 - update - drop the weather forecast sample capture

- Deleted `.github/workflows/capture-weather-forecast-sample.yml`. Its one run, on 2026-09-21, got HTTP 403 from the data.go.kr gateway, most likely because the service key is not approved for dataset 15084084. The owner chose not to apply for it, so a workflow that cannot succeed is removed rather than left to look usable.
- Updated `entities/kma-short-term-forecast-api.md` to stop naming the workflow and to say plainly that no response has been captured: the page rests on the provider's guide alone. Its `confidence` stays `medium`, and `records/weather/rules.json` keeps citing the guide.

## 2026-09-22 - update - review the pages untouched since 2026-08-03

- Reviewed every canonical page last changed on 2026-08-03 against the evidence that arrived after it, chiefly `raw/service-snapshots/hanjeok/api-contract-v4.md`.
- `entities/congestion-forecast-api.md`: the time-slot question is closed. The response is daily, and v4 deleted the slot fields. `contentId` compatibility and the unit of 10,731 (spike B3) remain open.
- `entities/related-attraction-api.md`: the relatedness score is still unverified, but v4 specifies a binary fallback, so the scoring formula does not wait on it.
- `entities/tourapi-korservice2.md`: records the provisional `ldong*` and `lclsSystm*` field names from v4 (pending spike B5), and a new open question: whether TourAPI's legal-dong codes moved with the 2026-07-01 district change seen in the visitor series.
- `concepts/raw-derived-data-separation.md`: adds how the principle applies to this repository's own collectors, including that the air-quality list's no-modification license makes separation a license question.
- `decisions/separate-context-wiki-from-services.md`: records that the first consumer reached the wiki through a package bundle, with no change to the Hanjeok repository.
- Reviewed and left unchanged: `decisions/keep-llm-out-of-ranking.md` and `concepts/project-artifact-linking.md`. Both still match their sources.
- `index.md` is unchanged, because no page was added, removed, or retitled. Updated the files under `indexes/`.
