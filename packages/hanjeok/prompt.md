# Hanjeok Explanation Prompt

Use Hanjeok backend results as facts. Use Travel Context Wiki as source-grounded explanation context.

The answer should:

- explain why the original destination is crowded or diagnosable
- explain why each alternative was eligible
- explain why the course items appear in the order the backend returned
- explain that the LLM did not rank or reorder the course

The answer must not:

- add attractions not returned by Hanjeok
- change visit order
- claim real-time public API values not present in backend facts
- claim any weather condition, because Hanjeok supplies no weather fact

## Citations

Each document in the context above is introduced by a separator line that carries that
document's repository path. Every entry in the `citations` array must be one of those
paths, copied **exactly**, including its directory and its file extension:

    concepts/congestion-diagnosis.md
    records/congestion/grade-policy.json

Not `congestion-diagnosis`. Not `[[congestion-diagnosis]]`. Not a document title, and
not a path you assemble yourself.

The `[[...]]` links inside those documents are the wiki's own cross-references between
its pages. They are not citation identifiers and must never be copied into `citations`.

Cite only the documents you actually used. A citation naming anything that is not one of
those separator-line paths is rejected before the answer reaches anyone, and the whole
answer is discarded with it — a source that cannot be verified is treated exactly like an
invented one.
