# Data Warehouse vs Data Lake

**Category:** System Design / Data Pipelines
**Difficulty:** Middle
**Tags:** `data-warehouse`, `data-lake`, `etl`, `elt`, `azure-synapse`, `schema-on-read`, `parquet`, `lakehouse`

## Question

> What is the difference between a data warehouse and a data lake? When should you use each? What is ELT vs ETL? What is a lakehouse and how does it relate to both?

- Why is schema-on-read more flexible than schema-on-write?
- How does Azure Synapse Analytics relate to both paradigms?

## Short Answer

A data warehouse stores structured, cleaned, pre-modelled data optimised for SQL analytics — schema enforced on write (schema-on-write), fast queries, expensive storage. A data lake stores raw data in any format (JSON, Parquet, CSV, images) at low cost — schema applied at query time (schema-on-read), flexible but requires more query effort. ETL (Extract-Transform-Load) cleans data before loading into the warehouse; ELT (Extract-Load-Transform) loads raw data into the lake first and transforms it on demand using distributed compute. A lakehouse (Delta Lake, Azure Fabric) combines the structure and performance of a warehouse with the flexibility and cost of a data lake.

## Detailed Explanation

### Data Warehouse

A data warehouse is a relational database optimised for analytics (OLAP — Online Analytical Processing) rather than transactions (OLTP):

- **Schema-on-write**: data is validated, cleaned, and modelled into star/snowflake schema before loading.
- **Columnar storage**: columns stored together for fast aggregation (e.g., Azure Synapse, Snowflake, BigQuery use columnar format internally).
- **SQL interface**: standard SQL queries; BI tools (Power BI, Tableau) connect directly.
- **Expensive**: per-query or per-compute-hour pricing, premium storage.

```
OLTP Source (orders DB)
      │
      ▼ (ETL pipeline — nightly)
[Transform: clean, join, standardise]
      │
      ▼
Data Warehouse (star schema)
  ├── fact_orders (order_id, date_key, customer_key, product_key, amount)
  ├── dim_customers (customer_key, name, region, segment)
  ├── dim_products (product_key, name, category, price)
  └── dim_dates (date_key, year, quarter, month, week, is_weekend)

BI Query: SELECT SUM(amount) FROM fact_orders
          JOIN dim_dates ON date_key WHERE year = 2024 AND quarter = 1
          → fast (columnar, pre-aggregated indexes)
```

**Star schema design**: a central fact table (measurements) surrounded by dimension tables (context). Denormalised for query performance — joins are simple and indexes are efficient.

### Data Lake

A data lake stores raw data as-is in cheap object storage (Azure Data Lake Storage Gen2, S3):

- **Schema-on-read**: no transformation before storage; schema applied when querying.
- **Any format**: JSON, CSV, Parquet, Avro, images, audio, raw text.
- **Cheap storage**: blob storage costs ~$0.02/GB/month vs warehouse ~$0.20/GB/month.
- **Flexible**: future use cases can query existing raw data differently.

```
All sources dump data to ADLS Gen2
  ├── raw/orders/2024/01/15/orders.json       ← raw operational events
  ├── raw/clickstream/2024/01/15/logs.gz       ← raw web logs
  ├── raw/iot-sensors/2024/01/15/readings.csv  ← raw IoT data
  └── raw/images/product-photos/             ← binary data

Query with Azure Synapse Serverless SQL:
SELECT TOP 100 orderId, customerId, SUM(totalAmount)
FROM OPENROWSET(BULK 'https://datalake.dfs.core.windows.net/raw/orders/2024/**',
    FORMAT='JSON') AS r
GROUP BY orderId, customerId
-- Schema applied at query time — flexible but slower than warehouse
```

### ETL vs ELT

| | ETL (Extract-Transform-Load) | ELT (Extract-Load-Transform) |
|--|-----------------------------|-----------------------------|
| Transform step | **Before** loading | **After** loading |
| Where transformation runs | Dedicated ETL tool (SSIS, Informatica) | In the warehouse/lake using SQL or Spark |
| Storage | Only clean data stored | Raw data stored (also usable for future transforms) |
| Latency | Higher (transformation before load) | Lower (load fast, transform on demand) |
| Flexibility | Must redefine ETL job to add fields | Can always re-query raw data differently |
| Tools | Azure Data Factory, SSIS | dbt, Azure Synapse, Databricks |

Modern practice prefers ELT for data lakes: load everything raw, then transform with dbt or Spark notebooks into marts.

### Lakehouse: Best of Both

A **lakehouse** stores data in open formats (Delta Lake, Apache Iceberg) on cheap object storage while providing ACID transactions, schema enforcement, and performance optimisation:

```
Data Lake Storage (ADLS Gen2, cheap)
  └── Delta Lake tables (open format Parquet + transaction log)
      ├── ACID transactions (concurrent reads/writes safe)
      ├── Schema enforcement (schema-on-write option)
      ├── Time travel (query data as of any past timestamp)
      ├── Optimised reads (data skipping, Z-ordering)
      └── SQL + Spark + streaming compatible
```

**Azure Fabric** (formerly Azure Synapse + Power BI + Data Factory unified) is Microsoft's lakehouse platform.

### Medallion Architecture (Bronze / Silver / Gold)

The standard data lake organisation pattern:

```
Bronze (raw): exact copy of source data, no transformation, immutable
  └── raw/orders/2024/01/15/*.json  ← ingested by ADF, never modified

Silver (cleaned): validated, standardised, deduplicated
  └── silver/orders/*.parquet  ← cleaned by Spark/dbt, nullable removed, types correct

Gold (business): aggregated, modelled, ready for BI/ML
  └── gold/daily_sales/*.parquet  ← star schema, pre-aggregated, used by Power BI
```

```python
# Azure Databricks: Bronze → Silver transformation (PySpark)
from delta.tables import DeltaTable
from pyspark.sql.functions import col, to_timestamp

# Read bronze (raw JSON)
bronze = spark.read.format("json") \
    .load("abfss://raw@datalake.dfs.core.windows.net/orders/")

# Clean and write to silver (Delta format)
silver = bronze \
    .filter(col("orderId").isNotNull()) \
    .withColumn("eventTime", to_timestamp("eventTime", "yyyy-MM-dd'T'HH:mm:ssZ")) \
    .dropDuplicates(["orderId", "eventVersion"])

silver.write.format("delta").mode("append") \
    .save("abfss://silver@datalake.dfs.core.windows.net/orders/")
```

### Azure Synapse Analytics

Azure Synapse unifies warehouse and lake in one platform:

| Capability | Use case |
|-----------|---------|
| **Dedicated SQL Pool** | Data warehouse: structured, pre-loaded, fast queries, expensive |
| **Serverless SQL Pool** | Query data lake files in-place: OPENROWSET on Parquet/CSV, pay-per-query |
| **Apache Spark Pool** | ELT transformations, ML, large-scale data processing |
| **Synapse Link** | Zero-ETL: query Cosmos DB / SQL operational data as analytics workload |

```sql
-- Synapse Serverless: query Parquet files in ADLS Gen2 without loading
SELECT
    YEAR(eventTime) AS yr,
    MONTH(eventTime) AS mo,
    COUNT(*) AS order_count,
    SUM(totalAmount) AS revenue
FROM OPENROWSET(
    BULK 'https://datalake.dfs.core.windows.net/silver/orders/**/*.parquet',
    FORMAT = 'PARQUET') AS r
WHERE YEAR(eventTime) = 2024
GROUP BY YEAR(eventTime), MONTH(eventTime)
ORDER BY yr, mo;
```

> **Warning:** "Just put everything in the data lake" without a medallion architecture and clear ownership creates a **data swamp** — data is there but undiscoverable, untrusted, and unusable. Define bronze/silver/gold layers, data contracts, and ownership before ingesting data.

## Common Follow-up Questions

- What is dbt (data build tool) and how does it enable analytics engineering?
- How does Delta Lake's time travel work and what are its use cases?
- What is a data mesh and how does it change data ownership models?
- How do you implement column-level access control (masking PII) in a data lake?
- What is the difference between Apache Parquet and Apache Avro, and when do you use each?

## Common Mistakes / Pitfalls

- **Storing only transformed data (ETL-only)**: losing the raw data means you can't re-process it with different logic later; always keep the raw layer.
- **No partitioning strategy**: unpartitioned Parquet files in a data lake require full scans; partition by date and entity ID to enable partition pruning.
- **Star schema overkill for small data**: a star schema makes sense for billions of rows; for millions, a single wide table with good indexes in a relational DB is simpler and faster.
- **Not versioning transformation logic**: dbt models and Spark notebooks are code — version control them; an unversioned transformation is as bad as unversioned application code.
- **Ignoring data quality**: loading raw data without any quality checks (row counts, null rate, schema drift) means downstream consumers silently receive bad data.

## References

- [Azure Data Lake Storage Gen2](https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction)
- [Azure Synapse Analytics](https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is)
- [Delta Lake documentation](https://docs.delta.io/)
- [Medallion architecture — Databricks](https://www.databricks.com/glossary/medallion-architecture)
- [dbt documentation](https://docs.getdbt.com/)
- [See: batch-vs-stream-processing.md](./batch-vs-stream-processing.md)
- [See: change-data-capture.md](./change-data-capture.md)
