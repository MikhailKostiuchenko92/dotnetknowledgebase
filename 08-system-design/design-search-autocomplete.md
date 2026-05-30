# Design a Search Autocomplete System

**Category:** System Design / Classic Problems
**Difficulty:** Senior
**Tags:** `autocomplete`, `trie`, `search`, `caching`, `ranking`

## Question

> Design a search autocomplete (typeahead) system that suggests top-10 completions as a user types. It must handle 10 million daily active users, return results in under 100 ms, and surface personalised suggestions when feasible.

- Would you use a trie, inverted index, or something else?
- How do you keep rankings fresh as query popularity changes?
- How do you scale this to a global user base?

## Short Answer

The core data structure is a prefix trie where each node stores the top-K most popular completions rooted at that prefix, pre-aggregated from a query log pipeline. Client-side, we debounce input (300 ms) and cache the last N prefixes. The trie is stored in Redis as a sorted set per prefix (score = popularity), served from CDN-edge pops for global latency. Popularity is refreshed hourly via a batch Spark/Flink job on the query log.

## Detailed Explanation

### Functional Requirements

| Feature | Detail |
|---------|--------|
| Input | Prefix string (1–100 chars) |
| Output | Top-10 completions, ranked by popularity |
| Freshness | Rankings updated hourly |
| Personalisation | Optional; recent user queries boosted |
| Supported languages | UTF-8, multi-lingual |

Non-functional: <100 ms p99 end-to-end, 10M DAU → ~600 QPS peak (assume 1 query per 5 s typing).

### Core Data Structures

#### Option 1: Trie with Pre-Aggregated Top-K

A standard trie node stores a character + pointer to children. For autocomplete, augment each node with a list of the top-K (K=10) most popular completions that pass through that node.

```
root
 ├── 'a'  topK: ["apple","amazon","air france"]
 │    ├── 'p'  topK: ["apple","appstore","apply"]
 │    │    └── 'p' → 'l' → 'e'  topK: ["apple watch","apple music"]
```

- **Lookup**: traverse prefix chars → return stored top-K at final node. O(P) where P = prefix length.
- **Update**: recompute top-K bottom-up — expensive for high-frequency writes → **batch update** (rebuild periodically).

#### Option 2: Redis Sorted Sets

Store each prefix as a Redis key; value is a sorted set where members are completions and scores are popularity counts.

```
ZADD suggest:ap 9500 "apple"
ZADD suggest:ap 8100 "appstore"
ZREVRANGEBYSCORE suggest:ap +inf -inf LIMIT 0 10  → top 10
```

- Scales horizontally via Redis Cluster; keys shard on prefix.
- Fine-grained TTL per prefix; stale prefixes expire automatically.
- **Hot key problem**: common short prefixes ("th", "wh") are extremely hot → replicate them across multiple shards with client-side fan-out.

### Ranking Model

```
score = α × global_frequency + β × freshness_boost + γ × personalisation_score
```

| Factor | Weight | Source |
|--------|--------|--------|
| Global frequency | 0.7 | Aggregated query log (last 7 days) |
| Freshness | 0.2 | Exponential decay: recent queries weighted more |
| Personalisation | 0.1 | User's own query history (last 30 days) |

Personalisation is computed server-side from a user vector stored in a fast KV store (e.g., DynamoDB); add ~10 ms to latency.

### Data Pipeline (Keeping Rankings Fresh)

```
Browser/App → Kafka topic: raw_queries
          → Flink (streaming, 5-min micro-batch)
          → Aggregation store (HBase / BigTable)
          → Hourly batch Spark job
          → Builds new trie snapshot
          → Uploads trie to object storage (S3)
          → Cache refresh service pulls new snapshot
          → Swap trie in Redis / in-process cache (atomic pointer swap)
```

### Filtering & Safety

- Blocklist of profanity/PII terms applied at ingestion and at serving.
- Prefix search must normalise: lowercase, strip accents, handle Unicode.
- Spell correction (BK-tree or SymSpell) for near-miss prefixes — add as a separate service to avoid latency spike on the hot path.

### Global Deployment

```
User (London)
 → DNS (GeoDNS) → Edge PoP (Frankfurt)
     → CDN layer: cache GET /suggest?q=appl for 5 minutes
         → If miss → Regional cache cluster (Redis)
             → If miss → Trie service (stateless, auto-scaled)
```

- CDN caches completions for the most popular 10M prefixes (∼80% cache hit).
- Regional Redis clusters are updated by the global trie refresh pipeline.
- Remaining 20% cold prefixes hit the trie service, which maintains an LRU in-process cache.

### Capacity

| Metric | Estimate |
|--------|----------|
| Unique queries/day | ~500M → ~5M unique prefixes after dedup |
| Trie memory | ~10 GB (compressed with DAFSA) |
| Redis sorted sets | ~50 GB (top 5M prefixes × avg 10 members × 100 B) |
| QPS to Redis | ~600 peak → well within single Redis cluster |

> **Warning:** Don't attempt real-time trie updates on every keystroke. A single trie rebuild job running hourly is simpler, more accurate, and avoids write amplification across millions of prefix nodes.

## Code Example

```csharp
// Minimal in-process trie for illustration (production uses Redis sorted sets)
using System.Collections.Concurrent;

namespace AutoComplete;

public sealed class TrieNode
{
    public Dictionary<char, TrieNode> Children { get; } = new();
    // Pre-aggregated top-K completions at this prefix
    public List<string> TopK { get; set; } = [];
}

public sealed class AutocompleteTrie
{
    private readonly TrieNode _root = new();

    public void Build(IEnumerable<(string query, int frequency)> rankedQueries)
    {
        // Sort descending; insert top entries first so each node accumulates top-K naturally
        foreach (var (query, _) in rankedQueries.OrderByDescending(x => x.frequency))
            Insert(query);
    }

    private void Insert(string query, int k = 10)
    {
        var node = _root;
        foreach (var ch in query)
        {
            if (!node.Children.TryGetValue(ch, out var child))
                node.Children[ch] = child = new TrieNode();

            if (child.TopK.Count < k)
                child.TopK.Add(query);

            node = child;
        }
    }

    public IReadOnlyList<string> Search(string prefix)
    {
        var node = _root;
        foreach (var ch in prefix)
        {
            if (!node.Children.TryGetValue(ch, out var child))
                return [];
            node = child;
        }
        return node.TopK;
    }
}

// Redis-backed production variant
public sealed class RedisAutocomplete(IDatabase db)
{
    public async Task<IList<string>> GetSuggestionsAsync(string prefix)
    {
        prefix = prefix.ToLowerInvariant();
        var key = $"suggest:{prefix}";

        // ZREVRANGE returns members sorted by score desc
        var results = await db.SortedSetRangeByRankAsync(key,
            start: 0, stop: 9, order: Order.Descending);

        return results.Select(r => (string)r!).ToList();
    }

    public async Task IncrementAsync(string query)
    {
        query = query.ToLowerInvariant();
        // Increment score for every prefix of the query
        var tasks = Enumerable.Range(1, query.Length)
            .Select(len => db.SortedSetIncrementAsync(
                $"suggest:{query[..len]}", query, 1));
        await Task.WhenAll(tasks);
    }
}
```

## Common Follow-up Questions

- How would you handle real-time trending terms (e.g., a breaking news event) when the batch job runs hourly?
- How do you support multi-language autocomplete (Chinese, Arabic) with non-Latin characters?
- A user types "the" — a very hot prefix. How do you prevent a single Redis shard from becoming a bottleneck?
- How would you add fuzzy matching (typo tolerance) without blowing up latency?
- Walk me through how you'd A/B test a new ranking algorithm in production.

## Common Mistakes / Pitfalls

- **Updating the trie on every query**: causes massive write amplification across all prefix nodes; always use batch aggregation.
- **Not normalising input**: "Apple", "apple", "APPLE" must map to the same entry; normalise at both ingestion and query time.
- **Returning raw frequency as score**: popular-but-old queries crowd out fresh ones; always apply time decay.
- **Ignoring the hot prefix problem**: prefix "th" serves the entire English-speaking internet; replicate it or use a dedicated shard.
- **No blocklist at serving time**: the ranking pipeline may miss newly emerging offensive terms; apply a runtime blocklist as a final filter.
- **Treating personalisation as mandatory**: personalisation adds latency and infra cost; keep it optional and behind a feature flag.

## References

- [Building Autocomplete at Scale — Engineering at Meta](https://engineering.fb.com/2010/12/22/core-infra/the-life-of-a-typeahead-query/) (verify URL)
- [System Design Interview Vol 1, Ch 13 — Alex Xu](https://www.bytebytego.com)
- [Redis ZADD / ZREVRANGE — redis.io](https://redis.io/commands/zadd/)
- [SymSpell — fast fuzzy matching](https://github.com/wolfgarbe/SymSpell)
- [See: redis-fundamentals.md](./redis-fundamentals.md)
- [See: caching-strategies-overview.md](./caching-strategies-overview.md)
