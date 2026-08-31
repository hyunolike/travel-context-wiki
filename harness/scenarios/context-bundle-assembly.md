# Scenario: Context bundle assembly

## Purpose

Before any explanation can be generated, the files a service package points at must assemble into one deterministic string. Prompt caching depends on that string being byte-identical across requests, so assembly is a contract, not a convenience.

## Given

- `packages/<service>/context-bundle.json` lists `retrievalPolicy`, `canonicalContext`, and `recordContext`.
- Every path it lists exists on disk.
- No listed file carries a line of its own shaped like `----- FILE: <path> -----`.
- No secret, user travel history, or location trace appears in any listed file.

## When

- `scripts/build-bundle.sh <service>` reads the package file and concatenates the listed files in the order the package declares.

## Then

- The script exits non-zero and names the offending path if any listed file is missing.
- The script exits non-zero and names the offending path if any listed file carries a marker-shaped line of its own.
- Running the script twice on an unchanged tree produces byte-identical output.
- The output contains no timestamp, UUID, hostname, or run counter.
- The output carries each file's repository path, so a citation can be checked against the bundle.
- The reported byte total stays small enough to send whole; above roughly 40 KB the no-vector-search decision in `indexes/retrieval-policy.md` should be revisited.

## Verification Notes

- Determinism is the whole point. A timestamp in the bundle silently drops the cache hit rate to zero and costs money without failing any test, which is why `harness/scripts/smoke.sh` compares two consecutive runs rather than trusting review.
- The byte total is measured, not estimated. The decision to skip embeddings rests on it.
- The marker check has to live here, in the generator, and not in whatever parses the bundle back. `----- FILE: <path> -----` is the only thing separating one document from the next, so a source file carrying such a line makes the output genuinely ambiguous — a consumer reading it back gets a document with a fabricated path, and that path then reads as a real member of the bundle's path set. That set is what a citation is checked against, so the fabricated path would let a model cite a document that does not exist and pass validation. Only the generator sees the files before they are concatenated; after concatenation the boundary is unrecoverable. A consumer-side check can catch marker-shaped fragments embedded mid-line, but never a clean marker line, because that line has already been consumed as a boundary.
