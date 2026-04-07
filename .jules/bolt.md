## 2024-05-23 - Avoiding DataFrame indexing inside loops
**Learning:** Indexing into a `DataFrame` row-by-row inside a tight, threaded loop introduces significant dynamic dispatch overhead and locks in Julia.
**Action:** Extract DataFrame columns into standard arrays outside of the `@threads` loop to vastly improve performance and eliminate data frame lookup bottlenecks.
