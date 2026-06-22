
-- ================================================
-- ClickHouse Large Table Enrichment Using Join Engine
-- Pattern: JOIN + UPDATE on 459M record table
-- Problem: ClickHouse does not support UPDATE ... JOIN syntax
-- Solution: Join table engine + joinGet() function
-- ================================================

-- BACKGROUND
-- Standard SQL UPDATE with JOIN does not work in ClickHouse:
-- UPDATE big_table SET col = small_table.col FROM small_table WHERE ...
-- This throws a syntax error.
-- Solution: Create a Join engine table, then use joinGet() in mutation.

-- STEP 1: Add new columns to the large table
-- These columns will store the verified/enriched data
ALTER TABLE target_database.large_table
ADD COLUMN IF NOT EXISTS verified_name String DEFAULT '',
ADD COLUMN IF NOT EXISTS verified_city String DEFAULT '',
ADD COLUMN IF NOT EXISTS verified_phone String DEFAULT '',
ADD COLUMN IF NOT EXISTS is_verified UInt8 DEFAULT 0,
ADD COLUMN IF NOT EXISTS confidence_score Float32 DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_verified_at Nullable(DateTime) DEFAULT NULL;

-- STEP 2: Create a Join engine table from the small verified dataset
-- Join engine stores data in memory for fast key-based lookup
-- Syntax: Join(strictness, join_type, key_column)
CREATE TABLE IF NOT EXISTS target_database.verified_join
(
    lookup_key String,
    verified_name String,
    verified_city String,
    verified_phone String,
    is_verified UInt8,
    confidence_score Float32,
    last_verified_at DateTime
)
ENGINE = Join(ANY, LEFT, lookup_key);

-- STEP 3: Populate the Join table from verified data source
-- Only include records with sufficient confidence
INSERT INTO target_database.verified_join
SELECT
    domain AS lookup_key,
    normalized_name,
    city,
    phone,
    mx_valid,
    confidence_score,
    last_verified_at
FROM target_database.small_verified_table
WHERE confidence_score >= 0.5
AND domain != '';

-- STEP 4: Update the large table using joinGet()
-- joinGet('join_table', 'column_to_get', key_value)
-- This is the only way to do a JOIN-based UPDATE in ClickHouse
ALTER TABLE target_database.large_table
UPDATE
    verified_name = joinGet('target_database.verified_join', 'verified_name', lookup_column),
    verified_city = joinGet('target_database.verified_join', 'verified_city', lookup_column),
    verified_phone = joinGet('target_database.verified_join', 'verified_phone', lookup_column),
    is_verified = joinGet('target_database.verified_join', 'is_verified', lookup_column),
    confidence_score = joinGet('target_database.verified_join', 'confidence_score', lookup_column),
    last_verified_at = joinGet('target_database.verified_join', 'last_verified_at', lookup_column)
WHERE lookup_column IN (SELECT lookup_key FROM target_database.verified_join);

-- STEP 5: Create filter views for different use cases
-- View 1: Records with valid mail server
CREATE OR REPLACE VIEW target_database.verified_mail_server AS
SELECT * FROM target_database.large_table
WHERE is_verified = 1;

-- View 2: Records with high confidence score
CREATE OR REPLACE VIEW target_database.verified_high_confidence AS
SELECT * FROM target_database.large_table
WHERE verified_name != ''
AND confidence_score >= 0.8;

-- View 3: Premium segment (all filters combined)
CREATE OR REPLACE VIEW target_database.verified_premium AS
SELECT * FROM target_database.large_table
WHERE is_verified = 1
AND confidence_score >= 0.8
AND last_verified_at >= now() - INTERVAL 90 DAY;

-- STEP 6: Verify results
SELECT
    countIf(verified_name != '') AS has_verified_name,
    countIf(is_verified = 1) AS is_verified_count,
    countIf(confidence_score >= 0.8) AS high_confidence
FROM target_database.large_table;
