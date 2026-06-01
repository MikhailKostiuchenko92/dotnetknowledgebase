# Request/Response Pipeline — HttpContext

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟡 Middle
**Tags:** `HttpContext`, `request`, `response`, `body-buffering`, `HttpRequest`, `HttpResponse`

## Question

> What is the lifetime of `HttpContext`, and how do you work with the request and response body in ASP.NET Core middleware?

## Short Answer

`HttpContext` is created per request and lives for the duration of that HTTP request/response cycle. The request body is a forward-only `Stream` by default — once read, it cannot be re-read without explicit buffering. The response body is also a stream; once any bytes are written, headers are sealed and the status code cannot be changed. Middleware should be aware of `HasStarted` to avoid writing to a committed response.

## Detailed Explanation

### `HttpContext` lifetime

`HttpContext` is created by Kestrel (or IIS in-process handler) at the start of each request. It is associated with a **DI scope** — one scope per HTTP request. The context is disposed (returned to the pool) after the response is fully written.

> **Warning:** Never store `HttpContext` in a field of a Singleton service, and never capture it in a `Task` that outlives the request. Use `IHttpContextAccessor` with care — it stores the context in `AsyncLocal<T>` which has its own threading constraints.

### `HttpRequest` — the incoming request

| Property | Type | Notes |
|---|---|---|
| `Method` | `string` | `"GET"`, `"POST"`, etc. |
| `Path` | `PathString` | `/api/users/42` |
| `QueryString` | `QueryString` | Raw; use `Query` for parsed key-value |
| `Headers` | `IHeaderDictionary` | Case-insensitive |
| `Body` | `Stream` | Forward-only (see buffering below) |
| `Form` | `IFormCollection` | Only valid after `ReadFormAsync()` |
| `ContentType` | `string?` | `application/json; charset=utf-8` |
| `ContentLength` | `long?` | From `Content-Length` header |
| `IsHttps` | `bool` | From connection, not URL |

### Reading the request body

The request body is a **non-seekable, forward-only stream**. Reading it twice requires buffering.

```csharp
// Reading raw body (once)
using var reader = new StreamReader(context.Request.Body);
var body = await reader.ReadToEndAsync(cancellationToken);
```

**Buffering for multiple reads** (e.g., logging middleware + action):
```csharp
context.Request.EnableBuffering();   // swaps Body with a seek-able MemoryStream or FileStream
using var reader = new StreamReader(context.Request.Body, leaveOpen: true);
var body = await reader.ReadToEndAsync();
context.Request.Body.Position = 0;  // rewind for downstream middleware
```

`EnableBuffering()` uses `Microsoft.AspNetCore.Http.Features.IHttpRequestBodyDetectionFeature` internally and has a size threshold (default 30 KB) above which it spills to a temp file.

### `HttpResponse` — the outgoing response

| Property | Type | Notes |
|---|---|---|
| `StatusCode` | `int` | Must be set before `HasStarted` |
| `Headers` | `IHeaderDictionary` | Must be written before first byte of body |
| `ContentType` | `string?` | Shortcut for `Content-Type` header |
| `Body` | `Stream` | Writable; headers sealed on first write |
| `HasStarted` | `bool` | `true` after first byte written |

```csharp
context.Response.StatusCode = 200;
context.Response.ContentType = "application/json";

// Writing body — seals headers
await context.Response.WriteAsJsonAsync(new { message = "hello" });

// At this point context.Response.HasStarted == true
// Headers cannot be modified anymore
```

### Response body interception (in middleware)

To read what downstream middleware writes (e.g., for compression or logging), wrap the body stream:

```csharp
var originalBody = context.Response.Body;
using var ms = new MemoryStream();
context.Response.Body = ms;

await next(context);       // downstream writes to ms

ms.Seek(0, SeekOrigin.Begin);
var responseBody = await new StreamReader(ms).ReadToEndAsync();
ms.Seek(0, SeekOrigin.Begin);

await ms.CopyToAsync(originalBody); // forward to client
context.Response.Body = originalBody;
```

> **Note:** In .NET 5+, consider using `IHttpResponseBodyFeature` and `PipeWriter` instead of wrapping the stream directly, which is more efficient and avoids double-buffering.

### `IHttpContextAccessor`

For accessing `HttpContext` outside of middleware (e.g., in a service):

```csharp
builder.Services.AddHttpContextAccessor(); // registers as Singleton

public class MyService(IHttpContextAccessor accessor)
{
    public string? GetUserId() =>
        accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier);
}
```

> **Warning:** `IHttpContextAccessor` uses `AsyncLocal<T>`. If you access it from a thread that was not started in the request flow (e.g., `Task.Run` without context propagation), it returns `null`.

## Code Example

```csharp
// RequestBodyLoggingMiddleware.cs — buffers request body for logging
namespace MyApp.Middleware;

public sealed class RequestBodyLoggingMiddleware(
    RequestDelegate next,
    ILogger<RequestBodyLoggingMiddleware> logger)
{
    private const int MaxLoggedBodyBytes = 4096;

    public async Task InvokeAsync(HttpContext context)
    {
        // Only buffer for specific content types
        if (context.Request.ContentType?.Contains("application/json") == true
            && (context.Request.ContentLength ?? 0) > 0)
        {
            context.Request.EnableBuffering();  // makes body seekable

            var body = new byte[Math.Min(
                context.Request.ContentLength ?? 0, MaxLoggedBodyBytes)];
            _ = await context.Request.Body.ReadAsync(body);
            context.Request.Body.Position = 0;  // rewind for downstream

            logger.LogDebug("Request body (first {Bytes} bytes): {Body}",
                body.Length, System.Text.Encoding.UTF8.GetString(body));
        }

        await next(context);
    }
}
```

```csharp
// Checking HasStarted before setting headers
public async Task InvokeAsync(HttpContext context)
{
    await next(context);

    // Safe: only add header if response hasn't committed yet
    if (!context.Response.HasStarted)
    {
        context.Response.Headers["X-Processed-By"] = "MyMiddleware";
    }
}
```

## Common Follow-up Questions

- Why is the request body a forward-only stream by default — what are the performance implications of `EnableBuffering()`?
- How do you safely add response headers after downstream middleware has already started writing the body?
- What is `IHttpResponseBodyFeature` and why is it preferred over wrapping `context.Response.Body` directly?
- How does `IHttpContextAccessor` work with `AsyncLocal<T>` and what are the threading pitfalls?
- How does the request body differ between HTTP/1.1 and HTTP/2 chunked encoding in Kestrel?

## Common Mistakes / Pitfalls

- **Reading `context.Request.Body` twice without `EnableBuffering()`** — the second read returns 0 bytes because the stream position is at the end.
- **Setting headers or status code after `context.Response.HasStarted`** — throws `InvalidOperationException`. Always check `HasStarted` or set them before `await next(context)`.
- **Storing `HttpContext` in a Singleton** — the context is request-scoped and will be disposed; using it after disposal causes undefined behavior.
- **Wrapping `context.Response.Body` without restoring it** — if an exception occurs before restoration, the response body is lost and the client may hang.
- **Capturing `HttpContext` in a `Task.Run(() => ...)` without passing it explicitly** — `AsyncLocal` context does not propagate into `Task.Run` without explicit capture; `IHttpContextAccessor` returns `null`.

## References

- [Microsoft Learn — HttpContext in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/use-http-context?view=aspnetcore-8.0)
- [Microsoft Learn — Request and response operations](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/request-response?view=aspnetcore-8.0)
- [Microsoft Learn — IHttpContextAccessor](https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.http.ihttpcontextaccessor?view=aspnetcore-8.0)
- [Andrew Lock — Accessing HttpContext outside of controllers](https://andrewlock.net/tag/aspnet-core/) (verify URL)
- [Microsoft — PipeReader/PipeWriter in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/request-response?view=aspnetcore-8.0#use-pipereader)
