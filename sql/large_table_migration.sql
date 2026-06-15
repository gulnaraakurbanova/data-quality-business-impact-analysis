-- ============================================================
-- HASH-BASED BATCH MIGRATION
-- Pattern used to migrate a ~330M row table between
-- environments without exceeding ClickHouse memory limits.
-- ============================================================

-- ------------------------------------------------------------
-- PROBLEM
-- ------------------------------------------------------------
-- A single INSERT ... SELECT * over ~330M rows fails with:
--   Code: 241. DB::Exception: (total) memory limit exceeded
--
-- SOLUTION
-- ------------------------------------------------------------
-- Split the source table into N equal partitions using
-- cityHash64() on the primary key, then INSERT each
-- partition separately. Because the hash is deterministic,
-- every row is migrated exactly once -- no duplicates, no gaps.


-- ------------------------------------------------------------
-- Single batch (1 of 10)
-- ------------------------------------------------------------
INSERT INTO target_db.large_table
SELECT *
FROM source_db.large_table
WHERE cityHash64(toString(primary_key)) % 10 = 0
SETTINGS max_memory_usage = 4000000000;  -- 4GB cap per batch


-- ------------------------------------------------------------
-- Full migration orchestration
-- ------------------------------------------------------------
-- See python/batch_migration.py for the orchestration script
-- that loops over all 10 batches.


-- ------------------------------------------------------------
-- VALIDATION -- confirm zero duplication, zero data loss
-- ------------------------------------------------------------
SELECT count() FROM source_db.large_table;
-- Result: ~330M

SELECT count() FROM target_db.large_table;
-- Result: ~330M (exact match -- zero loss, zero duplication)

-- Additional check: confirm no record was migrated twice
SELECT count() - uniqExact(primary_key) AS duplicates
FROM target_db.large_table;
-- Expected result: 0


-- ------------------------------------------------------------
-- WHY cityHash64 AND NOT modulo on the raw key?
-- ------------------------------------------------------------
-- Raw numeric keys are often sequential or clustered (e.g. all
-- IDs from one data-load batch share a numeric range). Using
-- `primary_key % 10` directly can produce wildly uneven batch
-- sizes if keys aren't uniformly distributed.
--
-- cityHash64() produces a pseudo-random 64-bit hash from the
-- input, so `hash % 10` distributes rows close to evenly
-- across all 10 batches regardless of how the source keys
-- were originally assigned.
