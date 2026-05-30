# Full-Text Search in SQL Server

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🔴 Senior
**Tags:** `SQL`, `full-text-search`, `FTS`, `CONTAINS`, `FREETEXT`, `LIKE`, `Elasticsearch`, `Azure AI Search`

## Question

> What is SQL Server Full-Text Search, and how does it differ from `LIKE '%keyword%'` pattern matching? What are `CONTAINS` and `FREETEXT`, and when should you prefer an external search engine like Elasticsearch or Azure AI Search?

## Short Answer

SQL Server Full-Text Search (FTS) builds an inverted index over specified text columns — enabling linguistic searches (stemming, stop words, thesaurus) that `LIKE '%keyword%'` cannot do. `CONTAINS` performs precise word, phrase, proximity, and inflectional matching. `FREETEXT` performs natural-language ranking. FTS is significantly faster than `LIKE` at scale for word lookups, but slower than purpose-built search engines (Elasticsearch, Azure AI Search) for relevance ranking, faceting, autocomplete, and cross-entity search. For simple keyword search within one table, FTS is adequate. For product search with facets, typo tolerance, and ranking, use a dedicated search engine.

## Detailed Explanation

### Why `LIKE '%keyword%'` Fails at Scale

```sql
-- Full table scan — no index can help with a leading wildcard
SELECT * FROM Articles WHERE Body LIKE '%machine learning%';
```

- `LIKE 'keyword%'` (trailing wildcard) can use an index seek.
- `LIKE '%keyword%'` (leading wildcard) **always causes a full table scan** on the column.
- No stemming: `LIKE '%run%'` does not match "running", "ran".
- No relevance scoring: all matching rows are equal.

### Setting Up Full-Text Search

```sql
-- 1. Create a Full-Text Catalog
CREATE FULLTEXT CATALOG ftCatalog AS DEFAULT;

-- 2. Create a Full-Text Index on the table
CREATE FULLTEXT INDEX ON Articles (Title, Body)
KEY INDEX PK_Articles
ON ftCatalog
WITH CHANGE_TRACKING AUTO;  -- auto-update index on DML
-- Language 1033 = English (affects stemming, stop words)
```

### CONTAINS — Precise FTS Queries

```sql
-- Simple word search
SELECT Id, Title FROM Articles
WHERE CONTAINS(Body, 'machine');

-- Phrase search
SELECT Id, Title FROM Articles
WHERE CONTAINS(Body, '"machine learning"');

-- Prefix search — starts with 'learn'
SELECT Id, Title FROM Articles
WHERE CONTAINS(Body, '"learn*"');

-- Boolean operators
SELECT Id, Title FROM Articles
WHERE CONTAINS(Body, 'machine AND learning AND NOT "deep learning"');

-- Proximity — 'machine' within 5 words of 'learning'
SELECT Id, Title FROM Articles
WHERE CONTAINS(Body, 'NEAR((machine, learning), 5)');

-- Inflectional forms — matches 'run', 'ran', 'running'
SELECT Id, Title FROM Articles
WHERE CONTAINS(Body, 'FORMSOF(INFLECTIONAL, run)');
```

### FREETEXT — Natural Language Ranking

```sql
-- Natural language query — SQL Server parses intent, stems words, finds synonyms
SELECT Id, Title, [Rank]
FROM Articles, FREETEXTTABLE(Articles, Body, 'machine learning neural network') AS ft
WHERE Articles.Id = ft.[KEY]
ORDER BY ft.[Rank] DESC;
```

`FREETEXTTABLE` returns a ranked result set; `CONTAINSTABLE` does the same for `CONTAINS`-style predicates.

### FTS vs LIKE vs Elasticsearch

| Feature | `LIKE '%x%'` | SQL Server FTS | Elasticsearch |
|---------|-------------|---------------|--------------|
| Performance (large tables) | ❌ Full scan | ✅ Inverted index | ✅ Inverted index |
| Stemming/inflection | ❌ | ✅ | ✅ |
| Relevance ranking | ❌ | Basic (RANK) | ✅ BM25 scoring |
| Fuzzy matching / typo tolerance | ❌ | ❌ | ✅ |
| Facets / aggregations | ❌ Awkward | ❌ | ✅ |
| Autocomplete / suggest | ❌ | Limited prefix | ✅ |
| Cross-index joins | ✅ SQL JOIN | ✅ SQL JOIN | ❌ Separate indices |
| Real-time updates | ✅ | ~Seconds delay | ~Seconds delay |
| Operational complexity | Low | Medium | High |

### .NET Integration

**SQL Server FTS via Dapper:**
```csharp
var results = await conn.QueryAsync<ArticleDto>("""
    SELECT a.Id, a.Title, ft.[Rank]
    FROM Articles a
    INNER JOIN FREETEXTTABLE(Articles, Body, @query) AS ft ON a.Id = ft.[KEY]
    ORDER BY ft.[Rank] DESC
    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY
    """,
    new { query = searchTerm, offset = (page - 1) * pageSize, pageSize });
```

**Elasticsearch via NEST (.NET client):**
```csharp
var response = await _client.SearchAsync<ArticleDocument>(s => s
    .Index("articles")
    .Query(q => q.MultiMatch(m => m
        .Fields(f => f.Field(a => a.Title, boost: 2.0).Field(a => a.Body))
        .Query(searchTerm)
        .Fuzziness(Fuzziness.Auto)))
    .Sort(sort => sort.Descending(SortSpecialField.Score))
    .From((page - 1) * pageSize)
    .Size(pageSize));
```

### When to Use What

| Scenario | Recommendation |
|----------|---------------|
| Simple keyword lookup in 1 table, < 10M rows | SQL Server FTS |
| Product catalog with facets, typo tolerance | Elasticsearch / Azure AI Search |
| Multi-lingual content with complex stemming | Elasticsearch |
| Strong consistency with search | SQL Server FTS (or sync external with Outbox) |
| Low operational budget, existing SQL Server | SQL Server FTS |
| High-volume, relevance-critical search | Elasticsearch |

## Code Example

```csharp
// Hybrid search service — SQL Server FTS for simple, Elasticsearch for complex
public class SearchService(AppDbContext db, ElasticsearchClient esClient)
{
    public async Task<SearchResult> SearchArticlesAsync(
        string query, bool useAdvanced, CancellationToken ct)
    {
        if (!useAdvanced)
        {
            // SQL Server FTS for admin/internal search
            return await db.Database
                .SqlQuery<ArticleSearchHit>($"""
                    SELECT a.Id, a.Title, ft.[Rank] AS Score
                    FROM Articles a
                    INNER JOIN CONTAINSTABLE(Articles, Body, {query}) ft
                        ON a.Id = ft.[KEY]
                    ORDER BY ft.[Rank] DESC
                    """)
                .ToSearchResult(ct);
        }

        // Elasticsearch for user-facing search with relevance + facets
        var response = await esClient.SearchAsync<ArticleDocument>(s => s
            .Query(q => q.MultiMatch(m => m
                .Query(query)
                .Fields(f => f.Field(a => a.Title, 2.0).Field(a => a.Body))
                .Fuzziness(Fuzziness.Auto))), ct);

        return response.ToSearchResult();
    }
}
```

## Common Follow-up Questions

- How do you keep an Elasticsearch index in sync with a SQL Server database — what patterns prevent data inconsistency?
- What is the Outbox pattern, and how does it apply to search index synchronization?
- How does Azure AI Search (formerly Azure Cognitive Search) differ from self-hosted Elasticsearch?
- What is the Elastic NEST client vs the new `Elastic.Clients.Elasticsearch` — what changed?
- How do you handle search index schema migrations (adding/removing analyzed fields)?

## Common Mistakes / Pitfalls

- **Using `LIKE '%x%'` for full-text search on large tables**: a 50M-row table with a `LIKE '%keyword%'` query will take seconds to minutes, consuming full CPU. It's the number one SQL performance anti-pattern for text search.
- **Assuming FTS updates are instant**: `CHANGE_TRACKING AUTO` updates the FTS index asynchronously — there is a propagation delay. If you insert a row and immediately search for it, it may not appear.
- **Using FTS without language configuration**: the default English stemmer treats "running" and "run" as related. For multilingual content, each language needs its own FTS language parameter.
- **Not considering Elasticsearch for user-facing search**: SQL Server FTS lacks fuzzy matching and BM25 ranking. Users expect typo tolerance in 2024 — "mahcine leraning" should still find "machine learning".

## References

- [Full-Text Search overview — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/search/full-text-search)
- [CONTAINS predicate — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/contains-transact-sql)
- [FREETEXTTABLE — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/freetexttable-transact-sql)
- [Elastic.Clients.Elasticsearch .NET client](https://www.elastic.co/guide/en/elasticsearch/client/net-api/current/index.html)
- [Azure AI Search .NET SDK — Microsoft Learn](https://learn.microsoft.com/en-us/azure/search/search-howto-dotnet-sdk)
