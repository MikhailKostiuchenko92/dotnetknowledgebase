# How Do You Test Middleware in Isolation vs. as Part of the Full Pipeline?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🔴 Senior
**Tags:** `middleware`, `TestServer`, `integration-testing`, `pipeline`, `IMiddleware`

## Question
> How do you test middleware in isolation vs. as part of the full pipeline?

## Short Answer
For **isolated** middleware testing, build a minimal `TestServer` with only the middleware under test and a simple next-delegate — this is fast and focused. For **pipeline** testing, use `WebApplicationFactory<Program>` with the full app and assert on endpoint responses — this validates that the middleware integrates correctly with routing, auth, and other pipeline components.

## Detailed Explanation

### Option 1: Isolated Middleware Test (No Real App)
Build a `TestServer` with just your middleware and a minimal pipeline:
```csharp
var app = WebApplication.Create();
app.UseMiddleware<RequestLoggingMiddleware>();
app.Run(ctx => ctx.Response.WriteAsync("OK")); // stub next
var testServer = new TestServer(app.Services.GetRequiredService<IServer>()...);
```

Cleaner using `WebApplicationFactory` with a minimal host:
```csharp
var factory = new WebApplicationFactory<Program>()
    .WithWebHostBuilder(builder =>
    {
        builder.ConfigureTestServices(services => { /* minimal */ });
        builder.Configure(app =>
        {
            app.UseMiddleware<RequestThrottlingMiddleware>();
            app.Run(ctx => ctx.Response.WriteAsync("OK"));
        });
    });
```

Or use `Microsoft.AspNetCore.TestHost` directly:
```csharp
var builder = new WebHostBuilder()
    .Configure(app =>
    {
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.Run(ctx => Task.CompletedTask);
    });
var server = new TestServer(builder);
var client = server.CreateClient();
var response = await client.GetAsync("/");
response.Headers.Should().ContainKey("X-Correlation-ID");
```

### Option 2: Full Pipeline Test (via WebApplicationFactory)
```csharp
public class CorrelationIdMiddlewareTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public CorrelationIdMiddlewareTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task AnyRequest_AddsCorrelationIdHeader()
    {
        var response = await _client.GetAsync("/health");
        response.Headers.Should().ContainKey("X-Correlation-ID");
    }
}
```

### Comparison

| Approach | Speed | Isolation | Catches Integration Issues |
|---|---|---|---|
| Minimal `TestServer` | ⚡ Fast | Maximum | ❌ No |
| Full `WebApplicationFactory` | 🕐 Moderate | Moderate | ✅ Yes |

### What to Test in Isolation
- Middleware adds correct response headers
- Middleware short-circuits on specific conditions (e.g., missing API key)
- Middleware modifies request before passing to `next`
- Middleware exception handling (wraps exceptions in a specific format)

### What to Test in the Full Pipeline
- Middleware order matters (e.g., CORS before auth)
- Middleware interacts correctly with authentication
- Rate limiting enforces per-route rules
- Exception handling middleware returns correct ProblemDetails format

## Code Example
```csharp
namespace Middleware.Tests;

// ── Isolated test of CorrelationIdMiddleware ────────────────
public class CorrelationIdMiddleware_IsolatedTests
{
    [Fact]
    public async Task Request_WithoutCorrelationId_AddsGeneratedId()
    {
        var server = new TestServer(new WebHostBuilder()
            .Configure(app =>
            {
                app.UseMiddleware<CorrelationIdMiddleware>();
                app.Run(ctx => Task.CompletedTask);
            }));

        var response = await server.CreateClient().GetAsync("/");

        response.Headers.Should().ContainKey("X-Correlation-ID");
        response.Headers.GetValues("X-Correlation-ID")
                .Should().ContainSingle()
                .Which.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task Request_WithExistingCorrelationId_PropagatesIt()
    {
        var server = new TestServer(new WebHostBuilder()
            .Configure(app =>
            {
                app.UseMiddleware<CorrelationIdMiddleware>();
                app.Run(ctx => Task.CompletedTask);
            }));

        var request = new HttpRequestMessage(HttpMethod.Get, "/");
        request.Headers.Add("X-Correlation-ID", "my-correlation-id");
        var response = await server.CreateClient().SendAsync(request);

        response.Headers.GetValues("X-Correlation-ID").Single()
                .Should().Be("my-correlation-id");
    }
}

// ── Full pipeline: middleware + auth integration ─────────────
public class RateLimitingPipelineTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public RateLimitingPipelineTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task ExcessiveRequests_Returns429TooManyRequests()
    {
        // Send 101 requests (limit is 100/min in production config)
        for (int i = 0; i < 100; i++)
            await _client.GetAsync("/api/products");

        var response = await _client.GetAsync("/api/products");
        response.StatusCode.Should().Be(HttpStatusCode.TooManyRequests);
    }
}
```

## Common Follow-up Questions
- How do you test middleware that depends on DI services?
- How do you test exception handling middleware?
- How do you verify that middleware calls `next`?
- What is `HttpContext.Items` and how do you test middleware that uses it?
- How do you test middleware ordering in the pipeline?
- Can you unit test middleware without `TestServer`?

## Common Mistakes / Pitfalls
- **Only testing middleware with the full pipeline** — hard to isolate bugs; minimal `TestServer` is faster for middleware-specific assertions.
- **Not testing short-circuit scenarios** — middleware that returns early without calling `next` is a common bug; test the `if` condition explicitly.
- **Forgetting `app.UseMiddleware<T>()` order in the test** — the test pipeline must register middleware in the same order as production for order-dependent tests.
- **Not asserting on the `next` delegate being called** — use a `RequestDelegate` mock or a flag variable to verify the chain is not broken unexpectedly.
- **Testing middleware logic through endpoints** — endpoint-level logic is not middleware; don't mix them.

## References
- [Microsoft Learn — ASP.NET Core Middleware](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/)
- [Microsoft Learn — Test middleware with TestServer](https://learn.microsoft.com/en-us/aspnet/core/test/middleware)
- [NuGet — Microsoft.AspNetCore.TestHost](https://www.nuget.org/packages/Microsoft.AspNetCore.TestHost/)
