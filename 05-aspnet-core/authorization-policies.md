# Authorization Policies in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🟡 Middle
**Tags:** `authorization`, `policies`, `IAuthorizationService`, `AddAuthorization`, `RequireClaim`, `IAuthorizationRequirement`

## Question

> How do you define and apply authorization policies in ASP.NET Core? What is the difference between role-based, claim-based, and policy-based authorization?

## Short Answer

**Role-based** authorization checks `ClaimTypes.Role` claims (`[Authorize(Roles = "Admin")]`). **Claim-based** checks for the presence of a specific claim (`RequireClaim`). **Policy-based** is the most flexible — you compose requirements via `AuthorizationPolicyBuilder` and implement custom `IAuthorizationRequirement`+`IAuthorizationHandler` pairs for any logic. All three ultimately use the `IAuthorizationService` pipeline; policies are recommended for new code because they decouple authorization logic from controller attributes.

## Detailed Explanation

### Three authorization styles

```csharp
// 1. Role-based (simple, but tightly coupled to role names)
[Authorize(Roles = "Admin,Manager")]

// 2. Claim-based (checks claim presence/value)
builder.Services.AddAuthorization(opts =>
    opts.AddPolicy("HasEmail", policy => policy.RequireClaim(ClaimTypes.Email)));

[Authorize(Policy = "HasEmail")]

// 3. Policy-based (custom requirement + handler — most flexible)
[Authorize(Policy = "MinimumAge")]
```

### Defining policies

```csharp
builder.Services.AddAuthorization(opts =>
{
    // Require authenticated user with a specific claim value
    opts.AddPolicy("SeniorDev", policy => policy
        .RequireAuthenticatedUser()
        .RequireClaim("experience_years", "5", "6", "7", "8", "9", "10+"));

    // Combine multiple requirements (AND logic)
    opts.AddPolicy("AdminInEurope", policy => policy
        .RequireRole("Admin")
        .RequireClaim("region", "EU"));

    // Fallback policy — applied to all endpoints without explicit [Authorize]/[AllowAnonymous]
    opts.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();

    // Default policy — applied when [Authorize] is used without a policy name
    opts.DefaultPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});
```

### Custom requirement and handler

```csharp
// Requirement (data only)
public sealed record MinimumAgeRequirement(int MinimumAge) : IAuthorizationRequirement;

// Handler (logic)
public sealed class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MinimumAgeRequirement requirement)
    {
        var dobClaim = context.User.FindFirst(c => c.Type == ClaimTypes.DateOfBirth);
        if (dobClaim is null) return Task.CompletedTask; // don't call Succeed — let it fail

        if (!DateOnly.TryParse(dobClaim.Value, out var dob))
            return Task.CompletedTask;

        var age = DateOnly.FromDateTime(DateTime.Today).Year - dob.Year;
        if (dob > DateOnly.FromDateTime(DateTime.Today).AddYears(-age))
            age--;

        if (age >= requirement.MinimumAge)
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

```csharp
// Registration
builder.Services.AddSingleton<IAuthorizationHandler, MinimumAgeHandler>();
builder.Services.AddAuthorization(opts =>
    opts.AddPolicy("Over18", policy =>
        policy.Requirements.Add(new MinimumAgeRequirement(18))));
```

### Multiple handlers for the same requirement (OR logic)

If multiple handlers are registered for the same `IAuthorizationRequirement`, authorization succeeds if **any one** handler calls `context.Succeed()`.

### `IAuthorizationService` imperative authorization

```csharp
[HttpGet("{id}")]
public async Task<IActionResult> GetDocument(
    int id,
    IAuthorizationService authz)
{
    var document = await _repo.GetByIdAsync(id);
    if (document is null) return NotFound();

    var result = await authz.AuthorizeAsync(User, document, "DocumentOwner");
    if (!result.Succeeded) return Forbid();

    return Ok(document);
}
```

Resource-based authorization (passing the document as resource) is useful when the policy logic depends on the resource itself.

## Code Example

```csharp
// SubscriptionRequirement — checks user's subscription tier
public sealed record SubscriptionRequirement(SubscriptionTier Minimum) : IAuthorizationRequirement;

public sealed class SubscriptionHandler(ISubscriptionService subscriptions)
    : AuthorizationHandler<SubscriptionRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx,
        SubscriptionRequirement req)
    {
        var userId = ctx.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId is null) return;

        var tier = await subscriptions.GetTierAsync(userId);
        if (tier >= req.Minimum)
            ctx.Succeed(req);
    }
}

// Registration
builder.Services.AddScoped<IAuthorizationHandler, SubscriptionHandler>();
builder.Services.AddAuthorization(opts =>
{
    opts.AddPolicy("ProOrAbove", p => p.Requirements.Add(new SubscriptionRequirement(SubscriptionTier.Pro)));
    opts.AddPolicy("EnterpriseOnly", p => p.Requirements.Add(new SubscriptionRequirement(SubscriptionTier.Enterprise)));
});

// Controller usage
[HttpGet("advanced-report")]
[Authorize(Policy = "ProOrAbove")]
public Task<IActionResult> GetAdvancedReport() { ... }
```

## Common Follow-up Questions

- What is the difference between `FallbackPolicy` and `DefaultPolicy`?
- How do you unit-test a custom `IAuthorizationHandler`?
- What happens when multiple `IAuthorizationHandler` implementations handle the same requirement?
- How do you combine `[Authorize(Policy = "A")]` and `[Authorize(Policy = "B")]` on the same controller?
- What is `context.Fail()` vs doing nothing in a handler, and when would you call it?

## Common Mistakes / Pitfalls

- **Not registering `IAuthorizationHandler` in DI** — custom handlers that are not registered are silently ignored; policy appears to never succeed.
- **Calling `context.Fail()` instead of simply returning** — `context.Fail()` short-circuits all other handlers for that policy (even those that would succeed). Only call `Fail()` when you definitively want to prevent access regardless of other handlers.
- **Using `[Authorize(Roles = ...)]` for complex logic** — role strings become magic constants scattered across attributes; move to named policies for maintainability.
- **Combining `[Authorize(Policy = "A")] [Authorize(Policy = "B")]` expecting OR logic** — stacked `[Authorize]` attributes apply AND logic (both must pass). For OR, implement a single policy with multiple handlers.
- **Not adding `RequireAuthenticatedUser()` to policies** — without it, an unauthenticated user (empty `ClaimsPrincipal`) passes a policy that doesn't check authentication; always add it to custom policies.

## References

- [Microsoft Learn — Policy-based authorization](https://learn.microsoft.com/aspnet/core/security/authorization/policies?view=aspnetcore-8.0)
- [Microsoft Learn — Resource-based authorization](https://learn.microsoft.com/aspnet/core/security/authorization/resourcebased?view=aspnetcore-8.0)
- [Microsoft Learn — Claims-based authorization](https://learn.microsoft.com/aspnet/core/security/authorization/claims?view=aspnetcore-8.0)
- [Microsoft — AuthorizationHandler source](https://github.com/dotnet/aspnetcore/blob/main/src/Security/Authorization/Core/src/AuthorizationHandler.cs)
