# Built-in Middleware Overview

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟢 Junior
**Tags:** `middleware`, `static-files`, `routing`, `authentication`, `authorization`, `cors`, `https`, `exception`

## Question

> What are the most important built-in middleware components in ASP.NET Core, and in what order should they be registered?

## Short Answer

ASP.NET Core ships with ready-to-use middleware for HTTPS redirection, static files, routing, CORS, authentication, authorization, exception handling, and more. Their registration order in `Program.cs` is critical — each middleware only sees the portion of the pipeline after it, so security middleware (authentication/authorization) must come after routing but before endpoint execution, and exception handlers must be first to catch errors from all downstream components.

## Detailed Explanation

### Recommended pipeline order (from Microsoft docs)

```csharp
app.UseExceptionHandler();           // 1. catch everything below
app.UseHsts();                       // 2. HSTS header (production)
app.UseHttpsRedirection();           // 3. redirect HTTP → HTTPS
app.UseStaticFiles();                // 4. short-circuit for wwwroot/*
app.UseRouting();                    // 5. match route → populate endpoint metadata
app.UseCors();                       // 6. CORS headers (after routing, before auth)
app.UseAuthentication();             // 7. populate HttpContext.User
app.UseAuthorization();              // 8. enforce [Authorize] on matched endpoint
app.UseOutputCache();                // 9. serve from cache if available (.NET 7+)
app.UseRateLimiter();                // 10. enforce rate limits (.NET 7+)
app.UseResponseCompression();        // 11. compress outgoing response
app.MapControllers();                // 12. execute matched controller action
```

> **Note:** In .NET 6+, `UseRouting()` and `UseEndpoints()` are implicit when you call `MapControllers()`. You only need to call `UseRouting()` explicitly if you add middleware between routing and endpoint execution (e.g., `UseCors`, `UseAuthentication`).

### Key built-in middleware

#### Exception Handling
- `UseExceptionHandler("/error")` — catches unhandled exceptions downstream, re-executes to the error path.
- `UseDeveloperExceptionPage()` — detailed exception page for development only.

#### HTTPS & HSTS
- `UseHttpsRedirection()` — 301/307 redirect from HTTP to HTTPS.
- `UseHsts()` — adds `Strict-Transport-Security` header (production only; breaks local dev).

#### Static Files
- `UseStaticFiles()` — serves files from `wwwroot/`; short-circuits without touching routing.
- `UseDefaultFiles()` — rewrites `/` to `/index.html` before `UseStaticFiles()`.
- `UseDirectoryBrowser()` — lists directory contents (use only in dev).

#### Routing & Endpoints
- `UseRouting()` — matches the request to an endpoint definition; populates `IEndpointFeature`.
- `MapControllers()` / `MapGet()` etc. — registers endpoint handlers; implicitly calls `UseEndpoints()`.

#### Authentication & Authorization
- `UseAuthentication()` — runs the authentication handler(s), populates `HttpContext.User`.
- `UseAuthorization()` — checks the `[Authorize]` attribute or policy on the matched endpoint.

#### CORS
- `UseCors()` — adds CORS response headers; handles preflight `OPTIONS` requests.
- Must come after `UseRouting()` so endpoint metadata (CORS policy name) is available.

#### Session & Cookies
- `UseSession()` — enables session state (requires `AddSession()` in DI).
- `UseCookiePolicy()` — enforces cookie consent, SameSite policy.

#### Response Compression
- `UseResponseCompression()` — GZip/Brotli compression for responses.

#### Request Localization
- `UseRequestLocalization()` — sets culture from query/cookie/header.

### Middleware that is a no-op if placed wrong

| Middleware | Breaks if placed after... |
|---|---|
| `UseAuthentication` | `UseAuthorization` — auth principal not set |
| `UseCors` | `MapControllers` — CORS headers already too late for preflight |
| `UseStaticFiles` | `UseRouting` — route matches first, static files never served |
| `UseExceptionHandler` | Any middleware it should catch |

## Code Example

```csharp
// Program.cs — full production pipeline in correct order

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddAuthentication().AddJwtBearer();
builder.Services.AddAuthorization();
builder.Services.AddCors(opts =>
    opts.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));
builder.Services.AddResponseCompression(opts => opts.EnableForHttps = true);

var app = builder.Build();

// Error handling — must be first
if (app.Environment.IsDevelopment())
    app.UseDeveloperExceptionPage();
else
    app.UseExceptionHandler("/error");

// Transport security
app.UseHsts();
app.UseHttpsRedirection();

// Static content — before routing to short-circuit early
app.UseStaticFiles();

// Routing — establish endpoint metadata
app.UseRouting();

// Cross-cutting — after routing (can read endpoint), before execution
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseResponseCompression();

// Endpoints
app.MapControllers();
app.MapGet("/error", () => Results.Problem());

app.Run();
```

## Common Follow-up Questions

- Why must `UseAuthentication` come before `UseAuthorization`?
- What is the effect of calling `UseStaticFiles` after `MapControllers`?
- How does `UseExceptionHandler` re-execute the request to the error path — doesn't it create a loop?
- How do you add a custom middleware that runs between routing and authorization?
- What changed in .NET 6 regarding the need to call `UseRouting()` and `UseEndpoints()` explicitly?

## Common Mistakes / Pitfalls

- **Calling `app.UseHsts()` in Development** — HSTS tells browsers to only use HTTPS for a year. Using it in dev will break `http://localhost` for a long time.
- **Forgetting `UseAuthentication` before `UseAuthorization`** — `HttpContext.User` is anonymous, every `[Authorize]` endpoint returns 401 or 403.
- **Placing `UseCors` before `UseRouting`** — endpoint-level CORS policies won't be applied since the endpoint hasn't been matched yet.
- **Adding `UseResponseCompression` after `MapControllers`** — responses are already written; compression has no effect.
- **Calling `UseDefaultFiles` after `UseStaticFiles`** — `UseDefaultFiles` is a URL rewriter that must run before `UseStaticFiles` to rewrite `/` to `/index.html` before the static files middleware tries to serve it.

## References

- [Microsoft Learn — ASP.NET Core middleware order](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/?view=aspnetcore-8.0#middleware-order)
- [Microsoft Learn — Static files in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/static-files?view=aspnetcore-8.0)
- [Microsoft Learn — Authentication and authorization](https://learn.microsoft.com/aspnet/core/security/?view=aspnetcore-8.0)
- [Andrew Lock — The ASP.NET Core middleware pipeline](https://andrewlock.net/tag/middleware/) (verify URL)
