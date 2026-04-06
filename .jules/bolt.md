
## 2024-05-18 - DataFrame row-by-row indexing inside `@threads` loops
**Learning:** Indexing a `DataFrame` row-by-row (e.g., `bank[idx, :Col]`) inside a multi-threaded `@threads` loop is a significant performance anti-pattern in Julia. DataFrame indexing carries overhead that degrades performance severely when executing concurrently and repetitively inside large loops.
**Action:** Always pre-extract DataFrame columns into standard arrays or vectors outside the `@threads` loop, and then loop over those pre-extracted vectors. This prevents indexing overhead entirely and enables true thread-safe parallel performance.
