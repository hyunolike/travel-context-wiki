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
