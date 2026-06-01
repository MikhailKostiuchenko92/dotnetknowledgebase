# CORS Middleware in ASP.NET Core

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟡 Middle
**Tags:** `cors`, `cross-origin`, `preflight`, `OPTIONS`, `AddCors`, `UseCors`, `credentials`

## Question

> How does CORS work in ASP.NET Core? How do you configure policies, handle preflight OPTIONS requests, and manage the `credentials` restriction?

## Short Answer

CORS (Cross-Origin Resource Sharing) is enforced by the `UseCors()` middleware, which adds the correct response headers based on a named or default policy defined with `AddCors()`. For non-simple requests (custom headers, non-GET/POST methods), browsers send a preflight `OPTIONS` request; ASP.NET Core handles this automatically. The `AllowCredentials()` configuration requires a specific `AllowedOrigins` list — `AllowAnyOrigin()` and `AllowCredentials()` cannot be combined.

## Detailed Explanation

### How CORS works (browser-side)

1. Browser detects a cross-origin request (different scheme/host/port).
2. For **simple requests** (GET/HEAD/POST with safe headers): browser sends the request and checks `Access-Control-Allow-Origin` in the response.
3. For **non-simple requests** (DELETE, PUT, custom headers like `Authorization`): browser first sends an `OPTIONS` preflight request.
4. The server must respond to the preflight with the appropriate `Access-Control-Allow-*` headers.
5. If the preflight succeeds, the browser sends the real request.

> **Important:** CORS is a **browser security mechanism**. Server-to-server calls (e.g., `HttpClient`, Postman, curl) are never subject to CORS. CORS headers do not secure your API — use proper authentication/authorization for that.

### Registering policies

```csharp
builder.Services.AddCors(options =>
{
    // Named policy
    options.AddPolicy("AllowMyFrontend", policy =>
        policy.WithOrigins("https://app.example.com", "https://admin.example.com")
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Content-Type", "Authorization")
              .AllowCredentials());   // allows cookies/auth headers cross-origin

    // Default policy (applied when UseCors() is called without a name)
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader());
    // Note: AllowAnyOrigin + AllowCredentials = INVALID (throws)
});
```

### Applying CORS

Global (all endpoints):
```csharp
app.UseCors("AllowMyFrontend");
```

Per-endpoint (controller):
```csharp
[EnableCors("AllowMyFrontend")]
[HttpGet]
public IActionResult Get() => Ok();

[DisableCors]
[HttpGet("internal")]
public IActionResult Internal() => Ok();
```

Per-endpoint (minimal API):
```csharp
app.MapGet("/api/data", () => Results.Ok())
   .RequireCors("AllowMyFrontend");
```

### Preflight handling

ASP.NET Core handles preflight `OPTIONS` requests automatically when `UseCors()` is in the pipeline and `UseRouting()` is called before it. The framework:
1. Detects the `OPTIONS` method + `Origin` + `Access-Control-Request-Method` headers.
2. Evaluates the matching policy.
3. Returns a `204 No Content` response with `Access-Control-Allow-*` headers.
4. Does **not** pass the request to your controller.

### Credentials restriction

When the browser sends `credentials: 'include'` (cookies, HTTP auth):

| Configuration | Result |
|---|---|
| `AllowAnyOrigin()` + `AllowCredentials()` | ❌ Throws `InvalidOperationException` |
| `WithOrigins("https://x.com")` + `AllowCredentials()` | ✅ Valid |
| `SetIsOriginAllowed(_ => true)` + `AllowCredentials()` | ✅ Allows all but reflects actual origin |

The browser also requires the server to echo the specific `Origin` back in `Access-Control-Allow-Origin` (not `*`) when credentials are included.

### Exposed response headers

By default, browsers only expose a limited set of "safe" response headers to JavaScript. To expose custom headers:

```csharp
policy.WithExposedHeaders("X-Pagination", "X-RateLimit-Remaining");
```

## Code Example

```csharp
// Program.cs — production CORS configuration

builder.Services.AddCors(options =>
{
    options.AddPolicy("ApiCors", policy =>
    {
        policy
            .WithOrigins(
                "https://app.mycompany.com",
                "https://admin.mycompany.com")
            .WithMethods(HttpMethods.Get, HttpMethods.Post,
                         HttpMethods.Put, HttpMethods.Delete, HttpMethods.Patch)
            .WithHeaders(HeaderNames.Authorization, HeaderNames.ContentType,
                         "X-Requested-With", "X-Api-Version")
            .WithExposedHeaders("X-Pagination-Total", "X-RateLimit-Remaining")
            .AllowCredentials()
            .SetPreflightMaxAge(TimeSpan.FromMinutes(10)); // cache preflight result
    });

    // Loose policy for internal tools (dev/staging only)
    options.AddPolicy("DevCors", policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();

// UseCors MUST come after UseRouting and before UseAuthentication/UseAuthorization
app.UseRouting();
app.UseCors("ApiCors");          // apply named policy globally
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

```csharp
// Controller with per-action CORS override
[ApiController]
[Route("api/[controller]")]
[EnableCors("ApiCors")]          // applies to all actions in this controller
public class ProductsController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok();

    [HttpDelete("{id}")]
    [EnableCors("ApiCors")]      // explicit (redundant here but shows intent)
    public IActionResult Delete(int id) => NoContent();

    [HttpGet("internal-stats")]
    [DisableCors]                // no CORS headers — internal only
    public IActionResult Stats() => Ok();
}
```

## Common Follow-up Questions

- What happens if `UseCors()` is placed before `UseRouting()`? Does per-endpoint CORS still work?
- Why does `AllowAnyOrigin() + AllowCredentials()` throw at startup rather than at request time?
- How do you dynamically validate origins (e.g., all subdomains of `*.example.com`)?
- How do you debug CORS issues — the browser shows a CORS error but no `Access-Control-Allow-Origin` header?
- How do you configure CORS differently for development vs production environments?

## Common Mistakes / Pitfalls

- **Placing `UseCors` before `UseRouting`** — per-endpoint CORS policies won't be applied; only the global policy works.
- **Combining `AllowAnyOrigin()` with `AllowCredentials()`** — this throws at startup because it violates the CORS spec and would be a security hole.
- **Thinking CORS secures the API** — CORS only restricts browser-based cross-origin access. Any non-browser client can call your API regardless. Use authentication/authorization for security.
- **Not caching preflight with `SetPreflightMaxAge`** — without it, the browser sends a preflight before every non-simple request, doubling request count.
- **Forgetting `WithExposedHeaders` for custom response headers** — JavaScript cannot read custom headers (e.g., `X-Pagination`) unless they are explicitly exposed in the CORS policy.

## References

- [Microsoft Learn — Enable CORS in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/cors?view=aspnetcore-8.0)
- [MDN — Cross-Origin Resource Sharing (CORS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [MDN — CORS preflight requests](https://developer.mozilla.org/en-US/docs/Glossary/Preflight_request)
- [Andrew Lock — CORS in ASP.NET Core](https://andrewlock.net/tag/cors/) (verify URL)
- [Microsoft — CorsPolicyBuilder source](https://github.com/dotnet/aspnetcore/blob/main/src/Middleware/CORS/src/Infrastructure/CorsPolicyBuilder.cs)
