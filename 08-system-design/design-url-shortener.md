# Design: URL Shortener

**Category:** System Design / Classic Design Problems
**Difficulty:** 🟡 Middle
**Tags:** `system-design`, `url-shortener`, `hashing`, `base62`, `redirect`, `analytics`, `collision`

## Question

> Design a URL shortening service (like bit.ly). Support creating short links, redirecting to long URLs, handling custom aliases, link expiry, and click analytics. Estimate scale: 100M new URLs/day, 10B redirects/day.

## Short Answer

A URL shortener maps a long URL to a short alphanumeric code (7 base-62 characters = 3.5 trillion combinations), stores the mapping in a DB (Redis for fast read, SQL/NoSQL for persistence), and redirects via HTTP 301/302. The core challenges are: generating unique short codes at high write throughput without collisions, serving 10B redirects/day with sub-10ms latency (solved by aggressive caching), and handling analytics (async via a message queue to keep redirect latency low).

## Detailed Explanation

### Capacity Estimation

| Metric | Value |
|--------|-------|
| New URLs per day | 100M → ~1,200/s writes |
| Redirects per day | 10B → ~115,000/s reads |
| Read:write ratio | ~100:1 |
| Storage per URL | ~500 bytes (URL + metadata) |
| 5-year storage | 100M × 365 × 5 × 500B ≈ **90 TB** |
| Short code length | 7 base-62 chars = 62^7 = 3.5T combinations |

### Short Code Generation Strategies

#### Option 1: Hash-Based (MD5 / MurmurHash)
1. Hash the long URL.
2. Take the first 7 characters (base-62 encoded).
3. Check DB for collision; if collision, append a counter and re-hash.

**Pros**: deterministic (same URL always → same code); natural deduplication.
**Cons**: collision detection requires a DB read on every write; hash collisions between different URLs produce the same code.

#### Option 2: Random Code
1. Generate a random 7-character base-62 string.
2. Check DB for collision; retry if collision.

**Pros**: simpler; no hash function needed.
**Cons**: same long URL gets different codes each time; no deduplication without extra lookup.

#### Option 3: Counter + Base-62 Encoding (Recommended)
1. Maintain a global auto-incrementing counter (distributed counter in Redis or a dedicated ID service).
2. Encode the counter in base-62.

```
Counter: 1234567890 → base62: "5Cd2z7"
```

**Pros**: guaranteed uniqueness; no collision check needed; codes are short and sequential.
**Cons**: sequential codes reveal approximate creation time; ID generator is a single point of failure (mitigated by multi-node ID service, e.g., Snowflake IDs).

### Data Model

```sql
CREATE TABLE urls (
    short_code  VARCHAR(10) PRIMARY KEY,
    long_url    VARCHAR(2048) NOT NULL,
    user_id     BIGINT,
    created_at  TIMESTAMP NOT NULL,
    expires_at  TIMESTAMP,
    is_active   BOOLEAN DEFAULT TRUE
);

-- Deduplication: find existing code for a long URL
CREATE INDEX idx_long_url ON urls (MD5(long_url));
```

### Redirect: 301 vs 302

| Code | Meaning | Cache behaviour | Use when |
|------|---------|----------------|---------|
| **301 Moved Permanently** | Browser caches forever | Browser doesn't hit your server again | Long-lived links; reduces server load |
| **302 Found (Temporary)** | Not cached | Every redirect hits your server | Analytics required; link destination may change |

For analytics, use **302** so every redirect request reaches the server (or use a 301 with a short `Cache-Control: max-age`).

### Architecture

```
[Client] 
  → CDN (serve 301s for very popular short codes)
  → Load Balancer
  → Redirect Service (read-heavy, stateless)
      ├─ Redis Cache (short_code → long_url, TTL: 24h)
      └─ DB Read Replica (cache miss fallback)

[Write Path]
  → API Service
  → ID Generator (Snowflake / Redis counter)
  → DB Primary

[Analytics Path]
  → Redirect Service publishes ClickEvent → Kafka
  → Analytics Consumer → ClickHouse / BigQuery
```

### Handling Expiry

Store `expires_at` in the DB. On redirect:
1. Check Redis cache (includes expiry TTL).
2. If expired → return 410 Gone.
3. Background job: soft-delete expired rows daily.

### Custom Aliases

Allow users to specify their own code (`alias`): store in the same table; validate uniqueness before inserting.

Rate-limit custom alias creation per user to prevent squatting.

## Code Example

```csharp
// ASP.NET Core 8 — URL shortener core: create + redirect

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<UrlDb>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Db")));
builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = builder.Configuration["Redis"]);
builder.Services.AddScoped<UrlService>();

var app = builder.Build();

// ── POST /urls — create short link ───────────────────────────────────
app.MapPost("/urls", async (CreateUrlRequest req, UrlService svc, CancellationToken ct) =>
{
    if (!Uri.TryCreate(req.LongUrl, UriKind.Absolute, out _))
        return Results.BadRequest("Invalid URL");

    var shortCode = await svc.CreateAsync(req.LongUrl, req.Alias, req.ExpiresAt, ct);
    return Results.Created($"/{shortCode}", new { shortCode, shortUrl = $"https://sho.rt/{shortCode}" });
});

// ── GET /{code} — redirect ────────────────────────────────────────────
app.MapGet("/{code}", async (string code, UrlService svc, CancellationToken ct) =>
{
    var longUrl = await svc.ResolveAsync(code, ct);
    if (longUrl is null) return Results.NotFound();

    // 302 redirect to capture analytics; browser doesn't cache permanently
    return Results.Redirect(longUrl, permanent: false);
});

app.Run();

// ── Service ───────────────────────────────────────────────────────────
public sealed class UrlService(UrlDb db, IDistributedCache cache, ILogger<UrlService> log)
{
    private static readonly Base62 _encoder = new();

    public async Task<string> CreateAsync(
        string longUrl, string? alias, DateTime? expiresAt, CancellationToken ct)
    {
        // Deduplication: reuse existing code for same URL (if no alias)
        if (alias is null)
        {
            var existing = await db.Urls
                .Where(u => u.LongUrl == longUrl && u.ExpiresAt == null)
                .Select(u => u.ShortCode)
                .FirstOrDefaultAsync(ct);
            if (existing is not null) return existing;
        }

        var code = alias ?? _encoder.Encode(await db.GetNextIdAsync(ct));

        db.Urls.Add(new UrlEntry
        {
            ShortCode = code,
            LongUrl   = longUrl,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = expiresAt
        });
        await db.SaveChangesAsync(ct);

        await cache.SetStringAsync(code, longUrl,
            new DistributedCacheEntryOptions
            {
                AbsoluteExpiration = expiresAt ?? DateTimeOffset.UtcNow.AddDays(7)
            }, ct);

        return code;
    }

    public async Task<string?> ResolveAsync(string code, CancellationToken ct)
    {
        // L1: Redis cache
        var cached = await cache.GetStringAsync(code, ct);
        if (cached is not null) return cached;

        // L2: DB
        var entry = await db.Urls
            .Where(u => u.ShortCode == code && u.IsActive)
            .FirstOrDefaultAsync(ct);

        if (entry is null) return null;
        if (entry.ExpiresAt.HasValue && entry.ExpiresAt < DateTime.UtcNow)
        {
            await cache.SetStringAsync(code, "",    // cache the "expired" state
                new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5) }, ct);
            return null;
        }

        await cache.SetStringAsync(code, entry.LongUrl,
            new DistributedCacheEntryOptions
            {
                AbsoluteExpiration = entry.ExpiresAt.HasValue
                    ? new DateTimeOffset(entry.ExpiresAt.Value) : DateTimeOffset.UtcNow.AddDays(1)
            }, ct);

        return entry.LongUrl;
    }
}

// ── Helpers ───────────────────────────────────────────────────────────
public class UrlDb(DbContextOptions<UrlDb> opts) : DbContext(opts)
{
    public DbSet<UrlEntry> Urls => Set<UrlEntry>();
    public async Task<long> GetNextIdAsync(CancellationToken ct)
        => await Database.ExecuteSqlRawAsync("SELECT NEXT VALUE FOR dbo.UrlIdSeq", ct);
}

public class UrlEntry
{
    public string ShortCode { get; set; } = "";
    public string LongUrl   { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool IsActive { get; set; } = true;
}

public sealed class Base62
{
    private const string Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    public string Encode(long num)
    {
        var sb = new System.Text.StringBuilder();
        do { sb.Insert(0, Alphabet[(int)(num % 62)]); num /= 62; } while (num > 0);
        return sb.ToString().PadLeft(7, '0');
    }
}

record CreateUrlRequest(string LongUrl, string? Alias, DateTime? ExpiresAt);
```

## Common Follow-up Questions

- How would you prevent users from creating short links pointing to malicious or phishing URLs?
- How does the ID generation service avoid a single point of failure (Snowflake IDs, Zookeeper ranges)?
- How do you handle the case where a very popular short link's destination changes (e.g., a news article URL changes)?
- How would you design the analytics pipeline to count 10B clicks/day with sub-second dashboard updates?
- How do you implement rate limiting on the URL creation endpoint to prevent abuse?
- How would you support link preview (OG metadata pass-through) without breaking the redirect flow?

## Common Mistakes / Pitfalls

- **Always using 301 redirects**: browsers cache 301 permanently. If the destination changes or the link expires, users with a cached 301 still get directed to the old URL. Use 302 or short-TTL `Cache-Control` on 301.
- **No collision detection for hash-based codes**: two different long URLs can hash to the same 7-character prefix. Without a collision check and retry, one URL silently overwrites the other.
- **No input validation**: storing arbitrary strings as long URLs allows XSS (storing `javascript:alert()`) and open redirect attacks. Validate that the long URL is a valid HTTP/HTTPS URL.
- **Storing full analytics in the redirect path**: if every redirect writes a click record to the DB synchronously, the DB becomes the bottleneck for 115K req/s. Publish click events to a queue and process asynchronously.
- **No rate limiting on the creation endpoint**: without limits, a single attacker can exhaust your 3.5T code space by creating billions of short links. Rate-limit by IP and API key.
- **Not handling expired links with a cached negative**: if a link expires and you don't cache the "not found" state in Redis, every request for the expired link hits the DB. Cache expiry state with a short TTL.

## References

- [System design — URL shortener walkthrough (ByteByteGo)](https://bytebytego.com/courses/system-design-interview/design-a-url-shortener) (verify URL)
- [Base62 encoding — Wikipedia](https://en.wikipedia.org/wiki/Base62)
- [See: database-sharding.md](./database-sharding.md) — sharding the URL store at scale
- [See: caching-strategies-overview.md](./caching-strategies-overview.md) — caching the redirect lookup
- [See: rate-limiting-concepts.md](./rate-limiting-concepts.md) — protecting the creation endpoint
