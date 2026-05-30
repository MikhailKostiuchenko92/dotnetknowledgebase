# Designing for Analytics at Scale

**Category:** System Design / Data Pipelines
**Difficulty:** Senior
**Tags:** `analytics`, `star-schema`, `columnar-storage`, `partitioning`, `query-pushdown`, `approximate-queries`, `olap`

## Question

> How do you design a database schema and storage layout for analytics at scale? What is a star schema? Why does columnar storage outperform row storage for aggregations? What techniques enable fast queries over billions of rows?

- What is query predicate pushdown and why does it matter for Parquet/Delta Lake queries?
- When should you use approximate query answering instead of exact counts?

## Short Answer

Analytics at scale requires different design decisions than OLTP: star schemas denormalise data into a central fact table and surrounding dimension tables, enabling simple JOIN-free aggregations. Columnar storage (Parquet, ORC) stores each column separately, allowing queries that touch 3 of 50 columns to skip 47 columns entirely. Partitioning by date divides data into directories that can be skipped by date-range queries. Query predicate pushdown filters rows at the file/page level before data is loaded into memory. For approximate answers on huge datasets, probabilistic data structures (HyperLogLog for distinct counts, sketches for quantiles) provide order-of-magnitude speed improvements with <1% error.

## Detailed Explanation

### Star Schema

The star schema separates measurements (facts) from context (dimensions):

```sql
-- Fact table: one row per transaction, FK references to dimensions
CREATE TABLE fact_sales (
    sale_id       BIGINT      NOT NULL,
    date_key      INT         NOT NULL REFERENCES dim_dates(date_key),
    customer_key  INT         NOT NULL REFERENCES dim_customers(customer_key),
    product_key   INT         NOT NULL REFERENCES dim_products(product_key),
    store_key     INT         NOT NULL REFERENCES dim_stores(store_key),
    quantity      INT         NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    total_amount  DECIMAL(10,2) NOT NULL  -- pre-computed; avoids multiply at query time
)
PARTITION BY RANGE (date_key);  -- one partition per month

-- Dimension tables: small, rarely updated, descriptive
CREATE TABLE dim_customers (
    customer_key  INT PRIMARY KEY,
    customer_id   UUID,
    full_name     TEXT,
    city          TEXT,
    country       TEXT,
    segment       TEXT  -- 'Premium', 'Standard', 'Trial'
);

CREATE TABLE dim_dates (
    date_key      INT PRIMARY KEY,   -- format: YYYYMMDD (20240115)
    full_date     DATE,
    year          SMALLINT,
    quarter       SMALLINT,
    month         SMALLINT,
    week_of_year  SMALLINT,
    day_of_week   SMALLINT,
    is_weekend    BOOLEAN,
    is_holiday    BOOLEAN
);
```

**Why star schema for analytics:**
- Simple, predictable join structure (fact ← dimension).
- Dimension tables fit in memory (thousands of rows vs billions in facts).
- BI tools generate efficient queries against star schemas automatically.
- Each query only touches the dimensions it needs (no massive OLTP joins).

### Columnar Storage

Row storage: `[row1: id=1, name=Alice, age=30, country=UK][row2: id=2, name=Bob, age=25, country=US]`  
Columnar storage: `[ids: 1, 2, 3...][names: Alice, Bob...][ages: 30, 25...][countries: UK, US...]`

**Query**: `SELECT AVG(age) FROM customers WHERE country = 'UK'`

| Storage | Reads | Pages touched |
|---------|-------|--------------|
| Row (all 50 columns) | All columns for every row | All pages |
| Columnar (country + age only) | Only 2 columns out of 50 | 4% of pages |

Additional columnar advantages:
- **RLE (Run-Length Encoding)**: repeated values compress heavily (`UK, UK, UK, UK` → `UK×4`).
- **Dictionary encoding**: replace string columns with integer codes + dictionary.
- **Min/max statistics**: each column chunk stores min/max → skip entire file pages if `WHERE` condition can't match.

### Partitioning Strategies

Partitioning divides data into physical directories/files that can be skipped:

```
Parquet files in Azure Data Lake:
  silver/sales/year=2024/month=01/*.parquet
  silver/sales/year=2024/month=02/*.parquet
  silver/sales/year=2023/month=12/*.parquet

Query: WHERE year = 2024 AND month = 01
  → Only reads year=2024/month=01/ directory
  → Skips 11 out of 12 months entirely
```

**Partition key choices:**

| Key | Good for | Avoid if |
|-----|---------|----------|
| Date/month | Time-range queries (most common) | Too many small files |
| Region/country | Regional dashboards | High cardinality (1000+ regions) |
| Entity + date | Per-customer analytics | Creates too many small files |

> Too many small Parquet files (< 64MB each) causes "small file problem" — each file has read overhead. Use `OPTIMIZE` (Delta Lake) or compaction jobs to merge small files.

### Query Predicate Pushdown

Predicate pushdown filters data at the lowest possible layer before loading into memory:

```
Without pushdown:
  Read 10GB of Parquet files into memory → filter → return 1MB result

With predicate pushdown:
  Read Parquet footer (min/max stats) → skip 90% of row groups → read 1GB → filter → 1MB
```

In Spark / Azure Synapse:
```python
# Spark: pushdown happens automatically with DataFrame filter
df = spark.read.parquet("abfss://silver/sales/")
    .filter("year = 2024 AND month = 1")   # Spark pushes this to Parquet reader
    .groupBy("customer_key")
    .agg({"total_amount": "sum"})

# Check the physical plan to verify pushdown is happening:
df.explain()  # look for "PushedFilters" in the scan node
```

For **Bloom filters** on high-cardinality columns:

```sql
-- Delta Lake: add Bloom filter for faster equality lookups
ALTER TABLE silver.sales
  SET TBLPROPERTIES (
    'delta.dataSkippingNumIndexedCols' = '10',
    'delta.bloomFilter.columns' = 'customer_id',
    'delta.bloomFilter.fpp' = '0.01'  -- 1% false positive rate
  );
```

### Pre-Aggregation: Materialised Views and Rollups

For frequently-run aggregations, pre-compute and store results:

```sql
-- Azure Synapse: materialised view (auto-maintained)
CREATE MATERIALIZED VIEW mv_daily_revenue
WITH (DISTRIBUTION = HASH(date_key))
AS
SELECT
    date_key,
    product_key,
    SUM(total_amount) AS revenue,
    COUNT(*)          AS orders
FROM fact_sales
GROUP BY date_key, product_key;
-- Query automatically rewrites to use mv_daily_revenue when applicable
```

### Approximate Query Answering

For huge datasets where exact counts aren't required (user counts, unique visitors, cardinality estimation):

```sql
-- PostgreSQL: exact distinct count (slow for large tables)
SELECT COUNT(DISTINCT customer_id) FROM fact_sales WHERE year = 2024;
-- May take minutes on billions of rows

-- PostgreSQL: HyperLogLog approximate count (fast, ~1% error)
SELECT hll_cardinality(hll_add_agg(hll_hash_text(customer_id::text)))::int
FROM fact_sales WHERE year = 2024;
-- Milliseconds; 99% accurate

-- Azure Data Explorer: approximate distinct count
customers_events
| summarize dcount(customer_id) by bin(timestamp, 1d)
-- dcount() uses HyperLogLog internally
```

**t-digest for percentiles** (p50, p95, p99) — accurate without materialising all values:

```csharp
// .NET: streaming percentile estimation
var tdigest = new TDigest(compression: 100);
await foreach (var response in streamingResponses)
    tdigest.Add(response.LatencyMs);

double p99 = tdigest.Quantile(0.99);  // ~1% error vs exact sort
```

### Z-Ordering (Data Clustering)

Delta Lake's Z-order groups related data physically in the same files — queries with multiple filter predicates skip more files:

```python
# Without Z-order: files interleave customer data across all regions
# Query WHERE customer_id = X AND country = 'UK' still reads many files

# With Z-order: files are arranged so customer X's data is co-located with UK data
spark.sql("""
    OPTIMIZE silver.sales
    ZORDER BY (customer_id, country)
""")
# Now queries with customer_id + country filter skip ~80% of files
```

> **Warning:** Z-ordering is expensive (rewrites files) and only benefits queries that filter on the Z-ordered columns. Don't Z-order on high-cardinality columns without profiling actual query patterns first.

## Common Follow-up Questions

- What is a snowflake schema and when is it preferred over a star schema?
- How does Apache Parquet's row group and page structure work?
- What is the difference between Delta Lake's OPTIMIZE/ZORDER and Spark's `repartition`?
- How do you handle slowly changing dimensions (SCD Type 1 vs Type 2)?
- What is ClickHouse and why is it 100× faster than PostgreSQL for analytics?

## Common Mistakes / Pitfalls

- **Using OLTP schema for analytics**: joining 8 normalised tables on billions of rows is slow; denormalise into star schema for analytics.
- **Not partitioning the fact table**: a single 1TB Parquet file must be fully scanned for every query; partition by date at minimum.
- **Partitioning by high-cardinality column**: partitioning by `customer_id` with 10M customers creates 10M directories — too many small files, catastrophic for listing and planning.
- **Not running OPTIMIZE/compaction**: streaming writes create many small files (1 per micro-batch); periodic compaction is essential for read performance.
- **Pre-aggregating at the wrong granularity**: daily rollups are useless for hourly dashboard; match pre-aggregation granularity to query requirements.

## References

- [Star schema — Kimball Group](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/)
- [Apache Parquet file format specification](https://parquet.apache.org/docs/file-format/)
- [Delta Lake OPTIMIZE and Z-order](https://docs.delta.io/latest/optimizations-oss.html)
- [HyperLogLog for cardinality estimation](https://research.google/pubs/pub40671/) (verify URL)
- [Azure Synapse Analytics — materialised views](https://learn.microsoft.com/en-us/azure/synapse-analytics/sql-data-warehouse/performance-tuning-materialized-views)
- [See: data-warehouse-vs-data-lake.md](./data-warehouse-vs-data-lake.md)
- [See: denormalization-for-performance.md](./denormalization-for-performance.md)
