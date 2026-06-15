-- ============================================================
-- DUPLICATE IDENTITY DETECTION
-- Identified 51.4M duplicate identity records across two
-- consumer email tables (40.5M + 10.9M) using these patterns
-- ============================================================

-- ------------------------------------------------------------
-- 1. Quick duplicate count via uniq() vs count()
-- ------------------------------------------------------------
-- Fast approximate check on large tables (uniq is HyperLogLog-based)
SELECT
    count()                       AS total_rows,
    uniq(record_id)               AS unique_ids,
    count() - uniq(record_id)     AS duplicate_count,
    round((count() - uniq(record_id)) * 100.0 / count(), 2) AS duplicate_pct
FROM consumer_email_dataset;


-- ------------------------------------------------------------
-- 2. Exact duplicate count (slower, exact)
-- ------------------------------------------------------------
SELECT
    count() AS total_rows,
    uniqExact(record_id) AS unique_ids,
    count() - uniqExact(record_id) AS exact_duplicates
FROM consumer_email_supplemental;


-- ------------------------------------------------------------
-- 3. Find which record_ids are duplicated and how many times
-- ------------------------------------------------------------
SELECT
    record_id,
    count() AS occurrences
FROM consumer_email_dataset
GROUP BY record_id
HAVING occurrences > 1
ORDER BY occurrences DESC
LIMIT 20;


-- ------------------------------------------------------------
-- 4. Cross-table duplicate check (sampled — full join would
--    exceed memory on 700M+ row tables)
-- ------------------------------------------------------------
-- Sample 1% of each table before joining to estimate overlap
SELECT count() AS overlap_estimate
FROM (
    SELECT email_address FROM consumer_email_dataset
    WHERE cityHash64(email_address) % 100 = 0       -- ~1% sample
) a
INNER JOIN (
    SELECT email_address FROM consumer_email_supplemental
    WHERE cityHash64(email_address) % 100 = 0       -- same 1% bucket
) b
ON a.email_address = b.email_address;


-- ------------------------------------------------------------
-- 5. Version comparison — find records present in an old
--    table version but missing from the current version
-- ------------------------------------------------------------
-- Used to investigate a 1.7M record gap between table versions.
-- On very large tables, run this with a sampled subset first.
SELECT count() AS records_only_in_old_version
FROM consumer_phone_dataset_v0 AS old
WHERE old.phone_number NOT IN (
    SELECT phone_number FROM consumer_phone_dataset
);
