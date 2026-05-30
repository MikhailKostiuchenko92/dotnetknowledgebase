# Graceful Degradation Patterns

**Category:** System Design / Observability
**Difficulty:** Middle
**Tags:** `graceful-degradation`, `fallback`, `feature-flags`, `stale-data`, `timeouts`, `resilience`

## Question

> What is graceful degradation and how do you implement it in a .NET microservice? What patterns exist for serving degraded but functional responses when a dependency fails?

- When should you return stale data vs an error?
- How do feature flags support graceful degradation?

## Short Answer

Graceful degradation means the system continues serving a useful (though possibly reduced) response when a dependency fails, rather than propagating errors to the user. Common patterns include: **stale cache fallback** (serve cached data when the source is down), **default/empty responses** (show an empty recommendations list rather than an error), **feature flags** (disable non-critical features when their dependency is degraded), and **timeouts with fallback** (if the recommendation service doesn't respond in 100 ms, return an empty list). The key principle: distinguish between **critical dependencies** (must succeed — payment gateway, auth) and **non-critical ones** (can degrade — recommendations, analytics).

## Detailed Explanation

### Critical vs Non-Critical Dependencies

Before applying degradation, classify every dependency:

| Dependency | Critical? | Degradation Strategy |
|------------|:--------:|---------------------|
| Auth service | ✅ | Fail fast — no degraded auth |
| Payment gateway | ✅ | Fail fast — no degraded payments |
| Product catalogue | ✅ | Stale cache (very recent data acceptable) |
| Recommendations engine | ❌ | Return empty list / "popular items" |
| Analytics event tracking | ❌ | Drop silently; log locally |
| Email notification | ❌ | Queue for retry; acknowledge immediately |
| Search service | ❌ | Fall back to DB full-text search |

> **Warning:** Applying graceful degradation to critical dependencies creates "security by vibes". If auth is unavailable and you let users through anyway, you've made a security decision, not a resilience decision. Fail fast on critical paths.

### Pattern 1: Stale Cache Fallback

Serve the last known-good value from cache when the source is unreachable.

```csharp
public sealed class ProductService(IProductRepository repo, IDistributedCache cache)
{
    private static readonly TimeSpan CacheTtl    = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan StaleTtl    = TimeSpan.FromHours(1); // extended on degradation

    public async Task<Product?> GetAsync(Guid productId, CancellationToken ct)
    {
        var cacheKey = $"product:{productId}";

        // Try fresh data first
        try
        {
            var product = await repo.GetAsync(productId, ct);
            await cache.SetAsync(cacheKey,
                JsonSerializer.SerializeToUtf8Bytes(product),
                new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = CacheTtl },
                ct);
            return product;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Repository down — serve stale cache
            var stale = await cache.GetAsync(cacheKey, ct);
            if (stale is not null)
            {
                // Extend TTL so stale data survives the outage
                await cache.RefreshAsync(cacheKey, ct);
                return JsonSerializer.Deserialize<Product>(stale);
            }

            // No stale data either — return null (caller decides: empty UI or error)
            return null;
        }
    }
}
```

### Pattern 2: Default / Empty Fallback

Return a safe default when the dependency fails:

```csharp
public async Task<IReadOnlyList<Product>> GetRecommendationsAsync(
    Guid userId, CancellationToken ct)
{
    try
    {
        return await _recommendationsService
            .GetForUserAsync(userId, ct)
            .WaitAsync(TimeSpan.FromMilliseconds(150), ct); // hard timeout
    }
    catch
    {
        // Degrade: return pre-computed "popular items" list instead of personalised recommendations
        return _popularItemsCache.GetTopN(10);
    }
}
```

### Pattern 3: Feature Flags for Dependency Control

Feature flags let you disable non-critical features at runtime without deployment:

```csharp
public async Task<HomePageViewModel> BuildHomePageAsync(
    Guid userId, CancellationToken ct)
{
    var products = await _catalogue.GetFeaturedAsync(ct); // critical — no fallback

    // Non-critical feature: disable at runtime if recommendations service is degraded
    IReadOnlyList<Product> recommendations = [];
    if (await _featureManager.IsEnabledAsync("recommendations-enabled"))
    {
        recommendations = await GetRecommendationsAsync(userId, ct);
    }

    // Non-critical: disable if analytics is overloaded
    if (await _featureManager.IsEnabledAsync("page-analytics-tracking"))
    {
        _ = _analytics.TrackPageViewAsync(userId, "home", ct); // fire-and-forget
    }

    return new HomePageViewModel(products, recommendations);
}
```

Feature flag backends: Azure App Configuration, LaunchDarkly, Unleash. `Microsoft.FeatureManagement` provides the .NET abstraction.

### Pattern 4: Timeout + Polly Fallback Pipeline

```csharp
// Polly v8 — timeout with fallback in a single pipeline
var pipeline = new ResiliencePipelineBuilder<IReadOnlyList<Product>>()
    .AddFallback(new FallbackStrategyOptions<IReadOnlyList<Product>>
    {
        ShouldHandle = new PredicateBuilder<IReadOnlyList<Product>>()
            .Handle<TimeoutRejectedException>()
            .Handle<HttpRequestException>()
            .Handle<BrokenCircuitException>(),
        FallbackAction = _ =>
            ValueTask.FromResult<IReadOnlyList<Product>>(_popularItemsCache.GetTopN(10)),
        OnFallback = args =>
        {
            _logger.LogWarning("Recommendations degraded, returning popular items: {Reason}",
                args.Outcome.Exception?.Message);
            return ValueTask.CompletedTask;
        },
    })
    .AddCircuitBreaker(new CircuitBreakerStrategyOptions<IReadOnlyList<Product>>
    {
        FailureRatio      = 0.5,
        SamplingDuration  = TimeSpan.FromSeconds(30),
        MinimumThroughput = 5,
        BreakDuration     = TimeSpan.FromSeconds(20),
    })
    .AddTimeout(TimeSpan.FromMilliseconds(150))
    .Build();

// Usage
var recommendations = await pipeline.ExecuteAsync(
    ct => new ValueTask<IReadOnlyList<Product>>(
        await _recommendationsClient.GetForUserAsync(userId, ct)), ct);
```

### Pattern 5: Shedding Non-Critical Work Under Load

When the service itself is overloaded (not just a dependency), shed non-critical work:

```csharp
// Middleware: under high load, skip analytics tracking
app.Use(async (ctx, next) =>
{
    var isHighLoad = _loadMonitor.CurrentQueueDepth > 1000;

    if (isHighLoad && ctx.Request.Path.StartsWithSegments("/api/analytics"))
    {
        ctx.Response.StatusCode = 503;
        return; // shed analytics traffic entirely
    }

    await next(ctx);
});
```

### Communicating Degradation to Clients

Clients benefit from knowing the response is degraded:

```http
HTTP/1.1 200 OK
X-Response-Status: degraded
X-Degraded-Reason: recommendations-service-unavailable
Cache-Control: no-store

{"products": [...], "recommendations": [], "degraded": true}
```

Mobile/web clients can display a subtle "personalised recommendations unavailable" notice rather than an error.

## Common Follow-up Questions

- How do you test graceful degradation behaviour in integration tests without spinning up a full dependency failure?
- When does stale data become worse than an error — e.g., for a price check on an e-commerce checkout?
- How do you implement a "dark launch" of a new dependency where failures don't affect the main response?
- How does backpressure differ from graceful degradation?
- What circuit breaker state transitions signal to a feature flag system that a feature should be automatically disabled?

## Common Mistakes / Pitfalls

- **Degrading critical dependencies**: graceful degradation on auth, payments, or data writes is a correctness bug, not a resilience feature.
- **Silent degradation with no observability**: if the system degrades and nobody logs/metrics it, you'll never know the dependency has been down for 3 days.
- **Stale data with no expiry**: serving stale data indefinitely (no TTL extension limit) can mislead users with severely outdated information — set a maximum stale age.
- **Fallback that itself depends on the failed service**: `GetRecommendationsAsync` falls back to `GetPopularItemsAsync`, which also calls the same recommendations service.
- **Applying a timeout without a fallback**: timeout without fallback just changes a slow error into a fast error; the user experience is equally bad. Always pair a timeout with a meaningful fallback.
- **Feature flags that are never re-enabled**: teams disable a feature during an incident and forget to re-enable it; add automated re-enable logic or review alerts.

## References

- [Polly Fallback — Polly docs](https://www.pollydocs.org/strategies/fallback.html)
- [Microsoft.FeatureManagement — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-app-configuration/use-feature-flags-dotnet-core)
- [Release It! — Michael Nygard (book)](https://pragprog.com/titles/mnee2/release-it-second-edition/)
- [See: circuit-breaker-pattern.md](./circuit-breaker-pattern.md)
- [See: throttling-vs-backpressure.md](./throttling-vs-backpressure.md)
