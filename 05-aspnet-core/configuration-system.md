# Configuration System in ASP.NET Core

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟡 Middle
**Tags:** `configuration`, `IConfiguration`, `IOptions`, `appsettings`, `providers`

## Question

> How does the ASP.NET Core configuration system work? Explain the provider chain and how `IOptions<T>` binding is used.

## Short Answer

The configuration system stacks multiple `IConfigurationProvider` implementations into a chain, where later providers override earlier ones for the same key. The default setup layers JSON files, environment variables, and command-line args. `IOptions<T>` binds a named configuration section to a strongly-typed class and surfaces it via DI — with `IOptions<T>`, `IOptionsSnapshot<T>`, and `IOptionsMonitor<T>` offering different lifetime and reload semantics.

## Detailed Explanation

### Provider chain (default ordering in `WebApplication.CreateBuilder`)

| Priority (low → high) | Provider | Notes |
|---|---|---|
| 1 | `appsettings.json` | Base values |
| 2 | `appsettings.{env}.json` | Environment overrides |
| 3 | User Secrets | Development only |
| 4 | Environment variables | `ASPNETCORE_` prefix stripped |
| 5 | Command-line arguments | `--Key Value` |

The **last provider wins** for any key. You can add your own providers (Azure Key Vault, database, HashiCorp Vault) at any position.

### Key naming rules

- Nested sections use `:` separator: `"Database:Host"`.
- Environment variable equivalent: `DATABASE__HOST` (double underscore → colon).
- Array indices: `"Logging:LogLevel:0"` or `LOGGING__LOGLEVEL__0`.

### `IConfiguration` — raw access

```csharp
string? host = config["Database:Host"];
string? port = config.GetValue<int>("Database:Port", defaultValue: 5432).ToString();
IConfigurationSection section = config.GetSection("Database");
```

Raw `IConfiguration` access is stringly-typed and loses type safety. Prefer `IOptions<T>` for strongly-typed access.

### `IOptions<T>` — the three variants

| Interface | Lifetime | Reloads | Use case |
|---|---|---|---|
| `IOptions<T>` | Singleton | ❌ Never | Values read once at startup; simplest |
| `IOptionsSnapshot<T>` | Scoped | ✅ Per request | Web app where config can change between requests |
| `IOptionsMonitor<T>` | Singleton | ✅ On change event | Background services, long-lived singletons |

### Validation on startup (.NET 7+)

```csharp
builder.Services
    .AddOptions<DatabaseOptions>()
    .BindConfiguration("Database")        // binds section
    .ValidateDataAnnotations()            // validates [Required], [Range] etc.
    .ValidateOnStart();                   // fail fast at host start, not first use
```

Without `ValidateOnStart`, validation errors only surface when the `IOptions<T>` is first resolved, which could be during a request.

### Named options

```csharp
// Register two sets of options with different names
builder.Services.Configure<SmtpOptions>("Primary", config.GetSection("Smtp:Primary"));
builder.Services.Configure<SmtpOptions>("Backup",  config.GetSection("Smtp:Backup"));

// Resolve named option
public class EmailSender(IOptionsMonitor<SmtpOptions> opts)
{
    public void Send() => opts.Get("Primary").Host; // uses named instance
}
```

### Adding custom providers

```csharp
builder.Configuration.AddJsonFile("extra.json", optional: true, reloadOnChange: true);
builder.Configuration.AddEnvironmentVariables(prefix: "MYAPP_");
builder.Configuration.AddAzureKeyVault(new Uri("https://..."), new DefaultAzureCredential());
```

## Code Example

```csharp
// DatabaseOptions.cs
namespace MyApp.Options;

public sealed class DatabaseOptions
{
    [Required]
    public string Host { get; init; } = string.Empty;

    [Range(1, 65535)]
    public int Port { get; init; } = 5432;

    [Required]
    public string Name { get; init; } = string.Empty;
}
```

```json
// appsettings.json
{
  "Database": {
    "Host": "localhost",
    "Port": 5432,
    "Name": "myapp"
  }
}
```

```csharp
// Program.cs
builder.Services
    .AddOptions<DatabaseOptions>()
    .BindConfiguration("Database")
    .ValidateDataAnnotations()
    .ValidateOnStart();

// In a service
public class UserRepository(IOptions<DatabaseOptions> opts)
{
    private readonly DatabaseOptions _db = opts.Value;

    public string ConnectionString =>
        $"Host={_db.Host};Port={_db.Port};Database={_db.Name}";
}
```

```csharp
// IOptionsMonitor in a background service (reloads on file change)
public class NotificationWorker(IOptionsMonitor<SmtpOptions> smtpOpts) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        smtpOpts.OnChange(opts => Console.WriteLine($"SMTP config changed: {opts.Host}"));

        while (!stoppingToken.IsCancellationRequested)
        {
            var current = smtpOpts.CurrentValue; // always latest
            await SendNotificationsAsync(current, stoppingToken);
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

## Common Follow-up Questions

- When would you choose `IOptionsMonitor<T>` over `IOptionsSnapshot<T>` for a web request handler?
- How do you unit-test a class that depends on `IOptions<T>`?
- How do you securely inject secrets (passwords, API keys) without committing them to source control?
- What happens if a required configuration key is missing and you've called `ValidateOnStart()`?
- How do you add an Azure Key Vault configuration provider in production?

## Common Mistakes / Pitfalls

- **Injecting `IOptions<T>` into a `Singleton` and expecting it to reflect changes** — `IOptions<T>.Value` is computed once. Use `IOptionsMonitor<T>` for singletons that must react to changes.
- **Forgetting `ValidateOnStart()`** — without it, a misconfigured option only fails when the option is first resolved, possibly mid-request in production.
- **Using the same environment variable prefix inconsistently** — `ASPNETCORE_` keys are added automatically; adding them again with `AddEnvironmentVariables("ASPNETCORE_")` causes duplicate/unexpected overrides.
- **Exposing raw `IConfiguration` across the whole app** — it's a stringly-typed bag. Prefer binding sections to typed options and injecting those.
- **Not calling `.BindConfiguration()` and manually using `.Configure<T>(config.GetSection(...))` without validation** — you lose the fluent validation pipeline.

## References

- [Microsoft Learn — Configuration in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/configuration/?view=aspnetcore-8.0)
- [Microsoft Learn — Options pattern in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/configuration/options?view=aspnetcore-8.0)
- [Andrew Lock — Strongly typed configuration with IOptions](https://andrewlock.net/tag/configuration/) (verify URL)
- [Microsoft Learn — Validate options with IValidateOptions](https://learn.microsoft.com/dotnet/core/extensions/options-validation)
- [Microsoft — ConfigurationManager source (GitHub)](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Configuration/src/ConfigurationManager.cs)
