# Options Validation in ASP.NET Core

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟡 Middle
**Tags:** `IOptions`, `IValidateOptions`, `ValidateOnStart`, `DataAnnotations`, `options-validation`

## Question

> How do you validate configuration options in ASP.NET Core at startup, and what is `ValidateOnStart`?

## Short Answer

ASP.NET Core's options validation lets you attach validation rules — via Data Annotations, a custom `IValidateOptions<T>` implementation, or a fluent delegate — to strongly-typed option classes. Without `ValidateOnStart()`, errors only surface when the option is first resolved (potentially during a request). Adding `ValidateOnStart()` (introduced in .NET 6) causes the host to throw during startup if any option is invalid, giving you a fast-fail safety net.

## Detailed Explanation

### Three validation approaches

#### 1. Data Annotations

```csharp
public sealed class SmtpOptions
{
    [Required] public string Host { get; init; } = string.Empty;
    [Range(1, 65535)] public int Port { get; init; } = 587;
    [Required, EmailAddress] public string FromAddress { get; init; } = string.Empty;
}
```

Register with:
```csharp
builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration("Smtp")
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

#### 2. Delegate validation

```csharp
builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration("Smtp")
    .Validate(opts => opts.Port != 25 || opts.Host != "localhost",
               "Port 25 on localhost is not allowed in production")
    .ValidateOnStart();
```

#### 3. `IValidateOptions<T>` — reusable, DI-aware validation

```csharp
public sealed class SmtpOptionsValidator : IValidateOptions<SmtpOptions>
{
    // Can inject other services (e.g., IWebHostEnvironment) via constructor
    public ValidateOptionsResult Validate(string? name, SmtpOptions options)
    {
        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(options.Host))
            errors.Add("Smtp:Host is required");

        if (options.Port is < 1 or > 65535)
            errors.Add("Smtp:Port must be between 1 and 65535");

        return errors.Count > 0
            ? ValidateOptionsResult.Fail(errors)
            : ValidateOptionsResult.Success;
    }
}
```

Register:
```csharp
builder.Services.AddSingleton<IValidateOptions<SmtpOptions>, SmtpOptionsValidator>();
builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration("Smtp")
    .ValidateOnStart();
```

### Why `ValidateOnStart()` matters

Without it:
```
App starts ✅ → First request that resolves IOptions<SmtpOptions> ❌ → Exception at runtime
```

With it:
```
App starts → Validation runs → Exception thrown → Process exits ❌ (visible immediately in logs/deployment)
```

`ValidateOnStart()` registers a special `IHostedService` that resolves each registered options type during `StartAsync`, triggering validation before any request is served.

> **Note:** `ValidateOnStart()` was introduced in .NET 6. For .NET 5 and earlier, you had to manually implement an `IHostedService` or use `IStartupFilter` to achieve the same effect.

### Named options validation

```csharp
builder.Services.AddOptions<ConnectionOptions>("primary")
    .BindConfiguration("Connections:Primary")
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddOptions<ConnectionOptions>("replica")
    .BindConfiguration("Connections:Replica")
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

`IValidateOptions<T>.Validate(string? name, T options)` receives the name so you can apply different rules per named instance.

### Combining multiple validators

You can register multiple `IValidateOptions<T>` for the same type — all are run and their errors are combined:

```csharp
builder.Services.AddSingleton<IValidateOptions<SmtpOptions>, SmtpOptionsValidator>();
builder.Services.AddSingleton<IValidateOptions<SmtpOptions>, SmtpTlsValidator>();
```

## Code Example

```csharp
// DatabaseOptions.cs
namespace MyApp.Options;

public sealed class DatabaseOptions
{
    [Required(ErrorMessage = "Database host is required")]
    [RegularExpression(@"^[a-zA-Z0-9\.\-]+$", ErrorMessage = "Invalid host format")]
    public string Host { get; init; } = string.Empty;

    [Range(1, 65535, ErrorMessage = "Port must be 1–65535")]
    public int Port { get; init; } = 5432;

    [Required]
    public string DatabaseName { get; init; } = string.Empty;

    [Range(1, 100, ErrorMessage = "MaxConnections must be between 1 and 100")]
    public int MaxConnections { get; init; } = 20;
}
```

```csharp
// DatabaseOptionsValidator.cs — cross-property validation via IValidateOptions
public sealed class DatabaseOptionsValidator(IWebHostEnvironment env)
    : IValidateOptions<DatabaseOptions>
{
    public ValidateOptionsResult Validate(string? name, DatabaseOptions options)
    {
        // Example: production must not use localhost
        if (env.IsProduction() && options.Host is "localhost" or "127.0.0.1")
            return ValidateOptionsResult.Fail(
                "DatabaseOptions.Host cannot be 'localhost' in Production.");

        return ValidateOptionsResult.Success;
    }
}
```

```csharp
// Program.cs
builder.Services.AddSingleton<IValidateOptions<DatabaseOptions>, DatabaseOptionsValidator>();

builder.Services
    .AddOptions<DatabaseOptions>()
    .BindConfiguration("Database")
    .ValidateDataAnnotations()       // attribute-based rules
    .ValidateOnStart();              // fail fast on bad config
```

### What the startup error looks like

```
Unhandled exception. Microsoft.Extensions.Options.OptionsValidationException:
  DataAnnotation validation failed for 'DatabaseOptions' with errors:
  The field Port must be between 1 and 65535.
```

## Common Follow-up Questions

- How do you validate options in .NET 5 / earlier without `ValidateOnStart()`?
- How do `IValidateOptions<T>` validators interact with named options?
- Can you inject `IOptions<T>` into an `IValidateOptions<T>` to perform cross-option validation?
- How do you unit-test a custom `IValidateOptions<T>` validator?
- What happens if `ValidateOnStart()` fails — does it throw synchronously or asynchronously?

## Common Mistakes / Pitfalls

- **Omitting `ValidateOnStart()`** — validation only triggers on first resolution, often inside a request handler, surfacing config errors at the worst time.
- **Using `IOptions<T>` without validation** — misconfigured options (empty strings, out-of-range values) get through silently and cause confusing runtime errors.
- **Cross-property rules in Data Annotations** — `[Required]` and `[Range]` are per-property. For rules that span multiple properties, use `IValidateOptions<T>` or `IValidatableObject`.
- **Registering `IValidateOptions<T>` as Transient** — it should be Singleton (or Scoped at most). Registering as Transient means a new instance is created for every validation call.
- **Forgetting that `ValidateOnStart` adds a hosted service** — in tests using `WebApplicationFactory`, this hosted service runs during `CreateClient()`, potentially failing tests if test configuration is incomplete. Override config in test fixture.

## References

- [Microsoft Learn — Options validation](https://learn.microsoft.com/dotnet/core/extensions/options-validation)
- [Microsoft Learn — Options pattern](https://learn.microsoft.com/aspnet/core/fundamentals/configuration/options?view=aspnetcore-8.0)
- [Andrew Lock — Adding validation to strongly typed configuration objects in ASP.NET Core](https://andrewlock.net/adding-validation-to-strongly-typed-configuration-objects-in-asp-net-core/) (verify URL)
- [Microsoft — IValidateOptions source](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Options/src/IValidateOptions.cs)
- [Microsoft Learn — ValidateOnStart (.NET 6)](https://learn.microsoft.com/dotnet/core/whats-new/dotnet-6#options-validation)
