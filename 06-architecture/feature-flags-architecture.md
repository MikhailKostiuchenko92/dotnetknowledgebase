# Feature Flags Architecture

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🟡 Middle
**Tags:** `feature-flags`, `Microsoft.FeatureManagement`, `trunk-based-development`, `kill-switch`, `LaunchDarkly`, `A/B-testing`

## Question

> What is the feature flag architectural pattern? How does `Microsoft.FeatureManagement` work in .NET, and what patterns enable safe feature rollout — kill switches, canary releases, A/B testing, and trunk-based development?

## Short Answer

Feature flags (feature toggles) decouple code deployment from feature activation — code ships continuously but features are hidden behind flags that can be toggled without deployment. `Microsoft.FeatureManagement` provides a `IFeatureManager` service backed by `appsettings.json`, Azure App Configuration, or custom providers. Patterns: **Kill switch** (disable a feature instantly in production), **Canary release** (gradually roll out to % of users), **A/B testing** (compare two experiences), **Trunk-based development** (merge to main daily, hide incomplete features behind flags).

## Detailed Explanation

### Microsoft.FeatureManagement Setup

```bash
dotnet add package Microsoft.FeatureManagement.AspNetCore
```

```csharp
// Program.cs
builder.Services.AddFeatureManagement();  // ← reads from appsettings.json "FeatureManagement" section
// Or: Azure App Configuration
builder.Services.AddFeatureManagement(builder.Configuration.GetSection("FeatureFlags"));
```

```json
// appsettings.json
{
  "FeatureManagement": {
    "NewCheckoutFlow": true,
    "RecommendationsPanel": false,
    "AiBundleEngine": {
      "EnabledFor": [
        { "Name": "Percentage", "Parameters": { "Value": 20 } }
      ]
    }
  }
}
```

```csharp
// Usage: inject IFeatureManager
public class CheckoutService(IFeatureManager features)
{
    public async Task<CheckoutResult> ProcessAsync(Cart cart, CancellationToken ct)
    {
        if (await features.IsEnabledAsync("NewCheckoutFlow", ct))
            return await _newCheckout.ProcessAsync(cart, ct);

        return await _legacyCheckout.ProcessAsync(cart, ct);
    }
}

// Minimal API: [FeatureGate] attribute
app.MapPost("/checkout", ProcessCheckout)
    .WithMetadata(new FeatureGateAttribute("NewCheckoutFlow"));
// ↑ Returns 404 if "NewCheckoutFlow" is disabled

// Controller: [FeatureGate] attribute
[FeatureGate("RecommendationsPanel")]
[HttpGet("/api/recommendations")]
public Task<List<ProductDto>> GetRecommendations(...) => ...;
```

### Kill Switch Pattern

```csharp
// Kill switch: instantly disable a misbehaving feature without deployment
// Flag is "enabled by default" in code — the flag DISABLES, not enables

// Naming: "Disable*" or check the inverse
if (!await features.IsEnabledAsync("DisablePayLater", ct))
{
    // Show "Pay Later" option
    response.ShowPayLater = true;
}
// When "DisablePayLater" = true: feature hidden; no deployment needed

// Or: configure with dynamic provider (Azure App Config)
// Change flag in Azure Portal → update propagates within seconds
builder.Services.AddAzureAppConfiguration(options =>
    options.Connect(connectionString)
        .UseFeatureFlags(flagOptions =>
            flagOptions.CacheExpirationInterval = TimeSpan.FromSeconds(30)));

app.UseAzureAppConfiguration(); // ← refreshes config on interval
```

### Canary Release (Percentage Rollout)

```csharp
// Roll out to 20% of users initially, increase over time
// appsettings.json:
{
  "FeatureManagement": {
    "AiBundleEngine": {
      "EnabledFor": [
        { "Name": "Percentage", "Parameters": { "Value": 20 } }
      ]
    }
  }
}

// User-targeted rollout (consistent experience per user):
// NuGet: Microsoft.FeatureManagement (TargetingFilter built-in)
{
  "FeatureManagement": {
    "NewDashboard": {
      "EnabledFor": [
        {
          "Name": "Targeting",
          "Parameters": {
            "Audience": {
              "Users": ["alice@example.com"],            // ← specific users (QA, beta)
              "Groups": [{ "Name": "Employees", "RolloutPercentage": 100 }],
              "DefaultRolloutPercentage": 10            // ← 10% of all users
            }
          }
        }
      ]
    }
  }
}

// Set targeting context per request (maps to authenticated user)
services.AddHttpContextAccessor();
services.AddScoped<ITargetingContextAccessor, HttpContextTargetingContextAccessor>();
```

### Trunk-Based Development

```
Traditional: feature branches live for weeks → big merge conflicts
Trunk-based: merge to main DAILY behind feature flags

Workflow:
  Day 1: Add flag "NewPaymentFlow", default OFF
          Merge incomplete payment code (unreachable without flag)
  Day 2–10: Develop daily, always merge to main
  Day 11: Feature complete — enable flag in staging
  Day 12: Enable for 5% in production (canary)
  Day 14: Enable for 100% → remove the flag from code + config

Rule: never leave a flag in code > 30 days — schedule cleanup sprints
```

### LaunchDarkly Integration

```csharp
// External flag service: real-time updates, advanced targeting, A/B testing
// NuGet: LaunchDarkly.ServerSdk

builder.Services.AddSingleton<LdClient>(sp =>
{
    var config = Configuration.Builder(builder.Configuration["LaunchDarkly:SdkKey"]!)
        .Events(Components.SendEvents())
        .Build();
    return new LdClient(config);
});

public class FeatureFlagService(LdClient ldClient) : IFeatureFlagService
{
    public bool IsEnabled(string flagKey, string userId, bool defaultValue = false)
    {
        var context = Context.Builder(userId).Build();
        return ldClient.BoolVariation(flagKey, context, defaultValue);
    }
}
```

## Code Example

```csharp
// Azure App Configuration with dynamic refresh + feature flags
builder.Configuration.AddAzureAppConfiguration(options =>
{
    options.Connect(builder.Configuration["AzureAppConfig:ConnectionString"])
        .UseFeatureFlags(ff => ff.CacheExpirationInterval = TimeSpan.FromSeconds(30));
});

builder.Services.AddAzureAppConfiguration();
builder.Services.AddFeatureManagement();

app.UseAzureAppConfiguration(); // ← refreshes config every 30s without restart
```

## Common Follow-up Questions

- How do you clean up stale feature flags — what process prevents flag accumulation?
- What is the difference between a feature flag and an environment-specific configuration?
- How do you test code paths that are behind a feature flag?
- How do you handle a feature flag that needs to be checked in background services (no HTTP context)?
- What is "flag debt" and how do you manage it?

## Common Mistakes / Pitfalls

- **Never removing flags**: flags left in code indefinitely become "flag debt" — dead code paths that no one understands. Schedule flag cleanup within 30 days of a feature becoming 100% available.
- **Long-lived flags without documentation**: a flag named `FeatureX` without a comment explaining what it toggles, why it exists, and its planned removal date is unmaintainable.
- **Checking flags in the domain layer**: `if (await features.IsEnabledAsync("NewPricing", ct))` inside a domain aggregate couples the domain to an infrastructure service. Flag checks belong in the application or presentation layer.
- **Testing without mocking flags**: tests that hit the real feature flag service are slow and environment-dependent. Use `IFeatureManager` mock or `InMemoryFeatureManager` for unit tests.

## References

- [Microsoft.FeatureManagement documentation](https://learn.microsoft.com/en-us/azure/azure-app-configuration/use-feature-flags-dotnet-core)
- [LaunchDarkly .NET SDK](https://docs.launchdarkly.com/sdk/server-side/dotnet)
- [Feature Toggles — Martin Fowler](https://martinfowler.com/articles/feature-toggles.html) (verify URL)
- [See: cross-cutting-concerns-overview.md](./cross-cutting-concerns-overview.md)
