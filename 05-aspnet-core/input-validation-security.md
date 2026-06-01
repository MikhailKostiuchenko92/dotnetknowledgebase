# Input Validation and XSS Prevention in ASP.NET Core

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `XSS`, `HtmlEncoder`, `mass-assignment`, `[BindProperty]`, `[Bind]`, `input-validation`

## Question

> How do you prevent Cross-Site Scripting (XSS) and mass assignment vulnerabilities in ASP.NET Core APIs? When do you need to use `HtmlEncoder`, and what is the `[BindProperty]` vs `[Bind]` trade-off?

## Short Answer

**XSS prevention:** For APIs returning JSON, HTML encoding is not needed (JSON is not rendered as HTML). For Razor/server-rendered HTML, Razor auto-encodes output by default; use `Html.Raw()` only for trusted content and always encode user data with `HtmlEncoder.Default.Encode()` when building HTML manually. **Mass assignment:** Use separate DTOs (request models) instead of passing domain entities to bind directly. The `[Bind]` allowlist and `[BindProperty]` with `SupportsGet` are model-layer guardrails, but DTO separation is the safest approach.

## Detailed Explanation

### XSS: HTML encoding with Razor

Razor's `@` syntax HTML-encodes by default:

```html
<!-- Safe: Razor encodes this output -->
<h1>@Model.UserName</h1>
<!-- Rendered: <h1>&lt;script&gt;alert(1)&lt;/script&gt;</h1> -->

<!-- UNSAFE: Raw output — only for trusted content (e.g., CMS HTML) -->
@Html.Raw(Model.HtmlContent)
```

### XSS: Manual HTML encoding in C#

```csharp
using System.Text.Encodings.Web;

var userInput = "<script>alert('xss')</script>";
var encoded = HtmlEncoder.Default.Encode(userInput);
// Output: &lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;

// URL encoding
var urlEncoded = UrlEncoder.Default.Encode(userInput);

// JavaScript encoding (for embedding in <script> blocks)
var jsEncoded = JavaScriptEncoder.Default.Encode(userInput);
```

### XSS: JSON API responses

**APIs that return `application/json` do NOT need HTML encoding** — JSON is parsed by JavaScript, not rendered as HTML. The browser's JSON parser is not vulnerable to XSS. Adding HTML encoding to JSON responses corrupts the output.

```csharp
// ❌ WRONG — corrupts JSON string content
return Ok(new { Name = HtmlEncoder.Default.Encode(user.Name) });

// ✅ CORRECT for JSON API — no encoding needed
return Ok(new { user.Name });
```

### Mass assignment vulnerability

Mass assignment occurs when user input is bound directly to an entity with more fields than the user should control:

```csharp
// ❌ VULNERABLE — user can POST {"Email": "x", "IsAdmin": true}
[HttpPost]
public IActionResult Update([FromBody] User user) // User has IsAdmin property
{
    _db.Update(user);
    return Ok();
}
```

**Fix: Use DTOs (request models):**

```csharp
// ✅ SAFE — separate DTO only has user-controlled fields
public sealed record UpdateUserRequest(string Email, string DisplayName);

[HttpPost]
public IActionResult Update([FromBody] UpdateUserRequest req)
{
    var user = _db.Users.Find(CurrentUserId)!;
    user.Email = req.Email;
    user.DisplayName = req.DisplayName;
    // IsAdmin never touched
    _db.SaveChanges();
    return Ok();
}
```

### `[Bind]` allowlist (MVC controllers)

```csharp
// Allowlist specific properties for binding
[HttpPost]
public IActionResult Create([Bind("Name,Email")] User user)
{
    // Only Name and Email are bound; IsAdmin, PasswordHash remain default
}
```

### `[BindProperty]` in Razor Pages

```csharp
public class ProfileModel : PageModel
{
    // Only these properties are bound from form POST
    [BindProperty]
    public string DisplayName { get; set; } = "";

    [BindProperty]
    public string Email { get; set; } = "";

    // NOT bound — even if submitted in the form
    public bool IsAdmin { get; set; }
}
```

`SupportsGet = true` binds the property also from GET query strings (use carefully — GET requests should be idempotent):

```csharp
[BindProperty(SupportsGet = true)]
public string? SearchQuery { get; set; }
```

### Input validation overview

```csharp
public sealed record CreateProductRequest(
    [Required, MaxLength(200)] string Name,
    [Range(0.01, 1_000_000)] decimal Price,
    [Required, RegularExpression(@"^[a-zA-Z0-9\-]+$")] string Slug);

// With [ApiController]: automatic 400 if validation fails
// Without [ApiController]: check ModelState.IsValid manually
```

## Code Example

```csharp
// Safe DTO approach for profile update endpoint
public sealed record UpdateProfileRequest(
    [Required, MaxLength(100)] string DisplayName,
    [Required, EmailAddress, MaxLength(256)] string Email,
    [MaxLength(500)] string? Bio);

[HttpPut("profile")]
[Authorize]
public async Task<IActionResult> UpdateProfile(
    [FromBody] UpdateProfileRequest req,
    CancellationToken ct)
{
    var userId = User.FindFirst(ClaimTypes.NameIdentifier)!.Value;
    var user = await _db.Users.FindAsync([userId], ct)
        ?? throw new NotFoundException("User not found");

    // Only update fields the user owns
    user.DisplayName = req.DisplayName.Trim();
    user.Email = req.Email.ToLowerInvariant();
    user.Bio = req.Bio?.Trim();
    // user.IsAdmin, user.CreatedAt, user.PasswordHash — untouched

    await _db.SaveChangesAsync(ct);
    return NoContent();
}
```

```html
<!-- Razor: safe by default, unsafe with Html.Raw -->
<p>@Model.UserComment</p>            <!-- SAFE — auto-encoded -->
<p>@Html.Raw(Model.SafeHtmlBody)</p> <!-- UNSAFE — use only for trusted sanitized HTML -->

<!-- For CMS HTML: sanitize before storing, then output raw -->
@* Never call Html.Raw on raw user input *@
```

## Common Follow-up Questions

- What is the difference between `HtmlEncoder`, `UrlEncoder`, and `JavaScriptEncoder`?
- How does Razor auto-encoding work under the hood (`IHtmlContent`)?
- What is `AntiXssEncoder` from the old AntiXss library and does it still have a role?
- How do you sanitize HTML input (allow `<b>` but block `<script>`) when you must store and render user HTML?
- What is the OWASP Top 10 API item "Excessive Data Exposure" and how does DTO selection address it?

## Common Mistakes / Pitfalls

- **HTML-encoding API JSON responses** — JSON APIs don't need HTML encoding; encoding corrupts the string values and confuses clients.
- **Using the domain entity directly as `[FromBody]` model** — allows mass assignment; always use a dedicated request DTO.
- **Trusting `[Bind]` allowlists as the primary defense** — `[Bind]` is a convenience, not a security guarantee; DTO separation is more explicit and testable.
- **Calling `Html.Raw()` on unvalidated user input in Razor** — bypasses Razor's encoding protection and introduces XSS.
- **Not sanitizing stored HTML before rendering with `Html.Raw()`** — always sanitize with a library (HtmlSanitizer) before storing user-provided HTML content intended to be rendered.

## References

- [Microsoft Learn — Prevent XSS in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/cross-site-scripting?view=aspnetcore-8.0)
- [Microsoft Learn — Prevent over-posting with mass assignment](https://learn.microsoft.com/aspnet/core/data/ef-rp/intro?view=aspnetcore-8.0) (verify URL)
- [OWASP — XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [HtmlSanitizer library](https://github.com/mganss/HtmlSanitizer)
