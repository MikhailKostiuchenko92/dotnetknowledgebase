# Authorization Patterns

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🟡 Middle
**Tags:** `authorization`, `resource-based-auth`, `policy-based-auth`, `IAuthorizationHandler`, `claims-transformation`, `ASP.NET-Core`

## Question

> What is the difference between role-based, policy-based, and resource-based authorization in ASP.NET Core? Walk through `IAuthorizationHandler`, `IAuthorizationRequirement`, and claims transformation.

## Short Answer

**Role-based** (`[Authorize(Roles = "Admin")]`) — coarse-grained, checks a claim by name. **Policy-based** (`[Authorize(Policy = "MinimumAge")]`) — encapsulates complex rules as reusable policies registered at startup. **Resource-based** (`_authService.AuthorizeAsync(user, resource, requirement)`) — used when authorization depends on the specific resource being accessed (e.g., "can this user edit THIS order?"). `IAuthorizationHandler` contains the evaluation logic. `IClaimsTransformation` enriches the `ClaimsPrincipal` after authentication — useful for adding roles from a database per request.

## Detailed Explanation

### Role-Based (Simple)

```csharp
[Authorize(Roles = "Admin")]       // ← requires "Admin" role claim
[HttpDelete("{id}")]
public Task<IActionResult> Delete(int id, CancellationToken ct) => ...;

// Multiple roles (OR):
[Authorize(Roles = "Admin,Manager")]
// Both roles (AND): use two [Authorize] attributes
[Authorize(Roles = "Employee")]
[Authorize(Roles = "Manager")]
```

### Policy-Based (Encapsulated Rules)

```csharp
// Define requirements + handlers in a reusable policy

// 1. Requirement: a marker for what the policy checks
public record MinimumAgeRequirement(int MinAge) : IAuthorizationRequirement;

// 2. Handler: evaluation logic
public class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx, MinimumAgeRequirement req)
    {
        var birthDateClaim = ctx.User.FindFirst("birthdate")?.Value;
        if (birthDateClaim is null || !DateOnly.TryParse(birthDateClaim, out var dob))
        {
            ctx.Fail();
            return Task.CompletedTask;
        }

        var age = DateOnly.FromDateTime(DateTime.Today).Year - dob.Year;
        if (age >= req.MinAge) ctx.Succeed(req);
        return Task.CompletedTask;
    }
}

// 3. Policy registration at startup
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AtLeast18", policy =>
        policy.Requirements.Add(new MinimumAgeRequirement(18)));

    options.AddPolicy("PremiumCustomer", policy =>
        policy.RequireAuthenticatedUser()
              .RequireClaim("subscription", "premium", "enterprise"));

    options.AddPolicy("CanManageOrders", policy =>
        policy.RequireRole("Admin", "Manager")
              .RequireClaim("department", "Operations"));
});

builder.Services.AddSingleton<IAuthorizationHandler, MinimumAgeHandler>();

// 4. Usage
[Authorize(Policy = "AtLeast18")]
[HttpPost("api/orders")]
public Task<IActionResult> Place(...) => ...;
```

### Resource-Based Authorization

```csharp
// Authorization depends on the specific resource (e.g., can user edit THIS order?)

// Requirement: defines what we check against a resource
public class EditOrderRequirement : IAuthorizationRequirement { }

// Handler: evaluates requirement for a specific Order resource
public class OrderAuthorizationHandler
    : AuthorizationHandler<EditOrderRequirement, Order>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx,
        EditOrderRequirement req,
        Order order)  // ← the specific resource
    {
        var userId = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (ctx.User.IsInRole("Admin")
            || order.CustomerId.ToString() == userId)
        {
            ctx.Succeed(req);  // ← admin OR the order owner
        }
        return Task.CompletedTask;
    }
}

builder.Services.AddScoped<IAuthorizationHandler, OrderAuthorizationHandler>();

// Controller: check resource-based auth explicitly
[HttpPut("{id}")]
public async Task<IActionResult> Update(int id, [FromBody] UpdateOrderRequest req,
    IAuthorizationService authService, CancellationToken ct)
{
    var order = await _orders.GetByIdAsync(id, ct);
    if (order is null) return NotFound();

    // Evaluate authorization against the specific order object
    var authResult = await authService.AuthorizeAsync(User, order, new EditOrderRequirement());
    if (!authResult.Succeeded) return Forbid();

    await _sender.Send(new UpdateOrderCommand(id, req.Total), ct);
    return NoContent();
}
```

### Claims Transformation

```csharp
// IClaimsTransformation: enrich ClaimsPrincipal after authentication
// Called on every request — cache results to avoid repeated DB calls

public class RoleEnrichmentTransformation(IRoleRepository roleRepo, IMemoryCache cache)
    : IClaimsTransformation
{
    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null) return principal;

        // Cache roles per user (avoid DB call per request)
        var roles = await cache.GetOrCreateAsync($"roles:{userId}", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            return await roleRepo.GetUserRolesAsync(int.Parse(userId));
        });

        var identity = new ClaimsIdentity();
        foreach (var role in roles ?? [])
            identity.AddClaim(new Claim(ClaimTypes.Role, role));

        principal.AddIdentity(identity);
        return principal;
    }
}

builder.Services.AddScoped<IClaimsTransformation, RoleEnrichmentTransformation>();
```

## Code Example

```csharp
// MediatR behavior: authorization check inside CQRS pipeline
// Allows checking resource-based auth BEFORE handler executes

public class AuthorizationBehavior<TRequest, TResponse>(
    ICurrentUser currentUser, IAuthorizationService authService)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IAuthorizedRequest
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        // IAuthorizedRequest provides: resource + requirement
        var result = await authService.AuthorizeAsync(
            currentUser.ClaimsPrincipal!, req.Resource, req.Requirement);

        if (!result.Succeeded)
            throw new ForbiddenException($"Not authorized to {req.Requirement.GetType().Name}");

        return await next();
    }
}
```

## Common Follow-up Questions

- How do you handle authorization in Minimal APIs vs controller-based APIs?
- What is the difference between `[Authorize]` and `[AllowAnonymous]` scoping rules?
- How do you unit test `IAuthorizationHandler` implementations?
- How do you implement row-level security (each user sees only their own records)?
- How do you propagate authorization context in gRPC or message handler contexts?

## Common Mistakes / Pitfalls

- **Hardcoding role names as strings throughout the codebase**: `[Authorize(Roles = "Admin")]` scattered across 50 controllers. Define role constants or use policy names as the single source of truth.
- **Checking authorization inside the domain model**: domain aggregates checking `if (currentUser.IsAdmin)` couples business logic to security context. Authorization belongs in the application/presentation layer.
- **Claims transformation not caching DB results**: calling the database on every request in `IClaimsTransformation` adds significant latency. Cache results with a short TTL keyed by user ID.
- **Returning 404 instead of 403 for resource-based access denial**: returning `NotFound()` for an unauthorized access attempt hides the resource's existence but is sometimes used deliberately to prevent enumeration. Be consistent and document the decision.

## References

- [Resource-based authorization — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/resourcebased)
- [Policy-based authorization — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/policies)
- [Claims transformation — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/claims)
- [See: authentication-authorization.md](../05-aspnet-core/authentication-authorization.md)
