# Lessons Learned

Eight technical lessons from profiling, cleaning, and enriching ~2.7 billion records across 14 datasets in ClickHouse Cloud and PostgreSQL.

---

## 1. ORDER BY key — check this first, always

In ClickHouse, the `ORDER BY` clause defines the table's primary index. Columns in this key **cannot be modified via `ALTER TABLE UPDATE`** — attempting to do so fails with `CANNOT_UPDATE_COLUMN`.

This constraint should be checked *before* planning any cleanup, not discovered halfway through. In this project, several high-impact issues (corrupted state codes, header-leak values in city fields, placeholder coordinates, fake dates of birth) were all located in ORDER BY key columns — meaning the only remediation path is full table recreation with a corrected schema.

```sql
SELECT name, is_in_sorting_key
FROM system.columns
WHERE table = 'your_table'
  AND is_in_sorting_key = 1;
```

---

## 2. Integer overflow hides in plain sight

`Int32` has a maximum value of `2,147,483,647`. When a numeric field overflows this limit (or when a system writes this exact value as a fallback), it silently appears as valid data — passing every format check.

This was found in phone number fields, household income fields, company revenue fields, and employee count fields — tens of millions of records across multiple tables. Each one corrupted a different downstream metric: phone coverage looked higher than it was, "high income" segments were inflated with garbage values, and revenue-based company segmentation was distorted.

**Rule of thumb:** any numeric column used for segmentation should be checked against `2147483647` (and `-2147483648`) before being trusted.

---

## 3. 1970-01-01 lives in every DATE column

Unix epoch (`1970-01-01`) is the default value many systems fall back to when a date is unknown. It passes as a perfectly valid date — format checks won't catch it.

Across this project, date-of-birth fields showed fake `1970-01-01` values in **77% to 92%** of records depending on the table. This single placeholder value blocked all age-based demographic segmentation for hundreds of millions of records.

`NULL` is a more honest representation than `1970-01-01` — it explicitly signals "unknown" rather than implying "born in 1970."

```sql
SELECT round(countIf(date_of_birth = '1970-01-01') * 100.0 / count(), 2) AS fake_pct
FROM your_table;
```

---

## 4. Header leaks — the silent corruptor

During ETL loading, a column's header name can sometimes end up inserted as a literal data value in one or more rows (e.g. a row where the `city` column literally contains the string `"city"` or `"CITY"`).

These rows pass every format check — they're valid strings — but they corrupt filters and aggregations. A query like `WHERE city = 'New York'` won't catch them, but a query counting distinct city values will show `"city"` as if it were a real city with thousands of "residents."

```sql
SELECT count() FROM your_table WHERE lower(column_name) = 'column_name';
```

---

## 5. Large table migration — hash-based batching

Copying a 330M-row table in a single `INSERT ... SELECT *` will exceed ClickHouse's memory limits (`Code: 241 — memory limit exceeded`).

The fix: split the source into N batches using `cityHash64(toString(id)) % N`, then insert each batch separately. Because the hash function is deterministic, every row is migrated exactly once — guaranteed zero duplication and zero gaps, verified by comparing row counts before and after.

```sql
INSERT INTO target.table
SELECT * FROM source.table
WHERE cityHash64(toString(id)) % 10 = 0
SETTINGS max_memory_usage = 4000000000;
```

Use a hash function rather than `id % N` directly — raw IDs are often sequential or clustered, which can produce wildly uneven batch sizes.

---

## 6. Mutations are asynchronous — learn to wait

`ALTER TABLE ... UPDATE/DELETE` in ClickHouse does not execute synchronously. It queues as a **mutation** and runs in the background. Querying immediately after issuing a mutation may show stale data, and starting a new mutation before the previous one finishes can cause conflicts or unexpected ordering of changes.

```sql
SELECT count() FROM system.mutations
WHERE is_done = 0 AND database = 'your_db';
```

Poll this until it returns `0` before proceeding to the next cleaning step.

---

## 7. Compliance flags are legal requirements, not optional fields

Fields like `DNC` (Do Not Contact), `DONOTCALL`, and `DNF` (Do Not Fax) aren't just data quality signals — they're legal obligations. In the US, ignoring a `DONOTCALL` flag on a phone campaign can violate the Telephone Consumer Protection Act (TCPA), with penalties of **$500–$1,500 per violation**.

Every campaign-readiness query should include compliance filtering as a non-negotiable first step:

```sql
WHERE DONOTCALL = 'False' AND DNC = ''
```

---

## 8. Technical findings need a business translation

"There are 51.4 million duplicate identity records" is a true statement, but it doesn't tell anyone what to do about it.

"These duplicates cause the same person to receive the same email twice, inflating campaign costs by an estimated 2x, depressing measured open rates by inflating the denominator, and increasing spam complaint rates that damage sender reputation for future campaigns" — *that* is something a stakeholder can act on.

The pattern that proved most useful throughout this project:

> **What is the issue? → Why did it happen? → What breaks if it's not fixed? → What's gained if it is fixed?**

Every finding in the [business impact report](reports/business_impact_report.md) follows this structure. It's the difference between a data quality checklist and a document that drives engineering prioritization.
