# Explanation Rules Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every rule that more than one document must agree on a single home, so that changing it means visiting its other homes.

**Architecture:** A declarative registry, `packages/explanation-rules.json`, lists each such rule with an id, a statement, why it is true, the detector that counts it, and every document that must reflect it. Each home carries a literal substring already present in (or absent from) that file, and `harness/scripts/smoke.sh` greps for it. Nothing is added to any document, and no package declares the registry, so no bundle byte and no cache prefix moves.

**Tech Stack:** bash, jq, grep, git. No new dependency; every check runs inside the existing `harness/scripts/smoke.sh`.

**Spec:** `docs/superpowers/specs/2026-09-13-explanation-rules-registry-design.md`

## Global Constraints

- **An anchor must be a single-line substring.** `grep` is line-oriented, so an anchor spanning a line break can never match. A shape check rejects anchors containing `\n`. This was found by running the check: the citation rule's first anchor spanned the break between `must be one of those` and `paths, copied **exactly**` and reported absent against text that was present.
- **Never split registry rows on tabs with `IFS=$'\t'`.** Tab is an IFS whitespace character in bash, so consecutive tabs collapse and an empty `mustContain` field silently shifts `mustNotContain` into its place — the check then passes while testing nothing. Emit `mustContain` and `mustNotContain` as **two separate streams**, each with no empty field.
- **The registry is not a bundle document.** `scripts/build-bundle.sh` embeds only what a package declares in `canonicalContext` and `recordContext` plus that package's own prompt. No package may list `packages/explanation-rules.json`.
- **A rule belongs in the registry only if more than one artifact must agree on it.** `homes` therefore has at least two entries; the shape check enforces it. A prohibition with one home stays prose in that document.
- **`log.md` is append-only** (SCHEMA.md → Log Rules). Heading format is exactly `## YYYY-MM-DD - <action> - <subject>`, action from the allowed table.
- **Every task ends with `./harness/scripts/smoke.sh` passing** and a commit.
- **Do not touch `README.md`, `README.ko.md`, or `README.ja.md`.** They carry an unrelated uncommitted revision in the working tree; documenting the registry there is a follow-up.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `packages/explanation-rules.json` | **Create.** The registry: the rules, their detectors, their homes, their anchors. |
| `harness/scripts/smoke.sh` | **Modify.** Validate the registry's shape and check every anchor. |
| `SCHEMA.md` | **Modify.** Name the registry in the `packages/` directory role and state the membership rule. |
| `harness/scenarios/travel-context-explanation.md` | **Modify.** Remove the **Then** clause that requires the forbidden sentence. |
| `packages/generic-travel/prompt.md` | **Modify.** Remove the required behaviour that instructs the same sentence. |
| `queries/why-this-place-today.md` | **Modify.** Move a prohibition out of the *should* list. Canonical page: `log.md` follows. |
| `packages/hanjeok/prompt.md` | **Modify.** Add `NO_DEFERRED_DESTINATION`, which three other documents carry and it does not. |
| `harness/fixtures/wiki-retrieval-context.json` | **Delete.** Dead fixture; no script reads it. Its `forbiddenBehavior` array is the oldest surviving count. |
| `harness/README.md` | **Modify.** Stop naming the deleted fixture. |
| `log.md` | **Modify.** Append entries. |

---

### Task 1: The registry and the check that reads it

**Files:**
- Create: `packages/explanation-rules.json`
- Modify: `harness/scripts/smoke.sh` (add to the `require_file` block near line 68, and a new section after the period-snapshot coverage assertions)
- Modify: `SCHEMA.md` (the `packages/` row in Directory Roles, near line 46)

**Interfaces:**
- Produces: `packages/explanation-rules.json` with top-level keys `version`, `description`, `detectors` (array of enum value strings), and `rules` (array). Each rule: `id`, `statement`, `basis`, `detector` (string or `null`), `homes` (array of `{path, mustContain?, mustNotContain?}`). Tasks 2 and 3 append to `rules` and to one rule's `homes`.

- [ ] **Step 1: Write the registry with seven rules**

`NO_SYSTEM_NAME` is deliberately absent — it is Task 2, because adding it fails until three documents are repaired.

Create `packages/explanation-rules.json`:

```json
{
  "version": "2026-09-13",
  "description": "Rules more than one document must agree on. Not a bundle document: no package lists it, so no model reads it. A rule with a single home stays prose in that document.",
  "detectors": [
    "INVENTED_PLACE",
    "REORDERED_COURSE",
    "LLM_CHOSE",
    "UNCITED_CLAIM",
    "DEFERRED_DESTINATION",
    "TIME_OF_DAY_REASON"
  ],
  "rules": [
    {
      "id": "NO_INVENTED_PLACE",
      "statement": "Every place the answer names appears in the backend facts, spelled exactly as the facts spell it.",
      "basis": "A name is an identifier. 광복궁 for 경복궁 points at a place that does not exist, and a reader who searches for it finds nothing.",
      "detector": "INVENTED_PLACE",
      "homes": [
        { "path": "packages/hanjeok/prompt.md", "mustContain": "alter a place name by even one character" },
        { "path": "concepts/travel-context-layer.md", "mustContain": "Inventing an attraction the backend did not return" }
      ]
    },
    {
      "id": "NO_REORDER",
      "statement": "The answer states the visit order the backend returned and no other.",
      "basis": "Ranking and ordering belong to the consuming service's backend. See decisions/keep-llm-out-of-ranking.md.",
      "detector": "REORDERED_COURSE",
      "homes": [
        { "path": "packages/hanjeok/prompt.md", "mustContain": "change visit order" },
        { "path": "concepts/travel-context-layer.md", "mustContain": "Reordering course items" }
      ]
    },
    {
      "id": "NO_DEFERRED_DESTINATION",
      "statement": "The answer never says the crowded destination was moved to a later position.",
      "basis": "CourseRoutePolicy.bestOrder returns listOf(originId) + best, so the original destination is always the first visit and is never deferred.",
      "detector": "DEFERRED_DESTINATION",
      "homes": [
        { "path": "concepts/travel-context-layer.md", "mustContain": "pushed to a later slot" },
        { "path": "queries/why-this-place-today.md", "mustContain": "say the crowded destination was moved later" },
        { "path": "harness/scenarios/travel-context-explanation.md", "mustContain": "does not say the crowded destination was moved to a later position" }
      ]
    },
    {
      "id": "NO_TIME_OF_DAY_REASON",
      "statement": "The answer gives no time-of-day, day-of-week, or hourly reason for crowding or for a visit time.",
      "basis": "Every congestion fact covers a whole date and nothing finer; a visit time is departure plus travel time. The 2026-08-03 spike settled that the public congestion API carries a date and no time field.",
      "detector": "TIME_OF_DAY_REASON",
      "homes": [
        { "path": "packages/hanjeok/prompt.md", "mustContain": "say that crowding depends on the hour" },
        { "path": "concepts/travel-context-layer.md", "mustContain": "Giving a time-of-day reason for a visit time" },
        { "path": "queries/why-this-place-today.md", "mustContain": "give a time-of-day reason for a visit time" },
        { "path": "harness/scenarios/travel-context-explanation.md", "mustContain": "does not give a time-of-day reason" }
      ]
    },
    {
      "id": "NO_WEATHER_CLAIM",
      "statement": "The answer asserts no weather condition.",
      "basis": "No consumer service supplies a weather fact. records/weather/rules.json and concepts/weather-aware-travel-recommendation.md are evidence without a producer.",
      "detector": null,
      "homes": [
        { "path": "packages/hanjeok/prompt.md", "mustContain": "claim any weather condition" },
        { "path": "concepts/travel-context-layer.md", "mustContain": "Asserting a weather condition" },
        { "path": "queries/why-this-place-today.md", "mustContain": "assert a weather condition" },
        { "path": "harness/scenarios/travel-context-explanation.md", "mustContain": "does not claim a weather condition" }
      ]
    },
    {
      "id": "CITATIONS_IN_BUNDLE",
      "statement": "Every path in citations is one of the separator-line paths of the assembled bundle, and the array is never empty.",
      "basis": "A source that cannot be verified is treated exactly like an invented one, so an answer whose citations cannot be resolved is discarded before it reaches anyone.",
      "detector": "UNCITED_CLAIM",
      "homes": [
        { "path": "packages/hanjeok/prompt.md", "mustContain": "copied **exactly**, including its directory and its file extension" },
        { "path": "harness/scenarios/travel-context-explanation.md", "mustContain": "Every path the explanation cites exists in the assembled bundle" },
        { "path": "harness/scenarios/context-bundle-assembly.md", "mustContain": "so a citation can be checked against the bundle" }
      ]
    },
    {
      "id": "NO_INVENTED_DIAGNOSIS",
      "statement": "When a place has no forecast coverage the answer says so and supplies no grade, percentile, concentration, or better-date list.",
      "basis": "hasCongestionData false is HTTP 200 with success true: missing coverage is a product state, not a failure, and reaching for a number here is the exact failure this wiki exists to prevent.",
      "detector": null,
      "homes": [
        { "path": "packages/hanjeok/prompt.md", "mustContain": "invent a diagnosis when there is none" },
        { "path": "concepts/congestion-diagnosis.md", "mustContain": "inventing one is the exact failure" },
        { "path": "queries/why-this-place-today.md", "mustContain": "there is no grade, percentile, or better-date list" }
      ]
    }
  ]
}
```

- [ ] **Step 2: Add the checker to `harness/scripts/smoke.sh`**

Add to the `require_file` block, directly after `require_file packages/hanjeok/prompt.md`:

```bash
require_file packages/explanation-rules.json
```

Then add this section after the period-snapshot coverage assertions (after the line `|| fail "a 28-day February was stored for a leap year that has 29"`):

```bash
# A rule that more than one document must agree on has one home:
# packages/explanation-rules.json. Each of its homes carries a literal substring
# already present in — or deliberately absent from — that file, and the anchors
# below are what keep the documents from drifting apart. Five consecutive commits
# taught packages/hanjeok/prompt.md prohibitions that reached nothing else, and
# the scenario ended up requiring, under Then, the one sentence the prompt
# forbids. Nothing caught it because nothing was looking.
#
# No marker is added to any document. packages/hanjeok/prompt.md is sent to the
# model, and a rule marker in it would be one more sentence about the system
# rather than the trip.
rules_file=packages/explanation-rules.json

# An anchor spanning a line break can never match, because grep is line-oriented.
# The citation rule's first anchor did exactly that and reported absent against
# text that was present.
jq -e '
  (.rules | length) > 0
  and (.detectors | length) > 0
  and ([.rules[].id] | length) == ([.rules[].id] | unique | length)
  and (.detectors as $known | all(.rules[];
        (.id | test("^[A-Z][A-Z0-9_]*$"))
        and (.statement | length) > 0
        and (.basis | length) > 0
        and (.homes | length) >= 2
        and (.detector == null or (.detector as $d | any($known[]; . == $d)))
        and all(.homes[]; has("mustContain") or has("mustNotContain"))))
  and all(.rules[].homes[];
        ((.mustContain // "") + (.mustNotContain // "")) | contains("\n") | not)
' "$rules_file" >/dev/null || fail "$rules_file is malformed: every rule needs a unique upper-case id, a statement, a basis, a known detector or null, at least two homes, and single-line anchors"

jq -r '.rules[].homes[].path' "$rules_file" | sort -u | while IFS= read -r home_path; do
  [ -f "$home_path" ] || fail "$rules_file names a home that does not exist: $home_path"
done

# Two separate streams, never one with an empty column. Tab is an IFS whitespace
# character in bash, so consecutive tabs collapse and an absent mustContain would
# shift mustNotContain into its place — the check would pass while testing
# nothing.
jq -r '.rules[] | .id as $id | .homes[] | select(has("mustContain"))
       | [$id, .path, .mustContain] | @tsv' "$rules_file" \
| while IFS=$'\t' read -r rule_id home_path anchor; do
  grep -qF -- "$anchor" "$home_path" || fail "$rule_id: $home_path no longer carries \"$anchor\" — update the anchor in $rules_file, and while you are there, check the rule's other homes listed beside it"
done

jq -r '.rules[] | .id as $id | .homes[] | select(has("mustNotContain"))
       | [$id, .path, .mustNotContain] | @tsv' "$rules_file" \
| while IFS=$'\t' read -r rule_id home_path anchor; do
  if grep -qF -- "$anchor" "$home_path"; then
    fail "$rule_id: $home_path contradicts the rule by carrying \"$anchor\" — see $rules_file for the rule's other homes"
  fi
done

# The registry instructs the documents, never the model. A package that listed it
# would put it in the bundle and spend cache prefix on rules the prompt already
# states in the voice the answer has to be written in.
if jq -e --arg p "$rules_file" 'any(.canonicalContext[]?, .recordContext[]?; . == $p)' packages/*/context-bundle.json >/dev/null 2>&1; then
  fail "a package lists $rules_file as bundle context; the registry instructs the documents, not the model"
fi
```

- [ ] **Step 3: Run smoke and verify it passes**

Run: `./harness/scripts/smoke.sh`
Expected: `smoke passed: 14 canonical pages checked`

Seven rules, 21 `mustContain` anchors, 0 `mustNotContain` anchors, all satisfied by the documents as they stand.

- [ ] **Step 4: Break it, to prove the check is load-bearing**

The documents already comply, so passing proves nothing yet. Corrupt one anchor and confirm the suite fails by name:

```bash
cp packages/hanjeok/prompt.md /tmp/prompt-backup.md
sed -i.bak 's/change visit order/change the visit order/' packages/hanjeok/prompt.md
./harness/scripts/smoke.sh; echo "exit=$?"
```

Expected: `FAIL: NO_REORDER: packages/hanjeok/prompt.md no longer carries "change visit order" — update the anchor in packages/explanation-rules.json, and while you are there, check the rule's other homes listed beside it` and `exit=1`.

Then restore and confirm green again:

```bash
cp /tmp/prompt-backup.md packages/hanjeok/prompt.md
rm -f packages/hanjeok/prompt.md.bak /tmp/prompt-backup.md
./harness/scripts/smoke.sh
```

Expected: `smoke passed: 14 canonical pages checked`, and `git status --porcelain packages/hanjeok/prompt.md` prints nothing.

- [ ] **Step 5: Name the registry in `SCHEMA.md`**

Replace the `packages/` row in the Directory Roles table (near line 46):

```markdown
| `packages/` | Service-specific context bundles and prompts, plus `explanation-rules.json`, the registry of rules more than one document must agree on. A rule enters it only when a second artifact must reflect it; a prohibition with one home stays prose in that document. No package may list the registry as bundle context — it instructs the documents, not the model. |
```

- [ ] **Step 6: Run the full gate and commit**

```bash
./harness/scripts/smoke.sh
scripts/build-index.sh --check
git add packages/explanation-rules.json harness/scripts/smoke.sh SCHEMA.md
git commit -m "feat: give a rule that two documents share exactly one home"
```

Expected: smoke passes, `--check` is silent, commit succeeds.

---

### Task 2: The rule three documents contradict

**Files:**
- Modify: `packages/explanation-rules.json` (append one rule)
- Modify: `harness/scenarios/travel-context-explanation.md` (the **Then** list)
- Modify: `packages/generic-travel/prompt.md` (the required-behaviour list)
- Modify: `queries/why-this-place-today.md` (**Answer Policy**)
- Modify: `log.md` (append one entry)

**Interfaces:**
- Consumes: the registry and the checker from Task 1.
- Produces: rule id `NO_SYSTEM_NAME` with three homes, one `mustContain` and two `mustNotContain`.

- [ ] **Step 1: Add the rule — the failing test**

Append to `.rules` in `packages/explanation-rules.json`:

```json
    {
      "id": "NO_SYSTEM_NAME",
      "statement": "The answer never names the system that produced it, and never argues about what the model did or did not do.",
      "basis": "The traveller is reading about their day. Measured on live courses: two of three explanations ended in a spiral of denials, and one named the backend by a mangled transliteration of its own name.",
      "detector": "LLM_CHOSE",
      "homes": [
        { "path": "packages/hanjeok/prompt.md", "mustContain": "name the system that produced any of this" },
        { "path": "harness/scenarios/travel-context-explanation.md", "mustNotContain": "states that the backend selected" },
        { "path": "packages/generic-travel/prompt.md", "mustNotContain": "State that the service backend selected" },
        { "path": "queries/why-this-place-today.md", "mustNotContain": "avoid claiming that the LLM selected or ordered anything" }
      ]
    }
```

- [ ] **Step 2: Run smoke to verify it fails**

Run: `./harness/scripts/smoke.sh`
Expected: FAIL, naming the first contradiction it reaches:

```
FAIL: NO_SYSTEM_NAME: harness/scenarios/travel-context-explanation.md contradicts the rule by carrying "states that the backend selected" — see packages/explanation-rules.json for the rule's other homes
```

- [ ] **Step 3: Repair the scenario**

In `harness/scenarios/travel-context-explanation.md`, the **Then** list opens with these three lines:

```markdown
- The explanation states that the backend selected the course.
- The explanation mentions congestion, distance or relatedness, and visit ordering.
- The explanation does not claim that the LLM re-ranked attractions.
```

Replace all three with:

```markdown
- The explanation mentions congestion, distance or relatedness, and visit ordering.
- The explanation does not name the system that produced the course — not a backend, a service, an API, a wiki, or the model — and does not argue about what was or was not considered. `NO_SYSTEM_NAME` in `packages/explanation-rules.json` is the rule; the traveller is reading about their day, and a sentence answering an accusation nobody made invites the suspicion it was meant to avoid.
```

The first line went because it required the forbidden sentence. The third was too narrow: forbidding the claim that the LLM re-ranked still permits naming the backend, which is what a live run actually did.

- [ ] **Step 4: Repair the generic prompt**

`packages/generic-travel/prompt.md` in full — the first required behaviour is replaced, and a pointer to the registry is added so the next person editing this file knows the rules are shared:

```markdown
# Generic Travel Explanation Prompt

Use backend facts first. Use Travel Context Wiki only to explain, not to decide.

The rules this shares with every other service package are in
`packages/explanation-rules.json`. Read them before editing this file.

Required behavior:

- Write for the traveller, never about the system that produced the answer.
- Explain weather fit only from provided backend weather facts.
- Explain congestion only from provided backend congestion facts.
- Use retrieved canonical pages for policy language.
- Do not invent attractions, scores, weather, or public API facts.
```

- [ ] **Step 5: Repair the canonical page**

In `queries/why-this-place-today.md`, **Answer Policy**, delete the last item of *The answer should*:

```markdown
- avoid claiming that the LLM selected or ordered anything
```

and add it, reworded to match the grammar of the list it moves into, as the first item of *The answer must not*:

```markdown
- claim that the LLM selected or ordered anything, or name the system that produced the course
```

A prohibition sitting in a list of things to do is the shape `1c12819` diagnosed: this page ships in the bundle, and reading an instruction to avoid a claim reads as an instruction to make the denial. Two live runs ended in a spiral of exactly that.

- [ ] **Step 6: Run smoke to verify it passes**

Run: `./harness/scripts/smoke.sh`
Expected: `smoke passed: 14 canonical pages checked`

- [ ] **Step 7: Confirm the bundle still assembles and is still deterministic**

`queries/why-this-place-today.md` and `packages/generic-travel/prompt.md` are both bundle documents, so their bytes moved.

```bash
scripts/build-bundle.sh hanjeok > /tmp/bundle-a
scripts/build-bundle.sh hanjeok > /tmp/bundle-b
cmp /tmp/bundle-a /tmp/bundle-b && echo "deterministic"
scripts/build-bundle.sh generic-travel >/dev/null
```

Expected: `deterministic`, and each run prints its `build-bundle: <service> — N files, N bytes` line to stderr without a size warning.

- [ ] **Step 8: Append the log entry**

A canonical page changed, so SCHEMA.md → Index And Log Synchronization applies. `index.md` does not change: no page is created, archived, renamed, or deleted.

Append to `log.md`:

```markdown
## 2026-09-13 - update - stop requiring the sentence the prompt forbids

- `harness/scenarios/travel-context-explanation.md` required, under **Then**, that "the explanation states that the backend selected the course". `packages/hanjeok/prompt.md` forbids exactly that: the traveller is reading about their day, not about a backend. An implementation satisfying the scenario failed the prompt and the other way round, and the scenario is the contract.
- Repaired: the scenario. The clause is gone, and the narrow one beside it — "does not claim that the LLM re-ranked attractions" — is now the rule it should always have been, because forbidding only that claim still permitted naming the backend, which a live run did, by a mangled transliteration of the backend's own name.
- Repaired: `packages/generic-travel/prompt.md`, whose first required behaviour instructed the same sentence. It has no consumer, so nothing had failed yet; the contradiction was waiting rather than absent.
- Repaired: `queries/why-this-place-today.md`. "avoid claiming that the LLM selected or ordered anything" sat in the **should** list — a prohibition among things to do, inside a document that ships in the bundle. `1c12819` diagnosed this shape: reading such a line reads as an instruction to make the denial, and two of three live explanations ended in a spiral of them. The item moved to **must not**, where it belongs.
- Recorded: `NO_SYSTEM_NAME` in `packages/explanation-rules.json`, with all four documents as its homes. The two that contradicted it are pinned by `mustNotContain`, so the contradiction cannot come back quietly.
- Canonical pages unchanged at 14.
```

- [ ] **Step 9: Run the full gate and commit**

```bash
./harness/scripts/smoke.sh
scripts/build-index.sh --check
git add packages/explanation-rules.json harness/scenarios/travel-context-explanation.md packages/generic-travel/prompt.md queries/why-this-place-today.md log.md
git commit -m "fix: stop requiring the one sentence the prompt forbids"
```

---

### Task 3: The rule the prompt was missing

**Files:**
- Modify: `packages/explanation-rules.json` (one home added to `NO_DEFERRED_DESTINATION`)
- Modify: `packages/hanjeok/prompt.md` (the *The answer must not* list)

**Interfaces:**
- Consumes: `NO_DEFERRED_DESTINATION` as written in Task 1.

- [ ] **Step 1: Add the missing home — the failing test**

In `packages/explanation-rules.json`, add to `NO_DEFERRED_DESTINATION`'s `homes`, as the first entry:

```json
        { "path": "packages/hanjeok/prompt.md", "mustContain": "say the crowded destination was moved to a later position" },
```

Three documents carry this rule — `concepts/travel-context-layer.md`, `queries/why-this-place-today.md`, and the scenario — and the one document the model actually reads does not. It holds today only because those canonical pages ship in the same bundle.

- [ ] **Step 2: Run smoke to verify it fails**

Run: `./harness/scripts/smoke.sh`
Expected:

```
FAIL: NO_DEFERRED_DESTINATION: packages/hanjeok/prompt.md no longer carries "say the crowded destination was moved to a later position" — update the anchor in packages/explanation-rules.json, and while you are there, check the rule's other homes listed beside it
```

- [ ] **Step 3: Add the rule to the prompt**

In `packages/hanjeok/prompt.md`, in the *The answer must not* list, directly after the `change visit order` item:

```markdown
- say the crowded destination was moved to a later position. It is always the first visit —
  the backend's own `reason` string for that item says so, and
  `concepts/course-generation-policy.md` explains why the order cannot put it anywhere
  else. A busy destination visited first is the whole shape of the course; describing it
  as deferred describes a course the traveller was not given.
```

- [ ] **Step 4: Run smoke to verify it passes**

Run: `./harness/scripts/smoke.sh`
Expected: `smoke passed: 14 canonical pages checked`

- [ ] **Step 5: Confirm the bundle grew and is still deterministic**

```bash
scripts/build-bundle.sh hanjeok > /tmp/bundle-c 2>/tmp/bundle-c.err
scripts/build-bundle.sh hanjeok > /tmp/bundle-d 2>/dev/null
cmp /tmp/bundle-c /tmp/bundle-d && echo "deterministic"
cat /tmp/bundle-c.err
```

Expected: `deterministic`, and the stderr line reports 9 files with a byte count larger than before and no size warning. No assertion pins the byte count; the 40 KB soft limit in `scripts/build-bundle.sh` is far above it.

- [ ] **Step 6: Commit**

```bash
git add packages/explanation-rules.json packages/hanjeok/prompt.md
git commit -m "fix: tell the prompt the rule its three neighbours already knew"
```

---

### Task 4: Retire the fixture nothing reads

**Files:**
- Delete: `harness/fixtures/wiki-retrieval-context.json`
- Modify: `harness/README.md:9`
- Modify: `log.md` (append one entry)

- [ ] **Step 1: Confirm nothing reads it**

```bash
grep -rn "wiki-retrieval-context" --include="*.sh" --include="*.json" --include="*.md" . | grep -v "^./.git" | grep -v "^./log.md"
```

Expected: exactly two hits — `harness/README.md:9` and `docs/superpowers/plans/2026-08-03-travel-context-wiki-pivot.md:73`. The plan is a historical record and is not edited. If any `.sh` file appears, stop: the fixture is live and this task does not apply.

- [ ] **Step 2: Delete the fixture and fix the reference**

```bash
git rm harness/fixtures/wiki-retrieval-context.json
```

In `harness/README.md`, delete this line:

```markdown
- `fixtures/wiki-retrieval-context.json`: expected wiki pages to retrieve.
```

- [ ] **Step 3: Run smoke and verify it passes**

Run: `./harness/scripts/smoke.sh`
Expected: `smoke passed: 14 canonical pages checked`. No `require_file` names the fixture, and the JSON-validity loop simply finds one file fewer.

- [ ] **Step 4: Append the log entry**

```markdown
## 2026-09-13 - delete - retire the retrieval-context fixture

- Deleted `harness/fixtures/wiki-retrieval-context.json`. No script read it, so it could not drift *into* anything — but its `forbiddenBehavior` array listed three rules where `packages/explanation-rules.json` now lists eight, and it is the first thing a reader greps for. A stale count nothing enforces is worse than no count.
- `harness/README.md` no longer names it. `docs/superpowers/plans/2026-08-03-travel-context-wiki-pivot.md` still does, and stays as written: it records what was planned on that day.
- The registry is now the only place that answers how many forbidden behaviours there are. The counts in the plans and in `decisions/choose-explanation-model.md` record what was measured when they were written and are left alone.
```

- [ ] **Step 5: Run the full gate and commit**

```bash
./harness/scripts/smoke.sh
scripts/build-index.sh --check
git add -A harness/fixtures harness/README.md log.md
git commit -m "chore: retire the fixture whose rule count nothing enforced"
```

---

## Verification

After Task 4, the whole change is one branch. Confirm the mechanism end to end:

```bash
./harness/scripts/smoke.sh
scripts/build-index.sh --check
jq '{rules: (.rules|length), homes: ([.rules[].homes[]]|length), mustContain: ([.rules[].homes[]|select(has("mustContain"))]|length), mustNotContain: ([.rules[].homes[]|select(has("mustNotContain"))]|length)}' packages/explanation-rules.json
```

Expected: smoke passes, `--check` is silent, and the registry reports 8 rules across 26 homes — 23 `mustContain`, 3 `mustNotContain`. The arithmetic: 21 homes after Task 1, plus 4 for `NO_SYSTEM_NAME` in Task 2, plus the one Task 3 adds to `NO_DEFERRED_DESTINATION`.

Then prove once more that the anchors are load-bearing, this time on a `mustNotContain`:

```bash
printf '\n- The explanation states that the backend selected the course.\n' >> harness/scenarios/travel-context-explanation.md
./harness/scripts/smoke.sh; echo "exit=$?"
git checkout harness/scenarios/travel-context-explanation.md
./harness/scripts/smoke.sh
```

Expected: the first run fails naming `NO_SYSTEM_NAME` and the scenario, `exit=1`; after the checkout the suite passes and `git status --porcelain` shows nothing outside the intended files.

## Out of scope

- **The Hermes Agent's Kotlin `Behaviour` enum.** Separate repository, separate change. This repository has to hold the canonical list before anything can cite it.
- **Naming the seventh detector.** `NO_WEATHER_CLAIM` and `NO_INVENTED_DIAGNOSIS` carry `detector: null`. Four documents forbid a weather claim and `decisions/choose-explanation-model.md` measured seven behaviours, but the only enum written down here has six and none of them is weather. Resolving it means reading the consumer's enum.
- **The trilingual README.** An unrelated revision is uncommitted in the working tree.
- **A detector for any rule that lacks one.** The registry records the absence; it does not fill it.
