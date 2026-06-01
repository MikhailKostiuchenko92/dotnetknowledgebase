# Environment Configuration in ASP.NET Core

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟢 Junior
**Tags:** `environment`, `configuration`, `appsettings`, `IWebHostEnvironment`, `ASPNETCORE_ENVIRONMENT`

## Question

> How does ASP.NET Core determine the current environment, and how does `appsettings.{env}.json` layering work?

## Short Answer

ASP.NET Core reads the `ASPNETCORE_ENVIRONMENT` environment variable (defaulting to `"Production"` when absent) and exposes it via `IWebHostEnvironment.EnvironmentName`. The configuration system automatically layers `appsettings.json` as a base and then merges `appsettings.{EnvironmentName}.json` on top, with later sources winning — so environment-specific files override shared defaults.

## Detailed Explanation

### How the environment is resolved

The framework reads environment names from these sources in priority order (highest first):

| Source | Example |
|---|---|
| `ASPNETCORE_ENVIRONMENT` env var | `ASPNETCORE_ENVIRONMENT=Staging` |
| `DOTNET_ENVIRONMENT` env var | `DOTNET_ENVIRONMENT=Staging` |
| `WebApplicationOptions.EnvironmentName` | set in code |
| Default | `"Production"` |

`ASPNETCORE_ENVIRONMENT` is ASP.NET Core-specific. `DOTNET_ENVIRONMENT` affects all `IHost`-based apps. When both are set, `ASPNETCORE_ENVIRONMENT` wins for web applications.

### Built-in environment name helpers

`IWebHostEnvironment` (and `IHostEnvironment`) exposes:

```csharp
env.EnvironmentName        // raw string
env.IsDevelopment()        // EnvironmentName == "Development" (case-insensitive)
env.IsStaging()            // "Staging"
env.IsProduction()         // "Production"
env.IsEnvironment("UAT")   // custom name
```

> **Tip:** Environment names are **case-insensitive** and can be any string — `"UAT"`, `"LoadTest"`, etc. There is nothing special about the three built-in names except that `IsDevelopment()` disables some security features (e.g., HSTS).

### Configuration layering order (default `CreateDefaultBuilder`)

Providers are added in this order; later additions override earlier ones for the same key:

1. `appsettings.json` (required: false since .NET 6)
2. `appsettings.{EnvironmentName}.json` (optional)
3. [Development only] User Secrets (`secrets.json`)
4. Environment variables (prefix `ASPNETCORE_`)
5. Command-line arguments

Keys in `appsettings.Development.json` override the same keys in `appsettings.json`. Environment variables override both JSON files. This means **you never need to duplicate keys** — only put overrides in environment-specific files.

### Key naming and nesting

Nested JSON maps to `:` delimiters:

```json
// appsettings.json
{ "Database": { "Host": "localhost" } }
```

```
config["Database:Host"]  // "localhost"
```

Environment variables use `__` (double underscore) as the hierarchy separator, which maps to `:`:

```
DATABASE__HOST=prod-db.example.com  // overrides Database:Host
```

### `IOptions<T>` binding

Bind a section to a strongly-typed class:

```csharp
builder.Services.Configure<DatabaseOptions>(
    builder.Configuration.GetSection("Database"));
```

See [configuration-system.md](configuration-system.md) for `IOptions<T>` vs `IOptionsSnapshot<T>` vs `IOptionsMonitor<T>`.

## Code Example

```csharp
// Program.cs — reading environment and conditional middleware

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// IWebHostEnvironment is available via app.Environment
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();  // detailed error pages only in dev
}
else
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
}

app.MapGet("/env", (IWebHostEnvironment env) =>
    Results.Ok(new { env.EnvironmentName, env.ContentRootPath }));

app.Run();
```

```json
// appsettings.json (base — all environments)
{
  "Logging": { "LogLevel": { "Default": "Warning" } },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=prod-db;Database=MyApp;..."
  }
}
```

```json
// appsettings.Development.json (overrides for local dev only)
{
  "Logging": { "LogLevel": { "Default": "Debug", "Microsoft.AspNetCore": "Information" } },
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=MyAppDev;Trusted_Connection=true"
  }
}
```

```csharp
// Accessing configuration directly
var connStr = builder.Configuration.GetConnectionString("DefaultConnection");
// In Development: "Server=localhost;..." 
// In Production: "Server=prod-db;..."
```

## Common Follow-up Questions

- How do you add a completely custom environment (e.g., `"UAT"`) and conditionally register services for it?
- What is the difference between `ASPNETCORE_ENVIRONMENT` and `DOTNET_ENVIRONMENT`?
- How do you prevent `appsettings.Development.json` from being deployed to production (`.gitignore`, csproj settings)?
- How do you access `IWebHostEnvironment` inside a class that is resolved from DI (not `Program.cs`)?
- How does the configuration system behave in Docker containers where environment variables drive all config?

## Common Mistakes / Pitfalls

- **Forgetting to set `ASPNETCORE_ENVIRONMENT`** on the server — the app silently runs in `"Production"` mode, hiding developer exception pages but also suppressing dev-only services.
- **Putting secrets in `appsettings.Development.json` and committing it** — use User Secrets or environment variables for anything sensitive.
- **Expecting `appsettings.{env}.json` to fully replace the base file** — it merges; keys not present in the environment file still come from `appsettings.json`.
- **Using `ASPNETCORE_` prefix for general .NET config** — this prefix is reserved for ASP.NET Core configuration keys. Use `DOTNET_` or no prefix for generic host settings.
- **Treating environment names as case-sensitive** — they are compared case-insensitively, so `"development"` and `"Development"` are the same.

## References

- [Microsoft Learn — Environments in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/environments?view=aspnetcore-8.0)
- [Microsoft Learn — Configuration in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/configuration/?view=aspnetcore-8.0)
- [Andrew Lock — Exploring the environment configuration in ASP.NET Core](https://andrewlock.net/tag/configuration/) (verify URL)
- [Microsoft Learn — Safe storage of app secrets in development](https://learn.microsoft.com/aspnet/core/security/app-secrets?view=aspnetcore-8.0)
