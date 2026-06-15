-- ============================================================
-- ENRICHMENT JOIN FRAMEWORK
-- Cross-table enrichment using a hashed JOIN key built from
-- normalized name + ZIP code. Validated across all 50 US states.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Build normalized JOIN key columns (MATERIALIZED)
-- ------------------------------------------------------------
-- These columns are computed automatically on insert and
-- cannot be modified via UPDATE (MATERIALIZED columns are
-- recalculated from their source expression).

-- Example DDL for the enrichment reference table:
--
-- CREATE TABLE enrichment_reference_dataset (
--     ...
--     first_name           String,
--     last_name            String,
--     zip5                 String,
--     first_name_norm      String MATERIALIZED lower(trimBoth(first_name)),
--     last_name_norm       String MATERIALIZED lower(trimBoth(last_name)),
--     zip_norm             String MATERIALIZED trimBoth(zip5),
--     join_key             UInt64 MATERIALIZED cityHash64(
--                               first_name_norm, last_name_norm, zip_norm
--                           )
-- ) ENGINE = SharedMergeTree(...)
-- ORDER BY (state, join_key);


-- ------------------------------------------------------------
-- 2. Basic enrichment JOIN
-- ------------------------------------------------------------
-- Append demographic/financial attributes from the reference
-- table to records in a target table.
SELECT
    target.email_address,
    target.state,
    ref.net_worth_segment,
    ref.credit_rating,
    ref.home_owner_flag
FROM consumer_phone_dataset AS target
INNER JOIN enrichment_reference_dataset AS ref
    ON target.join_key = ref.join_key;


-- ------------------------------------------------------------
-- 3. Match rate calculation — overall
-- ------------------------------------------------------------
SELECT
    count() AS total_records,
    countIf(ref.join_key != 0) AS matched_records,
    round(countIf(ref.join_key != 0) * 100.0 / count(), 2) AS match_rate_pct
FROM consumer_phone_dataset AS target
LEFT JOIN enrichment_reference_dataset AS ref
    ON target.join_key = ref.join_key;


-- ------------------------------------------------------------
-- 4. Match rate by state — used to prioritize enrichment
--    budget allocation
-- ------------------------------------------------------------
SELECT
    target.state,
    count() AS total_records,
    countIf(ref.join_key != 0) AS matched_records,
    round(countIf(ref.join_key != 0) * 100.0 / count(), 2) AS match_rate_pct
FROM consumer_phone_dataset AS target
LEFT JOIN enrichment_reference_dataset AS ref
    ON target.join_key = ref.join_key
GROUP BY target.state
ORDER BY match_rate_pct DESC;

-- Result pattern observed:
--   Highest match rates: DE 34%, AR 34%, MD 32%
--   Lowest match rates:  UT 0.3%, NM 1.1%
-- Geographic variation this large directly informs where
-- enrichment spend should be concentrated.


-- ------------------------------------------------------------
-- 5. Why placeholder values broke this JOIN
-- ------------------------------------------------------------
-- Before cleaning, 59.5M records in the enrichment reference
-- table had phone_number = '0000000000'. If the JOIN key had
-- included raw phone numbers, every one of those 59.5M rows
-- would match any other row with the same placeholder —
-- producing massive false-positive enrichment.
--
-- Lesson: placeholder values must be removed BEFORE they
-- participate in any JOIN key, hashed or not.

-- Check for placeholder contamination before joining on a field:
SELECT
    countIf(phone_number = '0000000000') AS placeholder_count,
    round(countIf(phone_number = '0000000000') * 100.0 / count(), 2) AS pct
FROM enrichment_reference_dataset;
