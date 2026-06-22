# Large-Scale ClickHouse Table Migration Using cityHash64 Partitioning

## Problem

When migrating large tables in ClickHouse (100M+ records), a standard INSERT INTO SELECT statement fails with a memory overflow error (Code 241: Memory limit exceeded).

This was encountered when migrating two production-scale tables:
- Large consumer table: 721,141,364 records
- Large enrichment table: 330,442,651 records

## Root Cause

ClickHouse loads the entire result set into memory before writing. On tables with hundreds of millions of rows, this exceeds the available memory budget and causes the query to be killed.

## Solution

Split the table into equal batches using cityHash64 on the primary key, then insert each batch separately with a memory cap.

## How cityHash64 Works

cityHash64 is a fast, deterministic hash function built into ClickHouse. When applied to a record unique identifier, it returns a consistent 64-bit integer.

Key properties:
- Deterministic: same input always produces same output
- Even distribution: records spread evenly across hash values
- Built-in: no external dependencies required

Each batch is selected using the modulo operator:

    SELECT * FROM source_table
    WHERE cityHash64(toString(id)) % 20 = i

Because the hash is deterministic, every record falls into exactly one batch.

## Implementation

    import time
    NUM_BATCHES = 20
    for i in range(NUM_BATCHES):
        query = (
            "INSERT INTO target_db.target_table "
            "SELECT * FROM source_db.source_table "
            "WHERE cityHash64(toString(id)) % "
            + str(NUM_BATCHES) + " = " + str(i)
        )
        client.command(query, settings={"max_memory_usage": "4000000000"})
        print("Batch " + str(i+1) + " completed")
        time.sleep(2)

## Parameters

| Parameter | Value | Reason |
|-----------|-------|--------|
| Number of batches | 20 | Splits 700M+ records into ~35M per batch |
| max_memory_usage | 4GB | Prevents memory overflow error Code 241 |
| sleep between batches | 2 seconds | Allows ClickHouse to release memory |
| Hash column | Primary key UUID | Ensures even distribution |

## Results

| Table | Records | Batches | Result |
|-------|---------|---------|--------|
| Large consumer table | 721,141,364 | 20 | Success |
| Large enrichment table | 330,442,651 | 20 | Success |

## Verification

After migration, always verify record counts match exactly:

    SELECT 'source' AS db, count() AS cnt FROM source_db.source_table
    UNION ALL
    SELECT 'target' AS db, count() AS cnt FROM target_db.target_table

Expected: both counts identical.

## When To Use This Pattern

Use cityHash64 batching when:
- Table has 100M+ records
- Standard INSERT INTO SELECT fails with Code 241
- Table has a UUID or integer primary key

Do NOT use when:
- Table has no unique identifier
- Records must be migrated in a specific order
- Table is small enough to fit in memory

## Key Lesson

Standard SQL migration patterns break at production scale. The cityHash64 pattern is deterministic, parallelizable, and requires zero infrastructure changes.

## Environment

- Database: ClickHouse Cloud
- Client: clickhouse-connect Python
- Tested on: tables up to 721M records
