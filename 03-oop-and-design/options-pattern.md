# Options Pattern in .NET

**Category:** OOP & Design / Configuration & DI
**Difficulty:** 🟡 Middle
**Tags:** `options-pattern`, `IOptions`, `configuration`, `DI`, `.NET`

## Question
> Can you explain the .NET options pattern, including `IOptions<T>`, `IOptionsSnapshot<T>`, `IOptionsMonitor<T>`, named options, validation, and how it integrates with DI?

## Short Answer
The options pattern binds related configuration values into strongly typed classes and exposes them through DI-friendly wrappers like `IOptions<T>`, `IOptionsSnapshot<T>`, and `IOptionsMonitor<T>`. `IOptions<T>` is the simplest singleton-style view, `IOptionsSnapshot<T>` is scoped and recomputed per request, and `IOptionsMonitor<T>` supports change notifications and reloadable values. The main benefit is better separation of concerns, stronger typing, and centralized validation of configuration.

## Detailed Explanation
### What the options pattern is
The options pattern groups related settings into a class, such as `SmtpOptions` or `GitHubClientOptions`, instead of scattering raw `IConfiguration["Some:Key"]` lookups all over the codebase. That gives you strongly typed access, easier testing, and a natural place to document defaults and validation rules.

It also fits the dependency injection model well. Rather than injecting the full configuration system into every class, you inject only the relevant settings wrapper for that class.

| Type | Lifetime behavior | Reload support | Typical usage |
|---|---|---|---|
| `IOptions<T>` | Singleton-friendly | No | Static settings read once |
| `IOptionsSnapshot<T>` | Scoped | Recreated per scope/request | ASP.NET Core request-scoped config |
| `IOptionsMonitor<T>` | Singleton-friendly | Yes | Long-lived services needing updates |

### How the three main wrappers differ
`IOptions<T>` exposes a `Value` property. It is simple and fast, but it does not automatically react to configuration reloads after startup.

`IOptionsSnapshot<T>` is scoped. In web apps, each request gets a fresh snapshot, which makes it useful when configuration can change between requests. Because it is scoped, you should not inject it into singleton services.

`IOptionsMonitor<T>` is built for long-lived services. It always exposes the latest value and lets you subscribe to changes with `OnChange`. That makes it the right fit for background services, caches, or clients that should react to config reloads without restarting the process.

> Warning: Injecting `IOptionsSnapshot<T>` into a singleton is a lifetime mismatch and usually means the design is wrong. Use `IOptionsMonitor<T>` if a singleton needs updated configuration.

### Named options, validation, and DI integration
Named options let you bind the same options type more than once. For example, you might bind `GitHubOptions` once for the public API and once for an internal enterprise instance. That avoids creating multiple nearly identical option classes.

Validation is where the pattern becomes much more than simple binding. You can validate with data annotations, custom delegates, or custom validators implementing `IValidateOptions<T>`. `ValidateOnStart()` is especially useful in services and APIs because it fails fast during startup instead of waiting for the first request to hit a broken configuration path.

DI integration is straightforward: register the options, bind them to a configuration section, optionally validate them, then inject the appropriate wrapper where needed. Internally, .NET uses services such as `IOptionsFactory<T>`, `IOptionsMonitorCache<T>`, and `IConfigureOptions<T>` to compose the final value.

### Why it matters and when not to overuse it
The options pattern improves cohesion and keeps configuration logic centralized. It also prevents stringly typed code from spreading through the application.

The trade-off is indirection. For a tiny script or a single setting used in one place, a whole options type may be unnecessary. It can also become messy if one options class grows too large or mixes unrelated concerns.

Use it for meaningful groups of settings with a clear consumer. Avoid huge “ApplicationOptions” mega-classes and avoid passing raw options objects everywhere when a smaller service abstraction would better hide configuration details.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace InterviewExamples;

public sealed class GitHubOptions
{
    [Required]
    public string BaseUrl { get; init; } = string.Empty;

    [Range(1, 60)]
    public int TimeoutSeconds { get; init; }
}

internal static class Program
{
    private static void Main()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["GitHub:Public:BaseUrl"] = "https://api.github.com",
                ["GitHub:Public:TimeoutSeconds"] = "10"
            })
            .Build();

        var services = new ServiceCollection();

        services.AddOptions<GitHubOptions>("Public")
            .Bind(configuration.GetSection("GitHub:Public"))
            .ValidateDataAnnotations()
            .Validate(options => Uri.IsWellFormedUriString(options.BaseUrl, UriKind.Absolute), "BaseUrl must be absolute.");

        using var provider = services.BuildServiceProvider();

        var monitor = provider.GetRequiredService<IOptionsMonitor<GitHubOptions>>();
        var publicOptions = monitor.Get("Public"); // Named options.

        Console.WriteLine($"{publicOptions.BaseUrl} ({publicOptions.TimeoutSeconds}s)");
    }
}
```

## Common Follow-up Questions
- When should you choose `IOptionsMonitor<T>` over `IOptionsSnapshot<T>`?
- How do named options differ from keyed services?
- What happens if configuration binding succeeds but the values are invalid?
- How do you validate options at startup instead of at first use?
- Which internal services build and cache options instances?

## Common Mistakes / Pitfalls
- Injecting raw `IConfiguration` everywhere instead of binding focused options types.
- Putting unrelated settings into one giant options class.
- Using `IOptions<T>` when the service actually needs reloadable values.
- Forgetting `ValidateOnStart()` and discovering invalid configuration only in production traffic.
- Injecting `IOptionsSnapshot<T>` into singleton services.

## References
- [Options pattern - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options)
- [Options pattern guidance for .NET library authors - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options-library-authors)
- [IOptionsMonitor<TOptions> Interface | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.extensions.options.ioptionsmonitor-1)
- [IOptionsSnapshot<TOptions> Interface | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.extensions.options.ioptionssnapshot-1)
- [Compile-time options validation source generation - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options-validation-generator)
