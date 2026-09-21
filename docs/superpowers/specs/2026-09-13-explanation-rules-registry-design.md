# Explanation Rules Registry

**Date:** 2026-09-13
**Artifact:** `packages/explanation-rules.json`, enforced by `harness/scripts/smoke.sh`

## Goal

Give a rule that more than one document must agree on exactly one home, so that
changing it means visiting its other homes. Today no such place exists, and the
documents have drifted apart in a way that is already visible in the repository.

## The drift this fixes

Five consecutive commits (`1c12819`, `0ec8f63`, `38b764e`, `7076e00`, `1a8d231`)
added roughly ten prohibitions to `packages/hanjeok/prompt.md`, each earned by
reading what the deployed service actually produced. None of them reached any
other document. What that left behind:

**A contradiction.** `harness/scenarios/travel-context-explanation.md` lists,
under **Then**:

> The explanation states that the backend selected the course.

`packages/hanjeok/prompt.md` forbids exactly that sentence:

> name the system that produced any of this. The traveller is reading about
> their day, not about a backend, a service, an API, or a wiki.

The scenario is the repository's contract for this feature. An implementation
that satisfies it fails the prompt, and an implementation that satisfies the
prompt fails it.

**The same contradiction, latent.** `packages/generic-travel/prompt.md` opens
its required-behaviour list with "State that the service backend selected the
destination or course." It has no consumer today, so nothing has failed yet.

**A shape that is known to cause the failure it forbids.** The **Answer Policy →
The answer should** list in `queries/why-this-place-today.md` ends with "avoid
claiming that the LLM selected or ordered anything" — a prohibition sitting in a
list of things to do, inside a document that ships in the bundle. `1c12819`
diagnosed this precise shape: several documents in the bundle exist to constrain
the model, and reading them reads as an instruction to affirm them. Two runs
against live courses ended in a spiral of denials.

**A count that no longer agrees with itself.** The forbidden behaviours are
"6종" in `docs/superpowers/plans/2026-08-31-hermes-agent-core.md`, "seven" in
`README.md` and `decisions/choose-explanation-model.md`, and "8종" in
`docs/superpowers/plans/2026-09-05-hermes-agent-followup.md`. Nothing is wrong
with any single document; there is simply nothing that says how many there are.

**Rules with no shared home at all.** `NO_DEFERRED_DESTINATION` lives in
`concepts/travel-context-layer.md`, `queries/why-this-place-today.md`, and the
scenario — but not in `packages/hanjeok/prompt.md`, which is the document the
model actually reads. It holds today only because the canonical pages ship in the
same bundle.

## What the registry holds

A rule belongs in the registry when **more than one artifact must agree on it**.
A prohibition that lives only in `packages/hanjeok/prompt.md` — most of the Voice
section — stays there as prose: a rule with one home has nothing to drift
against, and copying it into a registry would create the second home that makes
drift possible.

`packages/explanation-rules.json`:

```json
{
  "version": "2026-09-13",
  "description": "Rules more than one document must agree on. Not a bundle document; no package lists it, so no model reads it.",
  "rules": [
    {
      "id": "NO_SYSTEM_NAME",
      "statement": "The answer never names the system that produced it.",
      "basis": "The traveller is reading about their day. A backend, a service, an API, a wiki, and the model itself are all off-topic, and a transliteration of one is worse than the word.",
      "detector": "LLM_CHOSE",
      "homes": [
        { "path": "packages/hanjeok/prompt.md",
          "mustContain": "name the system that produced any of this" },
        { "path": "harness/scenarios/travel-context-explanation.md",
          "mustNotContain": "states that the backend selected" },
        { "path": "packages/generic-travel/prompt.md",
          "mustNotContain": "State that the service backend selected" }
      ]
    }
  ]
}
```

Fields:

| Field | Meaning |
| --- | --- |
| `id` | Stable identifier. What another repository cites. |
| `statement` | One sentence. What the rule requires, not how it is checked. |
| `basis` | Why it is true — the fact, contract, or measured failure behind it. |
| `detector` | The `Behaviour` enum value that counts violations, or `null` when no machine sees this axis. |
| `homes[]` | Every artifact that must reflect the rule, with the anchor that proves it does. |

`homes[].mustContain` and `homes[].mustNotContain` are literal substrings already
present in (or absent from) that file. Nothing is added to any document: no
`<!-- rule: ID -->` markers, because `packages/hanjeok/prompt.md` is sent to the
model and a marker would be one more thing in the context window that is about
the system rather than the trip — the exact category `NO_SYSTEM_NAME` exists to
keep out.

The registry is not a bundle document. `scripts/build-bundle.sh` embeds only the
paths a package declares in `canonicalContext` and `recordContext`, plus that
package's own prompt; no package lists this file, so the bundle's bytes and its
cache prefix do not move.

### Initial rule set

Eight, derived from the documents as they stand:

| `id` | `detector` | Homes today |
| --- | --- | --- |
| `NO_INVENTED_PLACE` | `INVENTED_PLACE` | prompt, `travel-context-layer` |
| `NO_REORDER` | `REORDERED_COURSE` | prompt, `travel-context-layer` |
| `NO_DEFERRED_DESTINATION` | `DEFERRED_DESTINATION` | `travel-context-layer`, `why-this-place-today`, scenario |
| `NO_TIME_OF_DAY_REASON` | `TIME_OF_DAY_REASON` | prompt, `travel-context-layer`, `why-this-place-today`, scenario |
| `NO_WEATHER_CLAIM` | `null` — see below | prompt, `travel-context-layer`, `why-this-place-today`, scenario |
| `CITATIONS_IN_BUNDLE` | `UNCITED_CLAIM` | prompt, scenario, `context-bundle-assembly` |
| `NO_SYSTEM_NAME` | `LLM_CHOSE` | prompt, scenario, generic prompt |
| `NO_INVENTED_DIAGNOSIS` | `null` | prompt, `congestion-diagnosis`, `why-this-place-today` |

`NO_WEATHER_CLAIM` gets `null` rather than a guess. Four documents forbid a
weather claim and `decisions/choose-explanation-model.md` measured seven
behaviours, but the only enum written down in this repository has six and none
of them is weather. Which value counts the seventh is not recorded here, so the
registry records that it does not know instead of inventing a name that a
consuming repository would then be expected to match. Resolving it means reading
the consumer's enum, which is outside this change.

`NO_INVENTED_PLACE` absorbs the character-for-character name rule from `0ec8f63`:
a mangled name is a place the facts do not contain, which is what the detector
already measures. `NO_DEFERRED_DESTINATION` is the entry that shows the registry
working before anything breaks — it is missing from the one document the model
reads, and the plan adds it there.

## What smoke enforces

Per `homes[]` entry: the path exists; `mustContain` is present; `mustNotContain`
is absent. Plus, per rule: `id` is unique, `statement` and `basis` are non-empty,
and `detector` is either `null` or one of the enum values the registry itself
lists.

The anchors are brittle on purpose. Rewording a rule breaks the check, and the
person rewording it goes to the registry to fix the anchor — where the other
homes of that rule are listed. That is the whole mechanism. The cost is real:
a cosmetic edit to `prompt.md` can fail the suite for a reason that looks
pedantic. The failure message therefore names the rule id and its other homes,
so the reason is legible at the moment it fires.

## Repairs that come with it

1. `harness/scenarios/travel-context-explanation.md` — replace the **Then**
   clause with what is true now. The explanation does not state that the backend
   selected the course; it states the course and why each place is in it.
2. `packages/generic-travel/prompt.md` — rewrite the required-behaviour list so
   it does not instruct a forbidden sentence. The package stays: it is the only
   evidence in the repository that bundle assembly is not single-service.
3. `queries/why-this-place-today.md` — move "avoid claiming that the LLM selected
   or ordered anything" out of **The answer should** and into **The answer must
   not**, where a prohibition belongs and does not read as a cue to affirm.
   A canonical page changes, so `log.md` gains an entry; `index.md` is unchanged
   because no page is created, archived, or renamed.
4. `packages/hanjeok/prompt.md` — add `NO_DEFERRED_DESTINATION`, which three
   other documents carry and the prompt does not.
5. `harness/fixtures/wiki-retrieval-context.json` — delete. Its
   `forbiddenBehavior` array lists three rules and is the oldest surviving count;
   no script reads the file, so it cannot drift *into* anything, but it is the
   first thing a reader greps and finds. Recorded in `log.md` rather than left
   as a silent deletion.

## What this does not do

- **It does not change the Hermes Agent's Kotlin enum.** That is a separate
  repository and a separate change. This repository has to hold the canonical
  list before anything can cite it.
- **It does not correct the counts in historical documents.** The plans and
  `decisions/choose-explanation-model.md` record what was measured on the day
  they were written; the registry states what is true now. `log.md` is
  append-only for the same reason.
- **It does not add a detector.** `NO_INVENTED_DIAGNOSIS` carries `detector:
  null` and stays that way until something counts it.
- **It does not verify that a home's prose actually means the rule.** An anchor
  proves a sentence is present, not that it says the right thing. A reviewer
  still reads. What the check removes is the failure where nobody knew there was
  a second document to read at all.

## Risks

- **Anchor rot.** Every edit to rule wording costs a registry visit. This is the
  intended cost, and it is also the most likely reason someone deletes the
  check. The failure message naming the other homes is what makes it worth
  keeping; if it degrades into "smoke.sh is annoying", the mechanism has failed.
- **A registry that is complete on the day it is written and stale a month
  later.** The membership rule — more than one artifact must agree — is what
  keeps it small enough to stay true. Eight entries, not the twenty prohibitions
  `prompt.md` carries.
