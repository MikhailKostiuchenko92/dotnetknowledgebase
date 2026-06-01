# Resource-Based Authorization in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🔴 Senior
**Tags:** `IAuthorizationService`, `resource-based-authorization`, `IAuthorizationRequirement`, `IAuthorizationHandler`, `AuthorizationHandler`

## Question

> When and how do you implement resource-based authorization in ASP.NET Core? How does `IAuthorizationService.AuthorizeAsync(user, resource, policy)` differ from attribute-based `[Authorize]`?

## Short Answer

**Attribute-based authorization** (`[Authorize(Policy = "X")]`) is evaluated before the action runs and has no access to the action's resource/return value. **Resource-based authorization** calls `IAuthorizationService.AuthorizeAsync(user, resource, requirement)` imperatively inside the action, passing the loaded resource as context. Use it when the authorization decision depends on **the specific resource** — e.g., "can this user edit *this* document?" where the document's owner field determines the answer.

## Detailed Explanation

### Why attribute authorization is not enough

```csharp
// [Authorize] runs before the action — no access to the loaded resource
[Authorize(Policy = "DocumentOwner")]  // Can't evaluate — document not loaded yet!
[HttpPut("{id}")]
public async Task<IActionResult> UpdateDocument(int id, UpdateDocumentRequest req) { ... }
```

Resource-based authorization loads the resource first, then checks:

```csharp
[HttpPut("{id}")]
public async Task<IActionResult> UpdateDocument(int id, UpdateDocumentRequest req)
{
    var document = await _repo.GetByIdAsync(id); // Load first
    if (document is null) return NotFound();

    // Now check authorization against the loaded resource
    var result = await _authService.AuthorizeAsync(User, document, "DocumentOwner");
    if (!result.Succeeded) return Forbid();

    // Proceed with update
    document.Apply(req);
    await _repo.SaveAsync(document);
    return NoContent();
}
```

### Implementing a resource-based handler

```csharp
// Requirement (marker — no data needed here)
public sealed class DocumentOwnerRequirement : IAuthorizationRequirement;

// Handler receives the resource as second generic parameter
public sealed class DocumentOwnerHandler
    : AuthorizationHandler<DocumentOwnerRequirement, Document>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        DocumentOwnerRequirement requirement,
        Document resource)
    {
        var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId is not null && resource.OwnerId == userId)
            context.Succeed(requirement);

        // Also allow admins
        if (context.User.IsInRole("Admin"))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

### Policy registration with a resource-based requirement

```csharp
builder.Services.AddSingleton<IAuthorizationHandler, DocumentOwnerHandler>();

builder.Services.AddAuthorization(opts =>
    opts.AddPolicy("DocumentOwner", policy =>
        policy.Requirements.Add(new DocumentOwnerRequirement())));
```

### Using `OperationAuthorizationRequirement` for CRUD operations

A single handler can handle multiple operations (Create, Read, Update, Delete):

```csharp
// Pre-defined operation requirements
public static class DocumentOperations
{
    public static OperationAuthorizationRequirement Read   = new() { Name = "Read" };
    public static OperationAuthorizationRequirement Update = new() { Name = "Update" };
    public static OperationAuthorizationRequirement Delete = new() { Name = "Delete" };
}

// Handler
public sealed class DocumentOperationsHandler
    : AuthorizationHandler<OperationAuthorizationRequirement, Document>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx,
        OperationAuthorizationRequirement req,
        Document doc)
    {
        var userId = ctx.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        bool isOwner = userId is not null && doc.OwnerId == userId;
        bool isAdmin = ctx.User.IsInRole("Admin");

        var allowed = req.Name switch
        {
            "Read"   => isOwner || doc.IsPublic || isAdmin,
            "Update" => isOwner || isAdmin,
            "Delete" => isAdmin, // only admins can delete
            _        => false
        };

        if (allowed) ctx.Succeed(req);
        return Task.CompletedTask;
    }
}
```

```csharp
// Usage in controller
[HttpDelete("{id}")]
public async Task<IActionResult> Delete(int id, IAuthorizationService authz)
{
    var document = await _repo.GetByIdAsync(id);
    if (document is null) return NotFound();

    var result = await authz.AuthorizeAsync(User, document, DocumentOperations.Delete);
    if (!result.Succeeded) return Forbid();

    await _repo.DeleteAsync(document);
    return NoContent();
}
```

### Returning 404 vs 403 — information leakage

A common security consideration: returning 404 for unauthorized resource access prevents information leakage (attacker doesn't know the resource exists):

```csharp
var result = await authz.AuthorizeAsync(User, document, DocumentOperations.Read);
if (!result.Succeeded)
    return document.IsPublic ? Forbid() : NotFound(); // hide existence from unauthorized users
```

## Code Example

```csharp
// Document service with embedded resource-based authorization
public sealed class DocumentService(
    IDocumentRepository repo,
    IAuthorizationService authz,
    IHttpContextAccessor http)
{
    private ClaimsPrincipal User => http.HttpContext!.User;

    public async Task<Document> GetOrThrowAsync(int id, CancellationToken ct = default)
    {
        var doc = await repo.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Document {id}");

        var result = await authz.AuthorizeAsync(User, doc, DocumentOperations.Read);
        if (!result.Succeeded)
            throw new ForbiddenException("Access denied");

        return doc;
    }

    public async Task UpdateAsync(int id, UpdateDocumentRequest req, CancellationToken ct = default)
    {
        var doc = await repo.GetByIdAsync(id, ct) ?? throw new NotFoundException($"Document {id}");

        var result = await authz.AuthorizeAsync(User, doc, DocumentOperations.Update);
        if (!result.Succeeded)
            throw new ForbiddenException("Cannot update document you don't own");

        doc.Apply(req);
        await repo.SaveAsync(doc, ct);
    }
}
```

## Common Follow-up Questions

- How do you test a resource-based authorization handler in isolation?
- What is the difference between `AuthorizationHandlerContext` and `AuthorizationFilterContext`?
- When would you use `context.Fail()` in a resource-based handler?
- How do you apply resource-based authorization to minimal API endpoints?
- How do you compose multiple resource-based requirements (AND logic vs OR logic)?

## Common Mistakes / Pitfalls

- **Using `[Authorize(Policy = "DocumentOwner")]` for resource-based rules** — the policy runs before the action without the resource; the handler has no resource to evaluate.
- **Registering `IAuthorizationHandler` for a resource type without the correct generic signature** — a handler registered as `IAuthorizationHandler` without the resource type parameter receives a `null` resource in `HandleRequirementAsync`.
- **Forgetting to register the handler in DI** — resource-based handlers are silently ignored if not registered; the policy never succeeds.
- **Not distinguishing 403 from 404** — revealing that a resource exists (by returning 403 instead of 404) can aid enumeration attacks.
- **Injecting `IHttpContextAccessor` into services to access the user** — tightly couples service logic to HTTP context; prefer passing `ClaimsPrincipal` explicitly as a parameter.

## References

- [Microsoft Learn — Resource-based authorization](https://learn.microsoft.com/aspnet/core/security/authorization/resourcebased?view=aspnetcore-8.0)
- [Microsoft Learn — OperationAuthorizationRequirement](https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.authorization.infrastructure.operationauthorizationrequirement)
- [Microsoft — AuthorizationHandler source](https://github.com/dotnet/aspnetcore/blob/main/src/Security/Authorization/Core/src/AuthorizationHandler.cs)
- [Andrew Lock — Resource authorization in ASP.NET Core](https://andrewlock.net/tag/authorization/) (verify URL)
