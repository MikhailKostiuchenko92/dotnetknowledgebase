# Response Compression in ASP.NET Core

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🟡 Middle
**Tags:** `response-compression`, `Brotli`, `Gzip`, `ICompressionProvider`, `Accept-Encoding`, `chunked`

## Question

> How do you enable response compression in ASP.NET Core? When should you use Brotli vs Gzip, and when should you NOT compress API responses?

## Short Answer

Add `AddResponseCompression()` with Brotli and/or Gzip providers, then call `UseResponseCompression()` early in the middleware pipeline. The middleware checks `Accept-Encoding`, selects the best matching provider, and compresses the response body. **Use Brotli for text/JSON APIs on HTTPS** (smaller output, good browser support). **Do NOT compress** already-compressed formats (images, audio, PDF, zip) — they won't shrink and you waste CPU. Also avoid compression for very small responses (< ~1KB) and be aware of the **BREACH** attack when using compression over HTTPS with user-controlled data in the response body.

## Detailed Explanation

### Setup

```bash
# Brotli is included in Asp.AspNetCore; no extra package needed
# For .NET 8+, both Brotli and Gzip providers are available out-of-box
```

```csharp
builder.Services.AddResponseCompression(opts =>
{
    opts.EnableForHttps = true; // compress HTTPS responses (off by default due to BREACH)
    opts.Providers.Add<BrotliCompressionProvider>();
    opts.Providers.Add<GzipCompressionProvider>();
    opts.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(new[]
    {
        "application/json",
        "application/problem+json",
        "image/svg+xml"
    });
});

builder.Services.Configure<BrotliCompressionProviderOptions>(opts =>
    opts.Level = CompressionLevel.Fastest); // Fastest/Optimal/SmallestSize

builder.Services.Configure<GzipCompressionProviderOptions>(opts =>
    opts.Level = CompressionLevel.Fastest);
```

```csharp
var app = builder.Build();
app.UseResponseCompression(); // MUST come before UseStaticFiles, MapControllers, etc.
```

### Default MIME types (built-in)

`ResponseCompressionDefaults.MimeTypes` includes:
- `text/plain`, `text/css`, `text/html`
- `application/javascript`, `text/javascript`
- `text/xml`, `application/xml`
- `text/json`, `application/json`

Add `application/problem+json` and `application/x-www-form-urlencoded` if needed.

### Brotli vs Gzip

| | Brotli (br) | Gzip |
|---|---|---|
| Compression ratio | ✅ Better (20–26% smaller than gzip) | Good |
| Compression speed | Similar at `Fastest` | Similar at `Fastest` |
| Browser support | ✅ All modern browsers | Universal |
| Server CPU | Similar | Similar |
| Static file pre-compression | ✅ Via StaticFiles + br files | ✅ |
| Introduced | 2015 | 1992 |

### BREACH attack warning

BREACH exploits HTTP compression when:
1. Response body contains a secret (CSRF token, user data)
2. Attacker can inject partial data into the request (e.g., URL parameter)
3. Attacker measures compressed response size to extract the secret

Mitigations:
- `EnableForHttps = false` (default) — disables compression for HTTPS entirely (over-conservative)
- Use `SameSite=Strict` cookies and CSRF protections
- Don't include secrets in compressed bodies
- Use length-hiding padding

### When NOT to compress

- Already-compressed content: `.jpg`, `.png`, `.gif`, `.mp3`, `.mp4`, `.pdf`, `.zip`, `.gz`
- Small responses (< 1KB) — compression overhead exceeds savings
- Streaming responses where latency matters (server-sent events, gRPC streaming)
- Sensitive payloads where BREACH is a concern without mitigations

### Custom compression provider

```csharp
public sealed class ZstdCompressionProvider : ICompressionProvider
{
    public string EncodingName => "zstd";
    public bool SupportsFlush => true;

    public Stream CreateStream(Stream outputStream) =>
        new ZstandardCompressionStream(outputStream); // hypothetical
}
```

## Code Example

```csharp
// Production-ready response compression setup
builder.Services.AddResponseCompression(opts =>
{
    opts.EnableForHttps = true;
    opts.Providers.Add<BrotliCompressionProvider>();
    opts.Providers.Add<GzipCompressionProvider>();
    opts.MimeTypes = ResponseCompressionDefaults.MimeTypes
        .Append("application/json")
        .Append("application/problem+json")
        .Append("application/grpc-web");
});

builder.Services.Configure<BrotliCompressionProviderOptions>(o =>
    o.Level = CompressionLevel.Optimal); // better ratio; acceptable CPU

builder.Services.Configure<GzipCompressionProviderOptions>(o =>
    o.Level = CompressionLevel.Optimal);

var app = builder.Build();
app.UseResponseCompression(); // early in the pipeline
app.UseStaticFiles();
app.UseRouting();
app.MapControllers();
```

```json
// Test compression with curl:
// curl -H "Accept-Encoding: br,gzip" -I https://localhost:5001/api/products
// Response headers should include: Content-Encoding: br
```

## Common Follow-up Questions

- How do you pre-compress static files at build time to avoid runtime CPU cost?
- What is the `Vary: Accept-Encoding` header and why is it important for caching?
- How does response compression interact with `ResponseCachingMiddleware`?
- Why is `EnableForHttps = false` the default, and when is it safe to change?
- How do you compress streamed responses (e.g., server-sent events)?

## Common Mistakes / Pitfalls

- **Placing `UseResponseCompression()` after `UseStaticFiles()`** — static files bypass response compression; `UseResponseCompression()` must come before `UseStaticFiles()` (though for static files, pre-compressed file serving is better).
- **Compressing already-compressed binary data** — adding JPEG or ZIP to `MimeTypes` wastes CPU and may slightly increase response size.
- **Not setting `Vary: Accept-Encoding` response header** — this is added automatically, but intermediate caches may serve a gzip-compressed response to a client that sent `Accept-Encoding: identity`. Verify with `curl -I`.
- **Enabling compression for chunked streaming responses** — compression and streaming interact poorly; compressed streams must buffer before flushing, defeating the latency goal of streaming.
- **Forgetting `EnableForHttps = true` on HTTPS-only APIs** — by default, HTTPS responses are NOT compressed; you must explicitly opt in.

## References

- [Microsoft Learn — Response compression](https://learn.microsoft.com/aspnet/core/performance/response-compression?view=aspnetcore-8.0)
- [Brotli RFC 7932](https://datatracker.ietf.org/doc/html/rfc7932)
- [BREACH attack paper](https://breachattack.com/)
- [Microsoft — ResponseCompressionDefaults source](https://github.com/dotnet/aspnetcore/blob/main/src/Middleware/ResponseCompression/src/ResponseCompressionDefaults.cs)
