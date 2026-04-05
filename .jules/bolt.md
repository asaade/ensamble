## 2024-05-24 - DataFrame row iteration within multi-threaded blocks in Julia
**Learning:** Indexing into a `DataFrame` row-by-row inside a `@threads` loop causes severe performance penalties due to repeated memory allocations, lack of type inference, and lock contention.
**Action:** Always pre-extract required `DataFrame` columns into type-stable native arrays (`Vector`s) outside of the `@threads` block. Iterate over these plain vectors concurrently to maximize speed and thread safety.
