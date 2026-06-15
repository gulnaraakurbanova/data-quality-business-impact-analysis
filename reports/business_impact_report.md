# Business Impact Report
## Data Quality Engineering — Marketing Data Platform
**Author:** Gulnara | **Date:** May-June 2026
**Environment:** ClickHouse Cloud (sandbox_db) · PostgreSQL (Neon)

---

## My Role

- Profiled 14 production-scale datasets (~2.70B rows) in ClickHouse Cloud and PostgreSQL
- Built an automated column-level quality assessment framework (`functions.py`)
- Executed ClickHouse cleaning mutations on 6 tables and validated all changes
- Investigated structural constraints (ORDER BY key limitations) and documented remediation paths
- Built and validated cross-table enrichment JOIN framework across 50 US states
- Produced this business impact assessment and engineering remediation roadmap

---

## Why This Project Matters

The company operates as a data-driven marketing business. The company's revenue depends on the quality, reachability, and segmentation capability of its contact databases. Poor data quality does not just create technical problems — it directly reduces campaign efficiency, inflates operational costs, and limits the revenue-generating potential of the data assets the business is built on.

This project focused on identifying quality issues that reduce campaign efficiency, block demographic segmentation, and distort performance measurement — and translating those findings into actionable business impact and remediation priorities.

---

## Executive Summary

This report presents a business-oriented analysis of the company's marketing data infrastructure — covering data quality assessment, cleaning, enrichment validation, and remediation recommendations across 14 tables and approximately **2.70 billion records**.

**Total Addressable Marketing Universe**
- Email: ~970M marketable records (consumer + cache, pre-deduplication)
- Phone: ~620M records (cells + consumer + biz combined)
- Postal: ~266M records (postal_consumer_dataset)
- B2B email + phone: 361M records (business_contacts_dataset)
- B2B executive segment: 425K C-Level contacts (email + phone verified)

**Top 3 Risks Requiring Immediate Action**
1. **51.4M duplicate UUIDs** across consumer tables — inflating campaign costs and invalidating ROI metrics
2. **77–92% fake DOB** across consumer and enrichment tables — blocking age-based segmentation for hundreds of millions of records
3. **ORDER BY key constraints** — critical columns (city, state, DOB) cannot be cleaned without full table recreation

**Key Engineering Contributions**
- Profiled 13 tables (~2.37B rows) using a systematic 7-question column-level checklist
- Executed production cleaning mutations across 7 tables
- Removed/corrected millions of invalid, placeholder, and overflow records
- Identified 51.4M duplicate UUIDs across consumer assets
- Cleaned 59.5M placeholder phone values (0000000000) from enrichment reference table
- Built and validated cross-table enrichment JOIN framework
- Measured enrichment match rates across all 50 US states for 3 table combinations
- Produced business impact assessment and remediation roadmap

---

## 1. Business Data Model

Understanding how data generates revenue at the company:

```
Raw Data Ingestion
(consumer, biz, phone, postal, fax)
        ↓
Data Cleaning & Profiling
(remove placeholders, fix formats, validate coverage)
        ↓
Enrichment
(JOIN with enrichment_reference_dataset → add net worth, credit rating, lifestyle signals)
        ↓
Segmentation
(age, geography, homeownership, seniority, industry)
        ↓
Campaign Execution
(email, phone, SMS, fax, direct mail)
        ↓
Revenue Generation
```

**How data quality issues break this chain:**

```
Duplicate UUID
    ↓
Duplicate sends to same contact
    ↓
Inflated campaign cost + spam complaints
    ↓
Lower deliverability + distorted conversion metrics
    ↓
ROI measurement becomes unreliable
```

```
Fake DOB (1970-01-01)
    ↓
Age segment = unknown for 77-92% of records
    ↓
Age-based campaigns (senior, millennial, Gen-X) cannot execute reliably
    ↓
Demographic segmentation value of the database is significantly reduced
```

```
ORDER BY key constraint
    ↓
City / state / DOB columns cannot be updated
    ↓
Geographic and demographic segmentation returns incorrect results
    ↓
Requires full table recreation to resolve
```

---

## 2. Database Overview

| Table | Rows | Channel | Environment |
|-------|------|---------|-------------|
| consumer_email_dataset | 714,937,704 | Email (B2C) | ClickHouse |
| business_contacts_dataset | 459,194,047 | Email + Phone (B2B) | ClickHouse |
| postal_consumer_dataset | 266,743,979 | Postal (B2C) | ClickHouse |
| consumer_phone_dataset | 260,170,003 | Phone (B2C) | ClickHouse |
| consumer_phone_dataset_v0 | 258,506,950 | Phone (B2C) | ClickHouse |
| consumer_email_supplemental | 255,209,715 | Email (B2C) | ClickHouse |
| enrichment_reference_dataset | 109,987,623 | Enrichment reference | ClickHouse |
| b2b_seniority_dataset | 44,027,457 | Email + Phone (B2B) | ClickHouse |
| business_contacts_supplemental | 330,442,651 | Email + Phone (B2B) | ClickHouse |
| fax_dataset_a | 3,813,995 | Fax (B2B) | ClickHouse |
| fax_dataset_b | 3,261,843 | Fax (B2B) | ClickHouse |
| enrichment_pilot_dataset | 398,969 | Enrichment test | ClickHouse |
| platform_customers | 3,601 | Platform CRM | PostgreSQL |
| platform_sales | 0 | Platform CRM | PostgreSQL |
| **TOTAL** | **~2.70 billion** | | |

---

## 3. Asset Groups

---

### 3.1 Consumer Email Assets
**Tables:** consumer_email_dataset · consumer_email_supplemental
**Priority:** High — primary revenue-generating channel

**Business Value**
Consumer email is the primary outreach channel for B2C acquisition, retention, and re-engagement campaigns. These two tables form the largest email asset in the database.

- Combined marketable email: **~970M records**
- Dual-channel (email + phone): **~457M records**
- Home owners: 329M — valuable for mortgage, insurance, solar, home-improvement
- Top states: CA, FL, TX, NY, IL, PA, OH, MI, GA, NJ

**Risks & So What?**

| Risk | So What? |
|------|----------|
| 51.4M duplicate UUIDs (consumer + cache) | Campaign volume is artificially inflated. The same contacts receive multiple sends, increasing costs and triggering spam complaints. Conversion rates appear lower than actual because the denominator is inflated. |
| DOB 77.7% fake (consumer), 72% (cache) | Age-based segmentation cannot be applied to the majority of records. Senior, millennial, and Gen-X targeting campaigns lose most of their addressable audience. |
| state: numeric codes in ORDER BY key | State-level filtering returns wrong results for affected records. Regional campaigns in top states (CA, TX, FL) may include or exclude incorrect contacts. Cannot be fixed without table recreation. |
| sourced_at / last_verified_at: 100% fake in cache | Record freshness is unknown. Inactive or bounced emails cannot be suppressed by date — increasing bounce rates and damaging sender reputation over time. |
| interest_ids / main_interest / sub_interest: 100% empty | Interest-based and behavioral targeting are completely unavailable. Personalization at the interest level is not possible with current data. |

**Opportunity**
~970M marketable email records is one of the largest consumer email assets profiled. After deduplication and enrichment JOIN, matched records gain net worth, credit rating, and 300+ lifestyle attributes — enabling premium-offer segmentation at scale.

**Engineering Actions**
- Removed numeric fake first/last names — ensures name-based personalization and JOIN keys are not corrupted
- Removed invalid phone numbers (non-10-digit) — prevents invalid numbers from inflating outbound dialing volume and reducing contact rates
- Removed numeric-only short address values — prevents placeholder data from distorting address-based matching
- Removed fake county values (-, NA, null, NULL) — enables reliable county-level geographic segmentation
- Removed future registration dates — prevents incorrect recency filtering from including invalid records in lifecycle campaigns
- Cleaned fake DOB (1970-01-01) → NULL in cache — marks unknown birth dates explicitly rather than allowing 1970 to corrupt age-based filters
- Cleaned gender and ownrent garbage values in cache — restores reliable demographic segmentation on these fields
- Cleaned address header leaks in cache — removes ETL artifacts that corrupt address-based filtering
- Validated all mutations via post-mutation row counts — confirms cleaning did not remove valid records

---

### 3.2 B2B Assets
**Tables:** business_contacts_dataset · b2b_seniority_dataset
**Priority:** High — direct B2B revenue channel

#### A. Broad Business Universe — business_contacts_dataset

**Business Value**
Largest B2B email + phone asset in the database. Supports outbound sales, lead generation, and account-based marketing at scale. 100% email coverage, zero DNC suppression required.

- Total: 459,194,047 records
- Email + phone: **361,559,340** — all marketable, no DNC
- Mid-market ($1M-$100M revenue): ~87M records

**Risks & So What?**

| Risk | So What? |
|------|----------|
| Revenue unknown: 58.4% | Mid-market and enterprise segmentation can only be applied to 41.6% of the database. Revenue-based audience building is severely limited. |
| sic_code invalid: 551,868 records | Industry-targeted campaigns will include or misclassify wrong businesses. Outreach budget is wasted on incorrectly segmented contacts. |

**Engineering Actions**
- Removed revenue overflow values (>1 trillion) — prevents extreme outliers from distorting revenue-based segment filters
- Removed placeholder revenue values (=1): 1,076,671 records — eliminates false signals in mid-market and SMB segmentation
- Removed employee overflow values (>1 million): 950,113 records — restores accurate company size segmentation
- Prepared sic_code dry run mutation — ready for production promotion to enable reliable industry-based targeting ⚠️

---

#### B. Executive Decision Maker Segment — b2b_seniority_dataset

**Business Value**
Premium B2B segment with verified professional seniority. Enables enterprise sales, executive outreach, and high-value account-based marketing.

- C-Level with email + phone: **425,674**
- VP: 314,000 | Director: 615,945 | Manager: 1,401,143
- Top industries: Financial Services, Law Practice, Real Estate
- Microsoft365 ESP: 14.23% — corporate email infrastructure

**Risks & So What?**

| Risk | So What? |
|------|----------|
| zip = '00000': 19.8M records (45%) | Geographic targeting, territory assignment, and state-level segmentation are unavailable for nearly half the database. Regional campaign coverage is significantly reduced. |
| title_level = LinkedIn URL: 354,771 records (cleaned) | Before cleaning, seniority filters were returning incorrect segment sizes. C-Level campaigns may have included or excluded wrong contacts. |

**Engineering Actions**
- Removed title_level URL artifacts (354,771 records) — restores accurate seniority-level filtering for C-Level and VP segment targeting
- Removed invalid linkedin_url values (154,548 records) — ensures URL field contains only usable profile links
- Cleaned numeric county_name values (9,134 records) — enables reliable county-level geographic segmentation
- Cleaned non-numeric sic_code values — restores industry classification for affected records

---

#### C. B2B Cache Asset — business_contacts_supplemental

**Business Value**
B2B email and phone marketing database sourced from multiple vendors. Supports outbound sales, lead generation, and account-based marketing across all major US industries. Complements business_contacts_dataset with additional sources and minimal overlap.

- Total: 330,442,651 records
- Email coverage: ~100% (330,442,639)
- Phone coverage: 65.51% (216,470,985)
- DNC: 0 flagged — no suppression required
- MX deliverable (MXCheck=1): 92.29%
- Microsoft365 dominant ESP: 88.7M records
- Enterprise segment (Over 1B + 1000+ employees): 25.6M records
- Top industries: Education, Retail, Business Services, Healthcare, Manufacturing

**Risks & So What?**

| Risk | So What? |
|------|----------|
| Kyle130MLI: 0% company_name (45.6M records) | Firmographic matching and company-level personalization are not possible for 13.8% of the database. Outreach to these records must be generic — reducing response rates for campaigns that rely on company-level targeting. |
| Revenue unknown: 58.1% | Mid-market and enterprise segmentation can only be applied to 41.9% of records. Revenue-based audience building is significantly limited. |
| sourced_at / last_verified_at: 100% fake | Record freshness cannot be determined. Recency-based suppression and lifecycle filtering are not possible — increasing risk of contacting stale records. |
| MXCheck=6: 7.70% (25.4M records) | Potential deliverability issues for 25.4M records. If included in campaigns without filtering, bounce rates may increase and sender reputation may be damaged. |
| UUID anomaly (negative duplicate count) | Data integrity cannot be fully confirmed until the anomaly is investigated. Cross-table deduplication results may be unreliable. |

**Opportunity**
- Low overlap with business_contacts_dataset (~0.57%) suggests a substantially expanded addressable B2B market when both datasets are combined
- Enterprise segment (25.6M records) represents high-value prospects for enterprise sales and ABM campaigns
- Microsoft365 dominance indicates strong corporate email deliverability across the dataset

**Engineering Actions**
- Migrated 330M records from source_db using hash-based batch migration — zero duplication confirmed
- Removed phone_number integer overflow (2,147,483,647): 47.2M records — restores accurate phone coverage metrics
- Removed revenue and employee overflow values — restores reliable company size and revenue segmentation
- Removed fake company_name, first_name, last_name, title values — improves personalization accuracy
- Removed phone numbers stored in contact_name and address fields — eliminates data type mismatches
- Removed DNC garbage value — restores compliance field integrity
- Validated all mutations via post-mutation row counts — ALL CLEAN

---

### 3.3 Phone Assets
**Tables:** consumer_phone_dataset · consumer_phone_dataset_v0
**Priority:** Medium-High — primary SMS and call channel

**Business Value**
Most complete phone coverage in the database. Supports SMS campaigns, outbound call programs, and carrier-based segmentation.

- consumer_phone_dataset: 260M records, phone ~100%
- Email + phone combined: ~18.5M records
- Top carriers: Verizon 23%, AT&T 20.5%, Sprint 12%

**Risks & So What?**

| Risk | So What? |
|------|----------|
| Longitude max: 2011.0 (impossible) | Geo-fenced SMS and location-based campaigns will misdirect or fail for affected records. Geographic targeting cannot be trusted without coordinate validation. |
| hhincome overflow (2,147,483,647) | Income-based audience segmentation is corrupted. Overflow values appear as extreme high-income records, distorting every income bracket filter applied to this table. |
| 1.7M record gap vs. cells_old | A portion of the phone database may have been silently lost during the version update. Scope and business impact not yet confirmed. |

**Engineering Actions**
- Cleaned fake email values in both tables
- Cleaned invalid gender, fake ownrent, fake uploaded dates in both tables
- Cleaned placeholder name, address, city values in both tables
- Cleaned hhincome integer overflow (2,147,483,647 → 0) in both tables
- Cleaned invalid phone values in cells_old

---

### 3.4 Postal Asset
**Table:** postal_consumer_dataset
**Priority:** Medium — direct mail and demographic segmentation

**Business Value**
Acxiom-sourced postal database with strong property and financial signals. Primary asset for direct mail campaigns and home-ownership-based targeting.

- Total: 266,743,979 records
- Marketable (email + DONOTCALL=False): **48,420,437**
- Home owner probability: 68.1% H code — mortgage, insurance, solar targeting
- Highest enrichment match rate: avg 19.0% with enrichment_reference_dataset_v2015

**Risks & So What?**

| Risk | So What? |
|------|----------|
| Email coverage: 34.65% | 65% of the database cannot be reached via email. Without enrichment or postal outreach, most records are unreachable through digital channels. |
| DONOTCALL=True: 35.76% | Over one-third is suppressed for phone. Campaigns that bypass this flag risk regulatory violations and reputational damage. |

**Engineering Actions**
- DONOTCALL compliance flag verified and documented
- Enrichment JOIN tested across all 50 US states
- Match rates calculated for 3 table combinations

---

### 3.5 Enrichment Assets
**Tables:** enrichment_reference_dataset · enrichment_pilot_dataset
**Priority:** Medium — multiplier effect on all other assets

**Business Value**
Enrichment pipeline adds demographic, financial, and lifestyle attributes to marketing records. Without these assets, premium segmentation is not possible. With them, the entire database gains targeting depth.

Key attributes available: net worth · credit rating · credit card presence · home ownership · mortgage data · education · occupation · 200+ lifestyle interest flags

- enrichment_reference_dataset: 109,987,623 records, 351 columns
- Enriched test (WY): 158,518 matched records with full financial profile

**Risks & So What?**

| Risk | So What? |
|------|----------|
| DOB 92% fake — ORDER BY key | Age-based enrichment signals are unavailable for most records. Table recreation required before this constraint can be resolved. |
| PHONE = '0000000000': 59.5M (cleaned) | Before cleaning, phone JOINs returned false positive matches on placeholder values — corrupting enrichment output and producing incorrect demographic attributions. |
| Wyoming only in enriched_test | National enrichment pipeline has not been validated. Results from this test are not representative of full-scale performance. |

**Opportunity**
National rollout at 19% average match rate across 266M postal records yields an estimated **~50M enriched consumer profiles** with income, net worth, credit, and behavioral signals.

**Engineering Actions**
- Removed PHONE = '0000000000' (59,547,186 records) — eliminates placeholder values that were generating false positive matches in phone-based JOINs and corrupting enrichment output
- Removed header leaks in CITY, NET_WORTH, PHONE, ETHNIC_CODE — prevents column header values from being returned as data in segmentation queries
- Cleaned invalid ZIP5 format and negative LATITUDE values — restores geographic JOIN and filtering accuracy
- Deleted invalid GENDER rows and header leak rows — ensures demographic segmentation fields contain only valid values
- Built and validated enrichment JOIN on first_name_norm + last_name_norm + zip_norm — enables scalable cross-table demographic enrichment
- Measured enrichment match rates across all 50 US states for 3 table combinations — provides geographic targeting guidance for enrichment budget allocation

---

### 3.6 Fax Assets
**Tables:** fax_dataset_b · fax_dataset_a
**Priority:** Low-Medium — legacy B2B fax channel

**Business Value**
B2B fax outreach databases with national coverage. Usable for industry-targeted fax campaigns after quality filtering.

- Combined usable after Valid=1 + DNF=0: **~5.78M records**
- SIC-coded records: ~2.6M combined
- fax_dataset_b also has phone: ~1.13M records — enables fax + phone sequence

**Risks & So What?**

| Risk | So What? |
|------|----------|
| Validation age ~2019 (7 years) | Current fax deliverability is unknown. Actual usable universe is likely lower than the valid record count suggests. Campaign ROI cannot be predicted without re-validation. |
| Company_Name: 63-66% empty | Personalized fax campaigns are not possible for the majority of records. Generic outreach reduces response rates. |
| ETL hex artifacts in Company_Name | Affected records cannot be used in firmographic matching or display — a direct consequence of an unresolved ETL pipeline issue. |

**Engineering Actions**
- Identified and documented ETL hex artifacts and duplicate UUIDs (1,376 + 5,452)
- Documented DNF compliance flags and Valid=1 filter logic
- Documented impossible coordinate values (lat max: 196,400)

---

### 3.7 Platform Tables
**Tables:** platform_customers · platform_sales (PostgreSQL)
**Priority:** Low (current state)

**platform_customers** contains 3,601 records (3,590 active). All records share the same load timestamp (2026-01-20), indicating a test data load. Customer lifetime value, churn, and cohort analysis are not possible in the current state.

**platform_sales** contains no records. Campaign ROI analysis and revenue attribution cannot be performed until this table is populated. This is the most significant gap for data-driven marketing optimization.

---

## 4. System-Wide Risks

These risks affect multiple assets and require coordinated remediation:

**Risk 1: Identity Quality**
51.4M duplicate UUIDs across consumer and cache tables. Cross-table campaigns will contact the same individuals multiple times, inflating costs and distorting all performance metrics. A deduplication pipeline is required before any cross-table campaign execution.

**Risk 2: Demographic Quality**
Fake DOB (1970-01-01) affects 77-92% of records across consumer, cache, and enrichment tables. Age-based segmentation — a fundamental targeting dimension — is unavailable for the majority of the database. This is a system-wide issue, not isolated to one table.

**Risk 3: Geographic Quality**
Invalid ZIP codes (b2b_seniority_dataset: 45% = '00000'), corrupted coordinates (consumer_phone_dataset: lon max 2011.0, fax_dataset: lat max 196,400), and uncleaned state codes (consumer_email_dataset ORDER BY key) collectively limit geographic targeting across multiple assets.

**Risk 4: Structural Constraints**
ORDER BY key limitations in ClickHouse prevent direct UPDATE on city, state, and DOB columns in consumer_email_dataset and enrichment_reference_dataset. These constraints require full table recreation — a non-trivial engineering effort — before these fields can be corrected.

**Risk 5: Missing Revenue Attribution**
platform_sales is empty. Without sales transaction data, it is not possible to measure campaign ROI, attribute revenue to specific audience segments, or make data-driven optimization decisions. All marketing performance measurement is currently blind.

---

## 5. ROI Simulation

Estimated impact of resolving key issues — directional analysis, not financial projections:

**If duplicate UUIDs are removed (51.4M records):**
→ Campaign send volume is likely to decrease across consumer email assets — exact reduction depends on overlap rate between tables
→ Sending costs decrease proportionally
→ Conversion rate metrics become more accurate — current rates are artificially depressed by duplicate denominators
→ Spam complaint risk decreases

**If enrichment is expanded nationally (currently Wyoming only):**
→ At 19% average match rate across 266M postal records: estimated ~50M enriched profiles
→ Net worth, credit rating, and 300+ lifestyle signals become available for these records
→ Premium segmentation (high net worth, credit card holders, homeowners) becomes executable at national scale

**If ORDER BY constrained tables are rebuilt:**
→ Age-based segmentation becomes available for 600M+ consumer records
→ State-level filtering becomes reliable for geographic campaign targeting
→ DOB-based lifecycle segmentation (recency, age cohorts) becomes possible

**If platform_sales is populated:**
→ Campaign ROI can be measured per audience segment
→ Marketing spend optimization becomes data-driven
→ Conversion attribution becomes possible across all outreach channels

**If fax_dataset assets are re-validated:**
→ Actual usable fax universe becomes known (currently estimated at ~5.78M but unverified)
→ Campaign delivery rate predictions become reliable
→ Re-validation may identify a significant portion of records as inactive — allowing cost savings on non-deliverable contacts

---

## 6. Enrichment Match Rate Analysis

Cross-table enrichment tested using `first_name_norm + last_name_norm + zip_norm` JOIN keys:

| Join | Avg Match Rate | Best States | Worst States |
|------|---------------|-------------|-------------|
| consumer_phone_dataset × enrichment_reference_dataset | 12.63% | DE 34%, AR 34%, MD 32% | UT 0.3%, NM 1.1% |
| consumer_email_supplemental × enrichment_reference_dataset | 8.55% | KS 26%, MD 25%, DE 18% | WI 0.03%, CA 0.1% |
| postal_consumer_dataset × enrichment_reference_dataset_v2015 | 19.0% | NC 58%, HI 49%, NJ 48% | Military codes 0% |

Enrichment ROI is geographically uneven. NC, NJ, MD, KS, and HI consistently yield the highest match rates. Enrichment budget and pipeline effort should be prioritized for these states. At 19% nationally, the postal table yields an estimated ~50M enriched profiles.

---

## 7. Engineering Roadmap

**Phase 1 — Immediate (0-30 days)**
- Deduplicate consumer_email_dataset and consumer_email_supplemental (51.4M UUID duplicates)
- Promote biz sic_code dry run mutation to production
- Validate LinkedIn zip='00000' scope and confirm remediation path
- Re-validate fax_dataset assets — establish current fax deliverability rates

**Phase 2 — Short Term (30-90 days)**
- Rebuild consumer_email_dataset and enrichment_reference_dataset with corrected ORDER BY keys
- Populate platform_sales — enables campaign ROI measurement
- Resolve consumer_phone_dataset coordinate corruption

**Phase 3 — Medium Term (90-180 days)**
- Expand enrichment pipeline nationally (currently Wyoming only)
- Prioritize high-match states: NC, NJ, MD, KS, HI
- Investigate 1.7M record gap between cells versions

**Phase 4 — Long Term**
- Implement automated data quality monitoring on ingestion
- Standardize demographic fields (DOB, gender, ownrent) across all consumer tables
- Build cross-table deduplication layer for consumer email assets

---

## 8. Lessons Learned

- **Scale does not equal quality.** Tables with hundreds of millions of records can contain structural issues that make the majority of data unusable for specific targeting use cases — 92% fake DOB being the clearest example in this engagement.
- **Placeholder values silently damage business decisions.** Values like 1970-01-01, 0000000000, and 2147483647 pass format checks but corrupt segmentation, filtering, and enrichment operations in ways that are invisible without systematic profiling.
- **Technical constraints determine remediation strategy.** ClickHouse ORDER BY key limitations mean some data quality issues cannot be resolved through standard mutations — they require full table recreation. Understanding platform constraints early prevents misdirected remediation effort.

---

## 9. Tools & Methods

- **Platform:** ClickHouse Cloud (SharedMergeTree), PostgreSQL (Neon)
- **Language:** Python 3.13, clickhouse-connect, psycopg2, pandas
- **Environment:** Jupyter Notebook (Anaconda)
- **Profiling:** Custom `functions.py` — 7-question checklist per column
- **Cleaning:** `ALTER TABLE UPDATE/DELETE` mutations with pre/post validation
- **Enrichment:** Cross-table JOIN on `first_name_norm + last_name_norm + zip_norm` computed keys
- **Scale:** Queries on tables ranging from 3M to 714M rows

---

*This report was produced as part of the data-quality-platform portfolio project.*
*For detailed profiling outputs, cleaning queries, and validation results, see the corresponding Jupyter notebooks in the `/notebooks` directory.*
