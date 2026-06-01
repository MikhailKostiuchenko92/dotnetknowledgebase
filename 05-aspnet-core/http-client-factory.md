# IHttpClientFactory and HttpClient in ASP.NET Core

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🟡 Middle
**Tags:** `IHttpClientFactory`, `HttpClient`, `named-clients`, `typed-clients`, `Polly`, `resilience`, `socket-exhaustion`

## Question

> Why should you use `IHttpClientFactory` instead of creating `HttpClient` directly? What are named vs typed clients, and how do you add resilience with Polly?

## Short Answer

Creating `HttpClient` directly leads to **socket exhaustion** (each instance opens a new connection that lingers after disposal) or **DNS staleness** (a single static instance doesn't respect DNS TTL). `IHttpClientFactory` manages a pool of `HttpMessageHandler` instances, recycling them based on a configurable lifetime (default 2 minutes), solving both problems. Named clients configure a shared factory by name; typed clients wrap `IHttpClientFactory` in a strongly-typed service. Polly (or .NET 8's `Microsoft.Extensions.Http.Resilience`) adds retry, circuit breaker, and timeout policies.

## Detailed Explanation

### The problem with `HttpClient`

```csharp
// ❌ New instance per request — socket exhaustion
using var client = new HttpClient();
var result = await client.GetStringAsync("https://api.example.com/products");
```

```csharp
// ❌ Static singleton — DNS staleness (won't pick up DNS changes)
private static readonly HttpClient _client = new();
```

`IHttpClientFactory` solves both by pooling `HttpMessageHandler` instances with a 2-minute default lifetime.

### Registration approaches

#### Basic (factory injection)

```csharp
builder.Services.AddHttpClient();
// Inject: IHttpClientFactory factory → factory.CreateClient()
```

#### Named clients

```csharp
builder.Services.AddHttpClient("GitHub", client =>
{
    client.BaseAddress = new Uri("https://api.github.com/");
    client.DefaultRequestHeaders.Add("Accept", "application/vnd.github.v3+json");
    client.DefaultRequestHeaders.Add("User-Agent", "MyApp/1.0");
});

// Usage
public class GitHubService(IHttpClientFactory factory)
{
    public async Task<string> GetReposAsync()
    {
        var client = factory.CreateClient("GitHub");
        return await client.GetStringAsync("repos");
    }
}
```

#### Typed clients (recommended)

```csharp
public sealed class GitHubClient(HttpClient http)
{
    public Task<string[]?> GetReposAsync(string org) =>
        http.GetFromJsonAsync<string[]>($"orgs/{org}/repos");
}

builder.Services.AddHttpClient<GitHubClient>(client =>
{
    client.BaseAddress = new Uri("https://api.github.com/");
    client.Timeout = TimeSpan.FromSeconds(30);
});
```

Typed clients are registered as **transient** by default. Each resolution creates a new `GitHubClient` wrapping a pooled `HttpMessageHandler`.

### Handler lifetime

The default handler lifetime is **2 minutes**. After expiry, the handler is marked for disposal (but active requests complete first). Shorter lifetimes pick up DNS changes faster; longer lifetimes reduce handler creation overhead.

```csharp
builder.Services.AddHttpClient<GitHubClient>()
    .SetHandlerLifetime(TimeSpan.FromMinutes(5));
```

### Adding resilience (.NET 8+)

.NET 8 ships `Microsoft.Extensions.Http.Resilience` (built on Polly v8):

```bash
dotnet add package Microsoft.Extensions.Http.Resilience
```

```csharp
builder.Services.AddHttpClient<GitHubClient>()
    .AddStandardResilienceHandler(); // retry + circuit breaker + timeout defaults
```

Or custom:

```csharp
builder.Services.AddHttpClient<GitHubClient>()
    .AddResilienceHandler("custom", pipeline =>
    {
        pipeline.AddRetry(new HttpRetryStrategyOptions
        {
            MaxRetryAttempts = 3,
            Delay = TimeSpan.FromSeconds(1),
            UseJitter = true
        });
        pipeline.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
        {
            FailureRatio = 0.5,
            SamplingDuration = TimeSpan.FromSeconds(30)
        });
        pipeline.AddTimeout(TimeSpan.FromSeconds(10));
    });
```

### Adding DelegatingHandlers (cross-cutting)

```csharp
public sealed class AuthHeaderHandler(ITokenService tokens) : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        var token = await tokens.GetAccessTokenAsync(ct);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await base.SendAsync(request, ct);
    }
}

builder.Services.AddTransient<AuthHeaderHandler>();
builder.Services.AddHttpClient<GitHubClient>()
    .AddHttpMessageHandler<AuthHeaderHandler>();
```

## Code Example

```csharp
// Typed client with resilience
public sealed class ProductApiClient(HttpClient http)
{
    public Task<Product?> GetByIdAsync(int id, CancellationToken ct = default) =>
        http.GetFromJsonAsync<Product>($"api/products/{id}", ct);

    public async Task<Product> CreateAsync(CreateProductRequest req, CancellationToken ct = default)
    {
        using var response = await http.PostAsJsonAsync("api/products", req, ct);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<Product>(ct))!;
    }
}

// Registration
builder.Services.AddHttpClient<ProductApiClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ProductApiUrl"]!);
    client.DefaultRequestHeaders.Add("Accept", "application/json");
})
.SetHandlerLifetime(TimeSpan.FromMinutes(5))
.AddStandardResilienceHandler(opts =>
{
    opts.Retry.MaxRetryAttempts = 3;
    opts.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(60);
});
```

## Common Follow-up Questions

- What is the difference between `AddHttpClient<T>()` and `AddHttpClient("name")`?
- How does the 2-minute handler lifetime interact with DNS change detection?
- What happens if you inject `HttpClient` directly (without `IHttpClientFactory`) into a scoped service?
- How does `IHttpClientFactory` work with `AddStandardResilienceHandler` in a high-throughput scenario?
- Can you use `IHttpClientFactory` in a console application (non-ASP.NET Core)?

## Common Mistakes / Pitfalls

- **Injecting `HttpClient` directly** (not via typed client pattern) — `HttpClient` should only be used directly when it's injected by `IHttpClientFactory` via a typed client. Never `new HttpClient()` inside DI-managed classes.
- **Making typed clients singleton** — typed clients are transient by default for a reason. Registering a typed client as singleton captures a `HttpMessageHandler` forever, causing DNS staleness.
- **Not setting `BaseAddress`** — relative URLs in `GetAsync("api/products")` throw if `BaseAddress` is not set; always configure it at registration.
- **Catching `TaskCanceledException` for timeout** — `HttpClient` timeouts throw `TaskCanceledException` with `InnerException = TimeoutException`; check `ex.InnerException` before treating it as user cancellation.
- **Using Polly v7 `AddPolicyHandler` with .NET 8+** — Polly v8 has breaking API changes. Prefer `Microsoft.Extensions.Http.Resilience` for .NET 8+; it wraps Polly v8 with a cleaner API.

## References

- [Microsoft Learn — IHttpClientFactory](https://learn.microsoft.com/aspnet/core/fundamentals/http-requests?view=aspnetcore-8.0)
- [Microsoft Learn — Http resilience](https://learn.microsoft.com/dotnet/core/resilience/http-resilience)
- [Microsoft — HttpClientFactory source](https://github.com/dotnet/runtime/tree/main/src/libraries/Microsoft.Extensions.Http)
- [Steve Gordon — What is IHttpClientFactory?](https://www.stevejgordon.co.uk/introduction-to-httpclientfactory-aspnetcore)
