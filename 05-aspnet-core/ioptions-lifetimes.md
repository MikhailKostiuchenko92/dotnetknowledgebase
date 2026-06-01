# IOptions, IOptionsSnapshot, and IOptionsMonitor

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🟡 Middle
**Tags:** `IOptions`, `IOptionsSnapshot`, `IOptionsMonitor`, `named-options`, `options-reload`

## Question

> What is the difference between `IOptions<T>`, `IOptionsSnapshot<T>`, and `IOptionsMonitor<T>` in ASP.NET Core? When would you use each?

## Short Answer

`IOptions<T>` is a Singleton that reads configuration once at startup and never reloads. `IOptionsSnapshot<T>` is Scoped — it recomputes the value once per request from the current configuration, supporting hot-reload for web request handlers. `IOptionsMonitor<T>` is a Singleton that tracks configuration changes in real time via an `OnChange` callback, suitable for background services and other Singletons that must react to live configuration changes.

## Detailed Explanation

### Comparison at a glance

| | `IOptions<T>` | `IOptionsSnapshot<T>` | `IOptionsMonitor<T>` |
|---|---|---|---|
| DI Lifetime | Singleton | Scoped | Singleton |
| Config reload | ❌ Never | ✅ Per request scope | ✅ On file-system change |
| `OnChange` callback | ❌ | ❌ | ✅ `OnChange(Action<T>)` |
| Can be injected into Singleton | ✅ | ❌ (captive dep) | ✅ |
| Access pattern | `.Value` | `.Value` | `.CurrentValue` |
| Named options | `.Get(name)` | `.Get(name)` | `.Get(name)` |

### `IOptions<T>` — startup-time snapshot

```csharp
public class EmailService(IOptions<SmtpOptions> opts)
{
    private readonly SmtpOptions _smtp = opts.Value; // computed once, cached

    public void Send(string to, string subject) =>
        SendViaSMTP(_smtp.Host, _smtp.Port, to, subject);
}
```

- `.Value` is computed once (lazy) and then cached for the application lifetime.
- Changing `appsettings.json` at runtime has **no effect** on `IOptions<T>.Value`.
- Safe to inject into Singleton services.

### `IOptionsSnapshot<T>` — per-request reload

```csharp
public class ProductController(IOptionsSnapshot<FeatureFlags> flags) : ControllerBase
{
    [HttpGet("beta")]
    public IActionResult Beta()
    {
        // flags.Value reflects the latest appsettings.json on every request
        if (!flags.Value.BetaEnabled)
            return NotFound();
        return Ok("beta feature");
    }
}
```

- New instance per request scope; re-evaluates configuration from the current provider state.
- Requires `reloadOnChange: true` on the JSON provider (which is the default).
- **Cannot** be injected into a Singleton (it's Scoped — captive dependency).

### `IOptionsMonitor<T>` — reactive Singleton

```csharp
public sealed class NotificationWorker(IOptionsMonitor<SmtpOptions> smtpMonitor)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Register a callback on change
        using var registration = smtpMonitor.OnChange((opts, name) =>
            Console.WriteLine($"SMTP config changed: Host={opts.Host}"));

        while (!stoppingToken.IsCancellationRequested)
        {
            var current = smtpMonitor.CurrentValue; // always latest
            await SendDigestAsync(current, stoppingToken);
            await Task.Delay(TimeSpan.FromMinutes(30), stoppingToken);
        }
    }
}
```

- `CurrentValue` always returns the most recently loaded configuration.
- `OnChange` returns an `IDisposable` — dispose it to unsubscribe.
- Thread-safe: changes are applied atomically.

### Named options

Named options allow multiple configurations of the same type (e.g., primary vs secondary SMTP):

```csharp
builder.Services.Configure<SmtpOptions>("primary", config.GetSection("Smtp:Primary"));
builder.Services.Configure<SmtpOptions>("backup",  config.GetSection("Smtp:Backup"));

// All three interfaces support .Get(name)
IOptions<SmtpOptions>        opts  → opts.Get("primary")
IOptionsSnapshot<SmtpOptions> snap → snap.Get("primary")
IOptionsMonitor<SmtpOptions>  mon  → mon.Get("primary")
```

`IOptions<T>` does not support named via `.Value` directly — `.Value` always returns the unnamed (default) instance; use `.Get(Options.DefaultName)` or `.Get("primary")`.

### How reload works under the hood

`IOptionsSnapshot` and `IOptionsMonitor` subscribe to `IOptionsChangeTokenSource<T>`. The JSON configuration provider calls `IChangeToken.RegisterChangeCallback` on the file watcher, which triggers a cache invalidation in the options cache. The next access to `.Value` or `.CurrentValue` recomputes the bound options object.

> **Note:** Reload requires `reloadOnChange: true` when adding the JSON provider (default in `CreateDefaultBuilder`). In production with Kubernetes `ConfigMaps`, you may need a custom `IOptionsChangeTokenSource` that watches a mounted file.

## Code Example

```csharp
// FeatureFlags.cs
public sealed class FeatureFlags
{
    public bool DarkMode { get; init; }
    public bool BetaCheckout { get; init; }
    public string[] AllowedCountries { get; init; } = [];
}
```

```csharp
// Program.cs
builder.Services
    .AddOptions<FeatureFlags>()
    .BindConfiguration("FeatureFlags")
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

```csharp
// Usage in different contexts

// 1. Controller (Scoped) — use IOptionsSnapshot for hot-reload per request
[ApiController, Route("api/features")]
public class FeaturesController(IOptionsSnapshot<FeatureFlags> flags) : ControllerBase
{
    [HttpGet] public IActionResult Get() => Ok(flags.Value);
}

// 2. Singleton service — use IOptionsMonitor; never IOptionsSnapshot
public sealed class FeatureEvaluator(IOptionsMonitor<FeatureFlags> monitor)
{
    public bool IsEnabled(string featureName) =>
        featureName switch
        {
            "DarkMode"       => monitor.CurrentValue.DarkMode,
            "BetaCheckout"   => monitor.CurrentValue.BetaCheckout,
            _                => false
        };
}

// 3. Startup / factory — use IOptions (value never changes after startup)
public sealed class PaymentGatewayFactory(IOptions<PaymentOptions> opts)
{
    public IPaymentGateway Create() =>
        new StripeGateway(opts.Value.StripeApiKey); // fixed at startup
}
```

## Common Follow-up Questions

- Why can't `IOptionsSnapshot<T>` be injected into a Singleton service?
- How does `IOptionsMonitor<T>` notify listeners on a background thread — is the `OnChange` callback thread-safe?
- How do you test a service that depends on `IOptionsMonitor<T>` — how do you simulate a config change?
- What happens if `appsettings.json` contains invalid values after a live reload — does the app crash?
- How do you use named options with `IOptionsMonitor<T>` in a multi-tenant scenario?

## Common Mistakes / Pitfalls

- **Injecting `IOptionsSnapshot<T>` into a Singleton** — compile-time allowed but runtime captive dependency; the Scoped snapshot is frozen in the Singleton forever.
- **Using `IOptions<T>` when you need hot-reload** — `IOptions<T>.Value` is cached at first access; configuration file changes have no effect.
- **Not disposing the `IOptionsMonitor<T>.OnChange` registration** — the callback holds a reference to the subscriber, potentially preventing garbage collection (memory leak).
- **Assuming `OnChange` fires synchronously** — it fires on a thread pool thread when the file watcher triggers; ensure callbacks are thread-safe.
- **Using `IOptions<T>` for mutable shared state** — `IOptions<T>.Value` is cached; direct mutation of the returned object is shared across all resolvers (it's the same Singleton instance).

## References

- [Microsoft Learn — Options pattern](https://learn.microsoft.com/aspnet/core/fundamentals/configuration/options?view=aspnetcore-8.0)
- [Microsoft Learn — IOptionsMonitor vs IOptionsSnapshot](https://learn.microsoft.com/dotnet/core/extensions/options#options-interfaces)
- [Andrew Lock — Using IOptionsSnapshot and IOptionsMonitor](https://andrewlock.net/tag/options/) (verify URL)
- [Microsoft — OptionsManager source (GitHub)](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Options/src/OptionsManager.cs)
- [Microsoft — OptionsMonitor source (GitHub)](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Options/src/OptionsMonitor.cs)
