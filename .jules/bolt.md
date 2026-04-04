## 2024-04-04 - [DataFrame Indexing in Threads]
**Learning:** A known performance anti-pattern in Julia codebases is indexing into a `DataFrame` row-by-row inside a `@threads` loop. DataFrames indexing has a slight overhead that gets highly magnified when done per-row within multi-threaded loops, causing massive allocations and degraded performance.
**Action:** Optimize this by pre-extracting `DataFrame` columns into standard arrays outside the loop, and then indexing into these standard arrays within the `@threads` block.
