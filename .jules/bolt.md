## 2024-04-07 - DataFrame Threading Overhead
**Learning:** Indexing into a `DataFrame` row-by-row inside a `@threads` loop introduces significant performance overhead due to dynamic dispatch and memory allocations within the Julia runtime.
**Action:** Always pre-extract DataFrame columns into standard arrays *outside* the multithreaded loop, and then iterate over these arrays *inside* the loop.
