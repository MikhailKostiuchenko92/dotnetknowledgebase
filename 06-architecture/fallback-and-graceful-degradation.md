# Fallback and Graceful Degradation

**Category:** Architecture / Resilience
**Difficulty:** 🟡 Middle
**Tags:** `fallback`, `graceful-degradation`, `stale-cache`, `feature-flags`, `Polly`, `partial-failure`, `static-fallback`

## Question

> What is the fallback resilience pattern, and how does it differ from graceful degradation? Walk through examples of static fallback, stale cache fallback, and feature-flag-based degradation — when to use each.

## Short Answer

**Fallback** is a resilience strategy that returns an alternative response when the primary path fails — implemented as the last layer in a Polly pipeline. **Graceful degradation** is the broader architectural principle: the system remains partially functional under failure, providing reduced but useful functionality rather than an outright error. Examples: product recommendations fail → return "popular items" (static fallback), inventory service times out → return last-known stock levels (stale cache), payment processor circuit is open → disable "Buy Now" button via feature flag (degraded mode). Every fallback is a **business decision** — must be agreed upon with stakeholders.

## Detailed Explanation

### Static Fallback

```
Use when: Dependency provides non-critical enhancement; any default is acceptable
Examples:
  - Recommendation service down → return hardcoded "popular items" list
  - Currency exchange service down → return yesterday's rates
  - User preferences service down → return application defaults

Characteristics:
  - Simple to implement
  - No dependency on secondary services
  - Data may be stale or impersonal
  - Best for low-stakes, non-critical features
```

```csharp
// Polly v8 fallback behavior
var pipeline = new ResiliencePipelineBuilder<List<ProductDto>>()
    .AddFallback(new FallbackStrategyOptions<List<ProductDto>>
    {
        FallbackAction = args =>
        {
            // Return empty list — consumer handles missing recommendations gracefully
            args.Context.ServiceProvider
                .GetService<ILogger>()
                ?.LogWarning("Recommendation service unavailable, using static fallback");
            return Outcome.FromResultAsValueTask(new List<ProductDto>(_popularItems));
        },
        ShouldHandle = new PredicateBuilder<List<ProductDto>>()
            .Handle<HttpRequestException>()
            .Handle<BrokenCircuitException>()
            .Handle<TimeoutRejectedException>()
    })
    .Build();

private static readonly List<ProductDto> _popularItems = new()
{
    new(1, "Bestseller Widget", 29.99m),
    new(2, "Popular Gadget", 49.99m),
};
```

### Stale Cache Fallback

```
Use when: The response changes slowly; serving slightly stale data is acceptable
Examples:
  - Product catalog: shows last-cached prices if pricing service is down
  - Stock levels: shows last-known inventory if warehouse service times out
  - User profiles: shows cached profile if profile service is unavailable

Characteristics:
  - Requires cache infrastructure (IDistributedCache, Redis)
  - Need to track cache age (TTL vs "stale-while-revalidate" pattern)
  - Consumer must accept that data may be outdated
  - Better UX than hard error for non-critical data
```

```csharp
public class ProductCatalogService(
    IProductApiClient apiClient,
    IDistributedCache cache,
    ILogger<ProductCatalogService> log)
{
    private const string CacheKey = "product:catalog:all";
    private static readonly TimeSpan _cacheTtl = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan _staleGrace = TimeSpan.FromHours(1);

    public async Task<List<ProductDto>> GetCatalogAsync(CancellationToken ct)
    {
        try
        {
            var products = await apiClient.GetAllAsync(ct);

            // Cache with TTL — also update stale backup
            var bytes = JsonSerializer.SerializeToUtf8Bytes(products);
            await cache.SetAsync(CacheKey, bytes,
                new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = _cacheTtl }, ct);
            await cache.SetAsync($"{CacheKey}:stale", bytes,
                new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = _staleGrace }, ct);

            return products;
        }
        catch (Exception ex) when (ex is HttpRequestException or BrokenCircuitException or TimeoutRejectedException)
        {
            log.LogWarning(ex, "Product API unavailable — attempting stale cache fallback");

            var staleBytes = await cache.GetAsync($"{CacheKey}:stale", ct);
            if (staleBytes is not null)
                return JsonSerializer.Deserialize<List<ProductDto>>(staleBytes)!;

            log.LogError("Stale cache also unavailable — returning empty catalog");
            return new List<ProductDto>();
        }
    }
}
```

### Feature Flag Degradation

```
Use when: A feature can be completely disabled rather than returning degraded data
Examples:
  - Recommendations panel: hidden when service is down (no content is better than stale)
  - "Pay Later" option: disabled when credit check service is unavailable
  - Advanced search filters: disabled when Elasticsearch is unhealthy
  - Real-time pricing: degraded to "call for price" when pricing engine is down

Characteristics:
  - Most user-friendly — UI adapts to system capabilities
  - Requires feature flag infrastructure (LaunchDarkly, Azure App Config, Flagsmith)
  - Frontend must react to flag state changes
  - Allows proactive degradation before full failure
```

```csharp
// ASP.NET Core: expose degradation flags to frontend
public class HealthCapabilityController(
    IInventoryClient inventory,
    ICircuitBreakerRegistry cbRegistry,
    IFeatureManager featureManager) : ControllerBase
{
    [HttpGet("api/capabilities")]
    public async Task<CapabilitiesDto> GetCapabilities(CancellationToken ct)
    {
        return new CapabilitiesDto
        {
            // Real-time inventory check: use circuit breaker state as proxy for availability
            RealtimeInventory = cbRegistry.GetCircuitState("inventory") == CircuitState.Closed,
            Recommendations    = await featureManager.IsEnabledAsync("Recommendations", ct),
            PayLater           = await featureManager.IsEnabledAsync("PayLater", ct)
        };
    }
}

public record CapabilitiesDto(bool RealtimeInventory, bool Recommendations, bool PayLater);
```

### When to Use Each

| Scenario | Strategy | Reason |
|----------|----------|--------|
| Non-critical feature (recs) | Static or feature-flag hide | Any default acceptable |
| Core data that changes slowly | Stale cache | Stale > error |
| Core feature that can't degrade | Retry + CB + fail | Can't fake a payment |
| Risky slow dependency | Feature flag disable | Prevent degraded UX |
| DB down | Read from read replica | High-availability, not fallback |

## Code Example

```csharp
// Combined: circuit breaker + stale cache fallback + feature flag
public class PricingService(
    IPricingApiClient pricingApi,
    IDistributedCache cache,
    IFeatureManager features,
    ILogger<PricingService> log)
{
    public async Task<PricingResult> GetPricingAsync(int productId, CancellationToken ct)
    {
        // Check if real-time pricing feature is enabled
        if (!await features.IsEnabledAsync("RealtimePricing", ct))
            return GetCatalogPrice(productId); // ← static from config/DB

        try
        {
            var price = await pricingApi.GetPriceAsync(productId, ct);
            await CachePriceAsync(productId, price, ct);
            return price;
        }
        catch (Exception ex) when (ex is BrokenCircuitException or TimeoutRejectedException)
        {
            log.LogWarning("Pricing API degraded — using cached price for product {Id}", productId);
            var cached = await GetCachedPriceAsync(productId, ct);
            return cached ?? GetCatalogPrice(productId); // ← stale then static
        }
    }
}
```

## Common Follow-up Questions

- How do you decide which fallback strategy to use — who makes that decision?
- How do you alert on-call engineers when a fallback is serving responses (vs normal operation)?
- What is the "stale-while-revalidate" HTTP caching strategy and how does it relate to stale cache fallback?
- How do you avoid "invisible degradation" where users don't know the system is in fallback mode?
- How do you test that fallback paths actually work under failure conditions?

## Common Mistakes / Pitfalls

- **Falling back silently without alerting**: a fallback that serves stale data without incrementing a metric or triggering an alert makes the system appear healthy when it's degraded. Always emit signals.
- **Fallback for critical operations**: returning a fake success for a payment or security check as a "fallback" is dangerous. Some operations must fail explicitly rather than degrade.
- **Stale cache without TTL on the stale backup**: a stale cache with infinite TTL will serve data that's days/weeks old after a prolonged outage. Set a maximum staleness window.
- **Feature flags not updated dynamically**: a hard-coded `if (inventoryServiceIsDown)` check in code is not a feature flag — it requires a deployment to toggle. Use a proper feature flag service with dynamic refresh.

## References

- [Fallback pattern — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/fallback) (verify URL)
- [Polly v8 fallback strategy](https://www.thepollyproject.org/)
- [Microsoft.FeatureManagement — Microsoft Docs](https://learn.microsoft.com/en-us/azure/azure-app-configuration/use-feature-flags-dotnet-core)
- [See: resilience-patterns-overview.md](./resilience-patterns-overview.md)
- [See: circuit-breaker-design.md](./circuit-breaker-design.md)
