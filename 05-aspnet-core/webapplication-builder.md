# WebApplication.CreateBuilder — Minimal Hosting Model

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟢 Junior
**Tags:** `hosting`, `minimal-api`, `program-cs`, `webapplication`, `bootstrap`

## Question

> What is `WebApplication.CreateBuilder`, and how does the minimal hosting model introduced in .NET 6 differ from the older `Startup`-class model?

## Short Answer

`WebApplication.CreateBuilder` creates a pre-configured builder that wires up Kestrel, the DI container, logging, and configuration in a single call, letting you register services and configure the pipeline directly in `Program.cs` without a separate `Startup` class. It replaced the `IWebHostBuilder` + `Startup` split introduced in ASP.NET Core 1.x, reducing boilerplate and making the entry point easier to read and test.

## Detailed Explanation

### The old model (ASP.NET Core 1–5)

Before .NET 6, the application bootstrap required two classes:

- **`Program.cs`** — creates the host via `Host.CreateDefaultBuilder().ConfigureWebHostDefaults(...)`.
- **`Startup.cs`** — declares `ConfigureServices(IServiceCollection)` and `Configure(IApplicationBuilder, ...)` in separate methods.

The split was intentional (testability, separation of concerns) but added ceremony. `IStartupFilter` and `IHostingStartup` were needed for library authors to hook into the pipeline without touching user code.

### The minimal hosting model (.NET 6+)

`WebApplication.CreateBuilder(args)` returns a `WebApplicationBuilder` that combines both concerns:

```
WebApplicationBuilder
├── Services          → IServiceCollection  (replaces ConfigureServices)
├── Configuration     → IConfigurationManager (extends IConfiguration)
├── Logging           → ILoggingBuilder
├── Host              → IHostBuilder (for generic host settings)
├── WebHost           → IWebHostBuilder (Kestrel, IIS settings)
└── Environment       → IWebHostEnvironment
```

Calling `builder.Build()` produces a `WebApplication` that implements both `IApplicationBuilder` and `IEndpointRouteBuilder`, so middleware and routes are registered on the same object.

### Default conventions wired up by `CreateDefaultBuilder` (still applies internally)

| Feature | Provider |
|---|---|
| Configuration | `appsettings.json`, `appsettings.{env}.json`, environment variables, command-line args, User Secrets (dev) |
| Logging | Console, Debug, EventSource, EventLog (Windows) |
| DI container | `Microsoft.Extensions.DependencyInjection` |
| HTTP server | Kestrel (cross-platform) with IIS in-process integration |

### When to still use the Generic Host directly

Use `Host.CreateDefaultBuilder()` (without `ConfigureWebHostDefaults`) when building a **pure background-worker service** with no HTTP. For everything HTTP-facing, `WebApplication.CreateBuilder` is preferred.

### `WebApplicationOptions` — custom bootstrap

```csharp
var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = Directory.GetCurrentDirectory(),
    EnvironmentName = "Staging",
    ApplicationName = "MyApp"
});
```

> **Warning:** Avoid calling `builder.Host.ConfigureAppConfiguration(...)` *and* `builder.Configuration.AddJsonFile(...)` on the same builder — they both affect the same `IConfigurationManager` and can cause duplicate providers.

### `WebApplication` vs `IApplicationBuilder`

`WebApplication.Use*` methods are inherited from `IApplicationBuilder`. The `app.Run()` at the end starts the Kestrel host *and* the entire HTTP pipeline — it blocks until the application shuts down.

## Code Example

```csharp
// Program.cs (.NET 8, file-scoped, minimal hosting model)

var builder = WebApplication.CreateBuilder(args);

// Register services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton<IMyService, MyService>();

// Override configuration (environment variables always win by default)
builder.Configuration.AddJsonFile("extra-config.json", optional: true, reloadOnChange: true);

var app = builder.Build();

// Configure middleware pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

// Minimal API endpoint alongside controllers
app.MapGet("/healthz", () => Results.Ok("healthy"));

app.Run(); // blocks here; handles SIGTERM / Ctrl+C for graceful shutdown
```

### Equivalent old-style (`Startup`) for comparison

```csharp
// Program.cs (old style, .NET 5)
Host.CreateDefaultBuilder(args)
    .ConfigureWebHostDefaults(web => web.UseStartup<Startup>())
    .Build()
    .Run();

// Startup.cs
public class Startup
{
    public void ConfigureServices(IServiceCollection services) { ... }
    public void Configure(IApplicationBuilder app, IWebHostEnvironment env) { ... }
}
```

## Common Follow-up Questions

- How do you still use a `Startup` class with the minimal hosting model if you need the separation?
- How does `WebApplicationBuilder` handle configuration sources ordering — which source wins?
- What is `IHostingStartup` and when would you use it over modifying `Program.cs`?
- How do you run integration tests against a minimal-hosting app using `WebApplicationFactory<T>`?
- What changed with `Program.cs` in AOT (ahead-of-time) compilation mode (.NET 8)?

## Common Mistakes / Pitfalls

- **Calling `builder.Build()` before registering all services** — services registered after `Build()` are silently ignored.
- **Confusing `app.Use*` (middleware) with `builder.Services.Add*` (DI)** — both look similar but operate at different phases.
- **Forgetting `app.Run()` / `app.RunAsync()`** — the app compiles but never actually listens if you forget this.
- **Registering `app.UseAuthorization()` before `app.UseAuthentication()`** — causes 401 responses even with valid tokens.
- **Adding JSON config files with `reloadOnChange: true` in unit tests** — triggers `FileSystemWatcher` and can flake tests in CI.

## References

- [Microsoft Learn — ASP.NET Core fundamentals overview](https://learn.microsoft.com/aspnet/core/fundamentals/?view=aspnetcore-8.0)
- [Microsoft Learn — Migrate from ASP.NET Core 5 to 6 (Startup to minimal hosting)](https://learn.microsoft.com/aspnet/core/migration/50-to-60?view=aspnetcore-8.0)
- [Andrew Lock — Exploring the minimal hosting model](https://andrewlock.net/exploring-the-new-minimal-hosting-model-in-net-6/) (verify URL)
- [Microsoft — WebApplicationBuilder source (GitHub)](https://github.com/dotnet/aspnetcore/blob/main/src/DefaultBuilder/src/WebApplicationBuilder.cs)
- [Microsoft Learn — Generic Host](https://learn.microsoft.com/aspnet/core/fundamentals/host/generic-host?view=aspnetcore-8.0)
