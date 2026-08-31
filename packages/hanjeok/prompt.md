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
