# Collection Stats Image Design

**Status:** approved design; not yet implemented
**Date:** 2026-08-17
**Artifact:** `docs/collection-stats.svg`, embedded in `README.md`

## Goal

Show, on the repository's front page, how much external evidence the scheduled
collectors have actually gathered — as a hand-drawn (Excalidraw-style) chart
that refreshes itself.

Today a reader of `README.md` learns what the wiki intends to collect and
nothing about what it holds. `raw/external-snapshots/` currently contains one
air-quality station list; the regional visitor collector landed on
`design/regional-visitor-collector` and has not captured a period yet. The
image makes that state visible instead of implied, and keeps doing so as
periods accumulate.

## Scope

Covered: the metric extraction, the SVG renderer, the README embed, the
workflow that refreshes it, the SCHEMA rule that permits it, and the harness
scenario that pins its behaviour.

Not covered: statistics about the wiki's own size (canonical page counts,
`records/` counts, `indexes/` chunk counts). Those describe authoring effort,
not collection, and would dilute a chart whose subject is external evidence.

## What is counted

Two collectors exist, and each contributes its own metrics.

### Regional visitors — `raw/external-snapshots/tourism-visitors/YYYY-MM.json`

| Metric | Source |
|---|---|
| Periods stored | number of `YYYY-MM.json` files |
| Period range | earliest and latest file name |
| Daily rows | sum of `.payload.response.body.totalCount` |
| 기초지자체 covered | distinct `.payload.response.body.items.item[].signguCode` in the latest period |
| Rows per period | `.payload.response.body.totalCount` per file — the chart's bars |
| Last captured | maximum `.collectedAt` |

`signguCode` is read only from the latest period. Reading every period would
mean parsing every ~3 MB file on each run to answer a question that only the
newest period can answer honestly — whether current coverage is national.

### Air-quality stations — `raw/external-snapshots/air-quality-airkorea-station-list.json`

| Metric | Source |
|---|---|
| Stations | `.payload.response.body.totalCount` |
| Last captured | `.collectedAt` |

### Layout

```text
┌─ paper ───────────────────────────────────────────────┐
│  수집 현황                                             │
│                                                        │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐       │
│  │   3    │  │ 66,412 │  │  229   │  │  673   │       │
│  │ 개월   │  │ 일별 행│  │지자체  │  │측정소  │       │
│  └────────┘  └────────┘  └────────┘  └────────┘       │
│                                                        │
│  월별 수집량                                           │
│  2026-05 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 22,134                    │
│  2026-06 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 22,140                    │
│  2026-07 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 22,138                    │
│                                                        │
│  마지막 수집 2026-08-08                                │
└────────────────────────────────────────────────────────┘
```

Every box and bar is drawn with the hand-drawn stroke described below. The
footer date is the maximum `collectedAt` across both collectors, so it answers
"how stale is anything here" with one number rather than two.

## Determinism is a hard requirement, not a preference

The refresh policy is *run daily, commit only when the picture changes* —
the same principle as SCHEMA rule 5, which compares payloads so that envelope
metadata does not manufacture a commit.

That forces two constraints the renderer must obey.

1. **The sketch jitter cannot be random.** A real random number generator makes
   the same data produce a different SVG on every run, so every day commits.
   The wobble is instead produced by a seeded Lehmer generator
   (`seed = seed * 16807 % 2147483647`), seeded from a djb2 hash of the
   extracted metrics serialised with `jq -S -c`. Same numbers, same drawing;
   a bar whose value moved is the only thing whose shape moves.
   MINSTD's constants are chosen so every intermediate product stays below
   2^53 and is therefore exact in the IEEE doubles `jq` uses — a larger
   multiplier would lose precision and could diverge between platforms.
2. **The image must not stamp the current date.** A "생성 2026-08-17" footer
   changes daily and would defeat the whole policy. The footer carries the
   maximum `collectedAt` found in the evidence — the date that is actually
   about the data.

## Hand-drawn rendering

Excalidraw's look reduces to four devices, all reproducible in plain SVG:

1. **Every straight edge is drawn twice.** Two cubic Béziers along the same
   endpoints, each with independently jittered control points, so the two
   passes diverge and re-converge the way a pen does.
2. **Control points are offset proportionally to edge length**, capped at
   roughly 2px, matching roughjs' `maxRandomnessOffset` at `roughness: 1`.
   Endpoints are jittered less than midpoints so corners still read as corners.
3. **Fills are hachure**, not solid: parallel 45° strokes about 8px apart,
   clipped to the shape, each stroke jittered independently.
4. **Stroke ends overshoot slightly** past the corner, which is what makes a
   hand-drawn rectangle read as hand-drawn rather than as a wobbly rectangle.

Rendered with presentation attributes (`stroke`, `fill`, `stroke-width`) rather
than a `<style>` block, because GitHub serves a repository SVG through its
image proxy and sanitiser, where inline CSS and scripts are not dependable.

### Font

`font-family="Comic Sans MS, Chalkboard SE, Segoe Print, cursive"`.

The proxy blocks external font loading, so the only alternative that guarantees
identical lettering everywhere is embedding Excalifont as a ~100KB base64
`@font-face` in the SVG. Rejected: this format was chosen so that a change in
the numbers is legible as a text diff, and burying that diff under a base64
blob repeated in every regeneration contradicts the reason for choosing it.
Readers on macOS and Windows get a handwriting face; Linux falls back to a
generic `cursive`. Upgrading later means changing one function in one script.

### Colour and dark mode

An opaque off-white "paper" rectangle covers the full canvas, with dark ink on
top. A transparent background with dark ink disappears on GitHub's dark theme,
and `prefers-color-scheme` inside a proxied, cached SVG is not dependable. The
paper also happens to be what an Excalidraw canvas looks like, so the fix and
the aesthetic agree.

Palette: paper `#fdfdf7`, ink `#1e1e1e`, bars `#4c6ef5` at reduced opacity for
hachure, muted labels `#5c5c5c`.

## Empty and partial states

With zero period files — today's state — the chart section is replaced by a
hand-drawn empty frame reading `아직 수집된 기간이 없습니다`, and the period
tiles render `0`. A collector that has never run must produce a legible image
saying so, not a broken axis or a division by zero. The same applies when the
air-quality snapshot is absent.

## Components

### `scripts/build-collection-stats.sh`

```text
build-collection-stats.sh            # regenerate docs/collection-stats.svg
build-collection-stats.sh --check    # exit 1 if the committed file is stale
build-collection-stats.sh --snapshot-dir DIR --out FILE   # for the harness
```

`jq` and POSIX shell only, matching every other script here. Runs correctly
with no secret present — it reads the repository and calls no API, so SCHEMA
rule 3 is satisfied trivially.

Internally two stages, so each is testable alone: extract metrics to a JSON
document on stdout, then render that document to SVG. The harness pins the
metric extraction against fixtures without asserting on path geometry.

### `docs/collection-stats.svg`

Neither evidence nor a derived record, so it lives in neither `raw/` nor
`records/`. It is repository self-description, and `docs/` already holds
material about the repository rather than about travel.

### `README.md`

A `## 수집 현황` section directly after `## Concept`, containing the embed and
one line naming the script and its refresh policy.

### `.github/workflows/collection-stats.yml`

Triggers: daily cron, `push` to `main` under `raw/external-snapshots/**`, and
`workflow_dispatch`. The push trigger closes the window in which a merged
capture is not yet reflected; the cron is the backstop.

The job regenerates, and then:

- if nothing changed, it stops without committing;
- if anything outside `docs/collection-stats.svg` is dirty, it **fails** rather
  than committing — a generator that can write anywhere is a generator that can
  quietly rewrite evidence;
- otherwise it commits that one path and pushes to `main`.

`./harness/scripts/smoke.sh` runs before the push, as every other workflow here
does.

### `SCHEMA.md`

A new section, **Generated Artifact Rules**, stating the narrow exception:

1. A generated artifact may be refreshed by a scheduled workflow and pushed
   directly to the default branch, but only if it calls no external API, reads
   no secret, and is derived solely from files already committed here. It has no
   independent content for a human to review, so a pull request would ask for a
   judgement that does not exist. This is the only exception to rule 8.
2. Its path is fixed and single. The workflow fails if any other path is dirty.
3. It is not evidence. A canonical page or record must never cite it as a
   source; it summarises sources, and citing a summary launders provenance.
4. It must be a pure function of the committed inputs. Nothing time-varying —
   including the current date — may appear in the output, so that an unchanged
   input produces an unchanged artifact and no empty commit.

### `--check` is deliberately not wired into `wiki-batch.yml`

Adding it as a required check would turn `main` red for the interval between
merging a capture and regenerating the image — a failure that reports a
scheduling gap as a contract violation. The push trigger already closes that
interval automatically. `--check` exists for local use and for the stats
workflow's own change detection.

## Harness

Per AGENTS.md, the scenario comes first.

`harness/scenarios/collection-stats-image.md` — Given/When/Then covering:

- Given two period snapshots and a station snapshot, When the script runs,
  Then the metrics document reports 2 periods, the summed row count, the
  station count, and the latest `collectedAt`.
- Given the same fixtures, When the script runs twice, Then the two SVG outputs
  are byte-identical.
- Given an empty snapshot directory, When the script runs, Then the SVG renders
  the empty state and the script exits 0.
- Given a committed SVG that does not match its inputs, When `--check` runs,
  Then it exits non-zero.

`harness/fixtures/collection-stats/` — two small period files and one station
file, shaped like the real envelopes but with a handful of rows each.

`harness/scripts/smoke.sh` gains those assertions. Well-formedness is checked
without adding a dependency: the output must begin with `<svg` and end with
`</svg>`, and must contain no unsubstituted placeholder.

## Testing

The behaviour worth protecting is determinism and the empty state; the exact
path coordinates are not. Tests assert on the metrics document and on
byte-equality between two runs, never on geometry — pinning coordinates would
make every visual tweak a test edit while catching nothing real.

Verification before the work is called done: `./harness/scripts/smoke.sh`
passes, `scripts/build-collection-stats.sh --check` passes on a clean tree, and
the rendered image is visually confirmed against the current repository state.

## Risks

- **The image is empty at first.** With no periods captured, the first
  published version shows zeros. That is accurate and the point, but it means
  the feature looks unfinished until the visitor collector merges and runs.
- **`cursive` fallback on Linux** loses the hand-drawn lettering while keeping
  the hand-drawn geometry. Acceptable and reversible.
- **Hachure fill on many bars grows the file.** With one bar per period, an
  18-month backfill means 18 bars; hachure at an 8px gap keeps this in the tens
  of kilobytes. If it grows past that, bars switch to a solid low-opacity fill
  with a hachured outline.
