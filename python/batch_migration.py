"""
Hash-based batch migration orchestration.

Migrates a large table (~330M rows) between ClickHouse
environments by splitting it into N deterministic batches
using cityHash64() on the primary key. This avoids exceeding
ClickHouse's memory limits on a single INSERT ... SELECT *.

See sql/large_table_migration.sql for the underlying query
and validation pattern.
"""

import time

TOTAL_BATCHES = 10


def migrate_table(client, source_table, target_table, primary_key, total_batches=TOTAL_BATCHES):
    """
    Migrate a table in N batches using cityHash64-based partitioning.

    Each batch is deterministic and non-overlapping, so the
    full set of batches covers every row exactly once.
    """
    for i in range(total_batches):
        query = f"""
            INSERT INTO {target_table}
            SELECT * FROM {source_table}
            WHERE cityHash64(toString({primary_key})) % {total_batches} = {i}
        """
        client.command(query, settings={"max_memory_usage": "4000000000"})
        print(f"Batch {i + 1}/{total_batches} complete")
        time.sleep(2)  # brief pause between batches


def validate_migration(client, source_table, target_table, primary_key):
    """
    Confirm zero data loss and zero duplication after migration.
    """
    source_count = client.command(f"SELECT count() FROM {source_table}")
    target_count = client.command(f"SELECT count() FROM {target_table}")
    duplicates = client.command(
        f"SELECT count() - uniqExact({primary_key}) FROM {target_table}"
    )

    print(f"Source row count: {source_count}")
    print(f"Target row count: {target_count}")
    print(f"Duplicates in target: {duplicates}")

    assert source_count == target_count, "Row count mismatch -- migration incomplete"
    assert duplicates == 0, "Duplicate rows found in target table"
    print("Validation passed: zero loss, zero duplication.")


if __name__ == "__main__":
    # Example usage (client setup omitted)
    #
    # client = clickhouse_connect.get_client(...)
    # migrate_table(client, "source_db.large_table", "target_db.large_table", "primary_key")
    # validate_migration(client, "source_db.large_table", "target_db.large_table", "primary_key")
    pass
