# Data Quality & Business Impact Analysis on 2.7B+ Records

A data engineering portfolio project covering large-scale data profiling, cleaning, enrichment validation, and business impact reporting across multiple marketing databases.

## Highlights

- **2.7B+ records** profiled across 14 datasets in ClickHouse Cloud and PostgreSQL
- **51.4M duplicate identity records** identified, with quantified campaign cost impact
- **59.5M placeholder phone values** removed from an enrichment reference table, eliminating false-positive JOIN matches
- **330M-row table migrated** between environments with zero data loss using hash-based batch partitioning
- **50-state enrichment validation framework** built on a hashed JOIN key, with match rates ranging 0.03%-58%

> **A note on anonymization:** All business names, table names, column names, identifiers, and data samples in this repository have been anonymized or generalized. The metrics, methodologies, queries, and findings reflect real analyses performed on production-scale datasets as part of a data engineering role — no proprietary business data, credentials, or company-identifying information is included.

---

## Project Overview

This project involved profiling, cleaning, and assessing the business impact of **14 datasets totaling approximately 2.7 billion records** across ClickHouse Cloud and PostgreSQL. The goal was to identify large-scale data quality issues, quantify their business impact, execute production-safe cleaning operations, and build a validated enrichment pipeline.

### My Role
- Profiled 14 production-scale datasets (~2.7B rows) in ClickHouse Cloud and PostgreSQL
- Built a systematic column-level quality assessment framework (7-question checklist per column)
- Executed ClickHouse cleaning mutations across multiple tables, with pre/post validation
- Investigated structural constraints (ORDER BY key limitations) and documented remediation paths
- Built and validated a cross-table enrichment JOIN framework across all 50 US states
- Migrated a 330M-row table using hash-based batch migration to avoid memory overflow
- Produced a business impact assessment and engineering remediation roadmap


---

## Key Findings

| Finding | Scale | Business Impact |
|---|---|---|
| Duplicate identity records | 51.4M | Inflated campaign costs, unreliable conversion metrics |
| Placeholder date-of-birth values (Unix epoch default) | 77-92% across multiple tables | Age-based segmentation blocked for hundreds of millions of records |
| Integer overflow in numeric fields (phone, income, revenue) | Tens of millions of records | Corrupted segmentation filters, inflated coverage metrics |
| Placeholder phone values in enrichment table | 59.5M | False-positive JOIN matches corrupting enrichment output |
| ORDER BY key constraints (ClickHouse) | Multiple tables | Critical columns (city, state, DOB, coordinates) cannot be cleaned without full table recreation |
| Empty sales/revenue tracking table | 1 table, 0 records | Campaign ROI cannot be measured at all |

---

## Engineering Highlights

**Large-scale table migration.** Migrated a ~330M row ClickHouse table between environments without exceeding memory limits by using deterministic hash-based partitioning. Rows were distributed into 10 balanced batches using `cityHash64(primary_key) % N`, ensuring zero duplication and zero data loss. Validation checks confirmed record counts and uniqueness after migration. See [`sql/large_table_migration.sql`](sql/large_table_migration.sql) and [`python/batch_migration.py`](python/batch_migration.py).

---

## Enrichment Match Rate Analysis

Built a cross-table enrichment pipeline using a hashed JOIN key (`first_name_norm + last_name_norm + zip_norm`), validated across all 50 US states.

| Join | Avg Match Rate | Best States | Worst States |
|---|---|---|---|
| Phone dataset × Enrichment reference | 12.63% | DE 34%, AR 34%, MD 32% | UT 0.3%, NM 1.1% |
| Email dataset × Enrichment reference | 8.55% | KS 26%, MD 25%, DE 18% | WI 0.03%, CA 0.1% |
| Postal dataset × Enrichment reference | 19.0% | NC 58%, HI 49%, NJ 48% | Military codes 0% |

At a 19% national match rate, the postal dataset (266M records) would yield an estimated **~50M enriched consumer profiles** with income, net worth, and credit signals.

---

## Repository Structure

```
data-quality-business-impact/
├── README.md
├── reports/
│   └── business_impact_report.md       — Full business impact assessment
├── sql/
│   ├── profiling_examples.sql           — 7-question column profiling framework
│   ├── duplicate_detection.sql          — Identity duplicate detection queries
│   ├── cleaning_mutations.sql           — Example cleaning mutations with validation
│   ├── enrichment_examples.sql          — Cross-table enrichment JOIN logic
│   └── large_table_migration.sql        — Hash-based batch migration pattern
├── python/
│   └── batch_migration.py               — Orchestration script for batch migration
└── lessons_learned.md                   — Key technical lessons from this project
```

---

## Technologies

- **ClickHouse Cloud** (SharedMergeTree, distributed analytical queries on 700M+ row tables)
- **PostgreSQL** (Neon)
- **Python** — clickhouse-connect, psycopg2, pandas
- **Jupyter Notebook** (Anaconda)
- SQL — profiling, mutations, hash-based JOINs, materialized columns

---

## Lessons Learned (Summary)

- **Scale does not equal quality.** Tables with hundreds of millions of records can be largely unusable for specific use cases — 92% placeholder date-of-birth values being the clearest example.
- **Placeholder values silently corrupt downstream decisions.** Values like `1970-01-01`, `0000000000`, and `2147483647` pass format validation but corrupt segmentation, filtering, and JOIN logic in ways invisible without systematic profiling.
- **Platform constraints determine remediation strategy.** ClickHouse's ORDER BY key limitations mean some issues cannot be resolved via standard mutations — they require full table recreation. Understanding this early prevents misdirected engineering effort.

See [`lessons_learned.md`](lessons_learned.md) for the full technical write-up.

---

## Contact

**Gulnara** — Data Analyst / Data Engineer

- GitHub: [github.com/gulnaraakurbanova](https://github.com/gulnaraakurbanova)
- LinkedIn: [linkedin.com/in/gulnara-kurbanova-921a251a1](https://www.linkedin.com/in/gulnara-kurbanova-921a251a1)
- Email: gulnaraakurbanova@gmail.com
