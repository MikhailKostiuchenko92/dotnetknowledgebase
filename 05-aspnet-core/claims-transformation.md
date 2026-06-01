# Claims Transformation in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🔴 Senior
**Tags:** `IClaimsTransformation`, `claims-enrichment`, `multi-tenant`, `ClaimsPrincipal`, `post-authentication`

## Question

> What is `IClaimsTransformation` and how do you use it to enrich a user's claims after authentication? What are the performance pitfalls?

## Short Answer

`IClaimsTransformation` is a single-method interface (`TransformAsync`) invoked by the authentication middleware after a successful authentication — it receives the `ClaimsPrincipal` and must return a (possibly enriched) `ClaimsPrincipal`. Use it to add database-sourced claims (roles, permissions, tenant IDs) that aren't embedded in the token. **Pitfall:** it is called on **every** `AuthenticateAsync` invocation, including implicit calls during authorization. Cache the result in the principal itself (marker claim) to avoid redundant DB lookups.

## Detailed Explanation

### When it runs

```
UseAuthentication()
  → IAuthenticationService.AuthenticateAsync()
  → [scheme handler reads cookie/JWT → ClaimsPrincipal]
  → IClaimsTransformation.TransformAsync(principal) ← HERE
  → HttpContext.User = enrichedPrincipal
```

`IClaimsTransformation.TransformAsync` is called every time `AuthenticateAsync` is called for the request, which can happen **multiple times** (once for explicit auth, once during `[Authorize]`, once for policy checks). You must guard against repeated database calls.

### Basic implementation

```csharp
public sealed class PermissionsClaimsTransformer(
    IPermissionService permissionService,
    ILogger<PermissionsClaimsTransformer> logger)
    : IClaimsTransformation
{
    private const string EnrichedMarkerClaimType = "enriched";

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        // Guard: already enriched this request
        if (principal.HasClaim(EnrichedMarkerClaimType, "true"))
            return principal;

        var userId = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId is null) return principal; // unauthenticated passthrough

        logger.LogDebug("Enriching claims for user {UserId}", userId);

        var permissions = await permissionService.GetPermissionsAsync(userId);

        // Clone the identity to avoid mutating the original
        var identity = new ClaimsIdentity(principal.Identity);
        identity.AddClaims(permissions.Select(p => new Claim("permission", p)));
        identity.AddClaim(new Claim(EnrichedMarkerClaimType, "true"));

        return new ClaimsPrincipal(identity);
    }
}
```

### Registration

```csharp
builder.Services.AddTransient<IClaimsTransformation, PermissionsClaimsTransformer>();
```

> **Important:** Only one `IClaimsTransformation` can be registered per DI container. Multiple registrations result in only the last one being used. If you need multiple enrichers, chain them inside a single transformer.

### Multi-tenant claims enrichment

```csharp
public sealed class TenantClaimsTransformer(ITenantResolver resolver) : IClaimsTransformation
{
    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        if (principal.HasClaim("tenantId", string.Empty)) return principal;

        var tenantId = await resolver.ResolveForUserAsync(principal);
        if (tenantId is null) return principal;

        var clone = new ClaimsIdentity(principal.Identity);
        clone.AddClaim(new Claim("tenantId", tenantId));
        clone.AddClaim(new Claim("enriched", "true"));

        return new ClaimsPrincipal(clone);
    }
}
```

### Why clone instead of mutating

`ClaimsIdentity` and `ClaimsPrincipal` are mutable, but mutating the principal directly can cause issues if it's cached (e.g., the JWT handler caches validated tickets). Always create a new `ClaimsIdentity` and wrap it:

```csharp
// ✅ Clone
var identity = new ClaimsIdentity(principal.Identity);
identity.AddClaim(new Claim("role", "admin"));
return new ClaimsPrincipal(identity);

// ❌ Mutate directly (can cause caching issues)
((ClaimsIdentity)principal.Identity!).AddClaim(new Claim("role", "admin"));
return principal;
```

### Performance: caching the enriched principal

For high-traffic APIs, even a fast DB query per request adds up. Use `IMemoryCache` with the user ID as key:

```csharp
public sealed class CachedPermissionsTransformer(
    IPermissionService permissions,
    IMemoryCache cache)
    : IClaimsTransformation
{
    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        if (principal.HasClaim("enriched", "true")) return principal;

        var userId = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId is null) return principal;

        var cached = await cache.GetOrCreateAsync($"permissions:{userId}", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            return await permissions.GetPermissionsAsync(userId);
        });

        var identity = new ClaimsIdentity(principal.Identity);
        identity.AddClaims(cached!.Select(p => new Claim("permission", p)));
        identity.AddClaim(new Claim("enriched", "true"));
        return new ClaimsPrincipal(identity);
    }
}
```

## Code Example

```csharp
// Complete setup with scoped DB access and memory cache anti-stampede guard
builder.Services.AddTransient<IClaimsTransformation, CachedPermissionsTransformer>();
builder.Services.AddMemoryCache();

// In the transformer:
public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
{
    // Fast path: already enriched in this request
    if (principal.HasClaim("enriched", "true")) return principal;

    var userId = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    if (string.IsNullOrEmpty(userId)) return principal;

    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2)); // fail fast
    try
    {
        var perms = await _cache.GetOrCreateAsync($"claims:{userId}", async e =>
        {
            e.SlidingExpiration = TimeSpan.FromMinutes(5);
            return await _permissions.GetAsync(userId, cts.Token);
        });

        var id = new ClaimsIdentity(principal.Identity);
        id.AddClaims(perms?.Select(p => new Claim("permission", p)) ?? []);
        id.AddClaim(new Claim("enriched", "true"));
        return new ClaimsPrincipal(id);
    }
    catch (OperationCanceledException)
    {
        _logger.LogWarning("Claims enrichment timed out for user {UserId}", userId);
        return principal; // degrade gracefully — no enrichment
    }
}
```

## Common Follow-up Questions

- Can you register multiple `IClaimsTransformation` implementations, and if not, how do you chain enrichers?
- How does `IClaimsTransformation` interact with cookie authentication and the `OnValidatePrincipal` event?
- What happens to claims added by `IClaimsTransformation` when the JWT token is refreshed?
- How do you invalidate cached permissions when a user's roles change?
- Is `IClaimsTransformation` called for anonymous (unauthenticated) requests?

## Common Mistakes / Pitfalls

- **Not guarding against repeated calls with a marker claim** — `IClaimsTransformation` is called multiple times per request (once per `AuthenticateAsync` call); without the guard, you make multiple DB roundtrips.
- **Registering as Singleton with a Scoped dependency** — `IClaimsTransformation` should be `Transient` or `Scoped`; registering as `Singleton` and injecting a scoped `DbContext` causes captured dependency issues.
- **Mutating the incoming `ClaimsPrincipal` directly** — clone it with `new ClaimsIdentity(principal.Identity)` to avoid modifying a cached or shared identity.
- **Expecting claims added here to be persisted to the cookie** — `IClaimsTransformation` adds claims in memory for the current request only; they are not written back to the cookie/token. Use `SignInAsync` to persist changes.
- **Blocking on `TransformAsync` result** — the interface is `Task<ClaimsPrincipal>`; always use `await` properly to avoid `GetAwaiter().GetResult()` deadlocks.

## References

- [Microsoft Learn — IClaimsTransformation](https://learn.microsoft.com/aspnet/core/security/authentication/claims?view=aspnetcore-8.0#extend-or-add-custom-claims-using-iclaimstransformation)
- [Microsoft — IClaimsTransformation source](https://github.com/dotnet/aspnetcore/blob/main/src/Security/Authentication/Core/src/IClaimsTransformation.cs)
- [Andrew Lock — Claims transformation in depth](https://andrewlock.net/tag/claims-transformation/) (verify URL)
