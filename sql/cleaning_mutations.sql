-- ============================================================
-- CLEANING MUTATIONS WITH PRE/POST VALIDATION
-- ClickHouse mutations (ALTER TABLE UPDATE/DELETE) run
-- asynchronously. Every mutation in this project followed:
--   1. Profile (count affected rows)
--   2. Mutate
--   3. Wait for mutation to complete
--   4. Validate (re-count, confirm fix)
-- ============================================================

-- ------------------------------------------------------------
-- PATTERN: Wait for mutations to complete before continuing
-- ------------------------------------------------------------
-- Run this in a loop (e.g. every 10s) until it returns 0
SELECT count()
FROM system.mutations
WHERE is_done = 0
  AND database = 'sandbox_db';


-- ============================================================
-- EXAMPLE 1: Remove integer-overflow placeholder values
-- ============================================================

-- Step 1 — Profile: how many records affected?
SELECT count() FROM business_contacts_supplemental
WHERE phone_number = '2147483647';
-- Result: 47,200,000 (47.2M)

-- Step 2 — Mutate: clear the overflow placeholder
ALTER TABLE business_contacts_supplemental
UPDATE phone_number = ''
WHERE phone_number = '2147483647';

-- Step 3 — Validate: confirm zero remaining
SELECT count() FROM business_contacts_supplemental
WHERE phone_number = '2147483647';
-- Expected result: 0


-- ============================================================
-- EXAMPLE 2: Replace placeholder dates with NULL
-- ============================================================

-- Step 1 — Profile
SELECT
    countIf(date_of_birth = '1970-01-01') AS fake_dob,
    round(countIf(date_of_birth = '1970-01-01') * 100.0 / count(), 2) AS pct
FROM consumer_email_supplemental;

-- Step 2 — Mutate (column must be Nullable to accept NULL)
ALTER TABLE consumer_email_supplemental
UPDATE date_of_birth = NULL
WHERE date_of_birth = '1970-01-01';

-- Step 3 — Validate
SELECT countIf(date_of_birth IS NOT NULL AND date_of_birth = '1970-01-01')
FROM consumer_email_supplemental;
-- Expected result: 0


-- ============================================================
-- EXAMPLE 3: Remove placeholder phone numbers from an
-- enrichment reference table (these were causing false
-- positive JOIN matches — 59.5M records)
-- ============================================================

-- Step 1 — Profile
SELECT count() FROM enrichment_reference_dataset
WHERE phone_number = '0000000000';
-- Result: 59,500,000

-- Step 2 — Mutate
ALTER TABLE enrichment_reference_dataset
UPDATE phone_number = ''
WHERE phone_number = '0000000000';

-- Step 3 — Validate
SELECT count() FROM enrichment_reference_dataset
WHERE phone_number = '0000000000';
-- Expected result: 0


-- ============================================================
-- EXAMPLE 4: ORDER BY KEY LIMITATION
-- This mutation FAILS — demonstrates a fundamental
-- ClickHouse constraint that shaped the remediation roadmap
-- ============================================================

-- Attempting to clean a header-leak value in a column that
-- is part of the table's ORDER BY key:
ALTER TABLE consumer_email_dataset
UPDATE city = ''
WHERE lower(city) = 'city';

-- Result:
-- Code: 420. DB::Exception: Cannot UPDATE key column `city`.
-- (CANNOT_UPDATE_COLUMN)

-- Check which columns are part of the sorting key before
-- planning any cleanup:
SELECT name, is_in_sorting_key
FROM system.columns
WHERE database = 'sandbox_db'
  AND table = 'consumer_email_dataset'
  AND is_in_sorting_key = 1;

-- Columns in the ORDER BY key cannot be fixed via mutation.
-- The only remediation path is full table recreation with a
-- corrected ORDER BY definition.


-- ============================================================
-- EXAMPLE 5: Dry-run pattern for risky production mutations
-- ============================================================
-- Before promoting a mutation to production, run it in
-- "dry run" mode — print what would happen without executing.

-- Python pseudocode:
--
-- def run_mutation(query, label, dry_run=True):
--     if dry_run:
--         print(f"[DRY RUN] {label}")
--         print(f"Query: {query[:120]}...")
--     else:
--         client.command(query)
--
-- run_mutation(sic_code_fix_query, "Fix invalid SIC codes", dry_run=True)
-- # Review output, then re-run with dry_run=False to execute
