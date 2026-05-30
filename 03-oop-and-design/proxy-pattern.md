# Proxy Pattern

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🟡 Middle
**Tags:** `proxy`, `structural`, `DispatchProxy`, `Castle`

## Question
> What is the Proxy pattern, and how would you use virtual, protection, or logging proxies in .NET? Can you also mention `DispatchProxy` and Castle DynamicProxy?

## Short Answer
The Proxy pattern provides a stand-in object that controls access to another object. It keeps the same interface as the real object, but can add lazy loading, access checks, logging, caching, or remote communication. In .NET, you can implement proxies manually or generate them dynamically with tools such as `DispatchProxy` or Castle DynamicProxy.

## Detailed Explanation
### What Proxy solves
A proxy looks like the real subject to the client but intercepts calls before delegating to the real implementation. That interception is useful when object creation is expensive, access should be restricted, or cross-cutting behavior should happen transparently.

The important distinction from Decorator is intent. Both wrap another object, but a decorator primarily adds behavior, while a proxy primarily controls access to the real object.

### Common proxy types
Several proxy variants appear often in .NET systems:

| Proxy type | Purpose | Example |
| --- | --- | --- |
| Virtual proxy | Delay expensive object creation until needed | Lazy-load a report, image, or EF Core navigation |
| Protection proxy | Enforce security or policy before delegation | Check roles before calling an admin service |
| Logging proxy | Trace calls and results transparently | Log service method calls for diagnostics |
| Remote proxy | Represent a remote service locally | gRPC or HTTP client wrapper |

A virtual proxy is often implemented with `Lazy<T>` or explicit lazy initialization. A protection proxy checks identity, claims, or other policies. A logging proxy can measure duration, capture parameters, and record failures.

### How it works internally
Internally, a proxy implements the same interface as the real subject. The client stays unaware that it is talking to a stand-in. The proxy can decide whether to instantiate the real object, whether to forward the call at all, and what extra work to do around the invocation.

Dynamic proxies automate this. `DispatchProxy` can create interface-based proxies at runtime and route calls through a single `Invoke` method. Castle DynamicProxy is more powerful and can proxy interfaces and virtual members on classes.

> Warning: dynamic proxies are convenient, but they add reflection and interception complexity. They are great for infrastructure concerns, not for hiding core business logic.

### Why it matters in .NET
Proxy is everywhere in enterprise .NET: lazy-loaded EF Core navigation properties, AOP-style interceptors, generated HTTP clients, test doubles, and secure wrappers. It helps you separate client code from expensive or sensitive implementation details.

For example, a controller can depend on `IReportService` without knowing whether the real report is created eagerly, lazily, remotely, or behind an authorization check.

### Trade-offs and when not to use it
A proxy introduces indirection, which can complicate debugging and performance analysis. Logging proxies can accidentally log sensitive data, and protection proxies can create duplicated authorization logic if you also authorize elsewhere.

Avoid Proxy when a simple direct dependency is enough. Also, be careful with dynamic proxies and non-virtual methods: Castle cannot intercept non-virtual class members, and `DispatchProxy` is interface-oriented.

## Code Example
```csharp
using System.Reflection;

namespace OopDesignSamples;

public interface IWeatherClient
{
    string GetForecast(string city);
}

public sealed class WeatherClient : IWeatherClient
{
    public string GetForecast(string city) => $"Forecast for {city}: Sunny";
}

public sealed class LoggingProxy<T> : DispatchProxy where T : class
{
    private T? _decorated;

    public static T Create(T decorated)
    {
        var proxy = Create<T, LoggingProxy<T>>();
        ((LoggingProxy<T>)(object)proxy)._decorated = decorated;
        return proxy;
    }

    protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
    {
        Console.WriteLine($"Calling {targetMethod!.Name}...");
        var result = targetMethod.Invoke(_decorated, args); // Forward to the real subject.
        Console.WriteLine($"Finished {targetMethod.Name}");
        return result;
    }
}

public static class Program
{
    public static void Main()
    {
        var client = LoggingProxy<IWeatherClient>.Create(new WeatherClient());
        Console.WriteLine(client.GetForecast("Kyiv"));
    }
}
```

## Common Follow-up Questions
- How is Proxy different from Decorator and Adapter?
- When would you choose `DispatchProxy` over Castle DynamicProxy?
- What are the limitations of dynamic proxies in .NET?
- How does lazy loading in EF Core relate to the virtual proxy idea?
- Where should authorization live if you also use a protection proxy?

## Common Mistakes / Pitfalls
- Using a proxy when a normal service or helper would be simpler.
- Assuming Castle DynamicProxy can intercept any class member, including non-virtual methods.
- Logging sensitive data or large payloads inside a logging proxy.
- Hiding network latency or remote failures behind an innocent-looking interface.
- Duplicating authorization rules in multiple protection proxies.

## References
- [Proxy](https://refactoring.guru/design-patterns/proxy)
- [DispatchProxy Class](https://learn.microsoft.com/en-us/dotnet/api/system.reflection.dispatchproxy?view=net-10.0)
- [Castle DynamicProxy](https://www.castleproject.org/projects/dynamicproxy/)
- [Lazy Loading of Related Data](https://learn.microsoft.com/en-us/ef/core/querying/related-data/lazy)
