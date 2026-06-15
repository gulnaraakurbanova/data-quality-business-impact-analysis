-- ============================================================
-- DATA PROFILING FRAMEWORK
-- 7-question checklist applied to every column before cleaning
-- Table/column names are generic examples — pattern is what matters
-- ============================================================

-- Applied to every numeric/string/date column across 14 tables (~2.7B rows)
-- before any cleaning mutation was written.

-- ------------------------------------------------------------
-- 1. EMPTY VALUES
-- ------------------------------------------------------------
SELECT
    count() AS total_rows,
    countIf(phone_number = '')  AS empty_phone,
    round(countIf(phone_number = '') * 100.0 / count(), 2) AS empty_phone_pct
FROM consumer_email_dataset;


-- ------------------------------------------------------------
-- 2. FORMAT CHECK (length, regex match)
-- ------------------------------------------------------------
-- Phone numbers should be exactly 10 digits
SELECT
    count() AS invalid_format_count
FROM consumer_email_dataset
WHERE phone_number != ''
  AND length(phone_number) != 10;

-- SIC industry codes should be exactly 4 digits
SELECT count() AS invalid_sic
FROM business_contacts_dataset
WHERE sic_code != ''
  AND NOT match(sic_code, '^[0-9]{4}$');


-- ------------------------------------------------------------
-- 3. MIN/MAX SANITY CHECK
-- ------------------------------------------------------------
-- Geographic coordinates must be within valid Earth ranges
SELECT
    min(latitude)  AS min_lat,
    max(latitude)  AS max_lat,
    min(longitude) AS min_lon,
    max(longitude) AS max_lon
FROM consumer_phone_dataset;

-- Anything outside -90/90 (lat) or -180/180 (lon) is invalid
SELECT count() FROM consumer_phone_dataset
WHERE latitude  NOT BETWEEN -90  AND 90
   OR longitude NOT BETWEEN -180 AND 180;


-- ------------------------------------------------------------
-- 4. FAKE / PLACEHOLDER VALUE DETECTION
-- ------------------------------------------------------------
-- Unix epoch default date — extremely common placeholder for "unknown DOB"
SELECT
    countIf(date_of_birth = '1970-01-01') AS fake_dob,
    round(countIf(date_of_birth = '1970-01-01') * 100.0 / count(), 2) AS fake_dob_pct
FROM consumer_email_dataset;

-- Integer overflow placeholder (Int32 max value)
SELECT count() FROM business_contacts_dataset
WHERE annual_revenue = 2147483647
   OR employee_count  = 2147483647;

-- Placeholder phone number used when phone is unknown
SELECT count() FROM enrichment_reference_dataset
WHERE phone_number = '0000000000';


-- ------------------------------------------------------------
-- 5. NEGATIVE VALUES (where they should not exist)
-- ------------------------------------------------------------
SELECT count() FROM enrichment_reference_dataset
WHERE latitude < 0;


-- ------------------------------------------------------------
-- 6. FUTURE DATES
-- ------------------------------------------------------------
SELECT count() FROM consumer_email_dataset
WHERE registration_date > today();


-- ------------------------------------------------------------
-- 7. HEADER LEAK DETECTION
-- ------------------------------------------------------------
-- During ETL loading, a column header can end up as a data row
-- e.g. the literal string "city" appears where a real city name should be
SELECT count() FROM consumer_email_dataset
WHERE lower(city) = 'city';

SELECT count() FROM enrichment_reference_dataset
WHERE upper(net_worth_segment) = 'NET_WORTH';


-- ============================================================
-- SOURCE QUALITY COMPARISON
-- Compare data completeness across different vendor sources
-- ============================================================
SELECT
    source,
    count() AS total_records,
    round(countIf(phone_number != '') * 100.0 / count(), 2)   AS phone_fill_pct,
    round(countIf(company_name  != '') * 100.0 / count(), 2)  AS company_name_fill_pct,
    round(countIf(industry      != '') * 100.0 / count(), 2)  AS industry_fill_pct
FROM business_contacts_supplemental
GROUP BY source
ORDER BY total_records DESC;
