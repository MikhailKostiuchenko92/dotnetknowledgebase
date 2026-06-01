# Filter Ordering and Scope in ASP.NET Core

**Category:** ASP.NET Core / Filters
**Difficulty:** 🟡 Middle
**Tags:** `IOrderedFilter`, `filter-scope`, `filter-order`, `global`, `controller`, `action`

## Question

> How does ASP.NET Core determine the execution order of multiple filters of the same type? How do you override the default ordering?

## Short Answer

By default, filters execute by scope: **Global → Controller → Action** (before stage) and **Action → Controller → Global** (after stage), forming a matryoshka nesting. To override this, implement `IOrderedFilter` and set the `Order` property — lower values run in the before stage first and after stage last. Filters at the same `Order` value fall back to scope ordering. Negative `Order` values run before default (0) filters.

## Detailed Explanation

### Default scope ordering

ASP.NET Core builds the effective filter list for each action by collecting filters from:
1. Global (`MvcOptions.Filters`)
2. Controller-level attributes
3. Action-level attributes

For the **before phase** (e.g., `OnActionExecuting`), they run Global → Controller → Action.
For the **after phase** (e.g., `OnActionExecuted`), they run Action → Controller → Global.

```
Before:   [Global 1] → [Global 2] → [Controller] → [Action]
After:    [Action] → [Controller] → [Global 2] → [Global 1]
```

This means global filters are the outermost wrapper — they see the request first and the response last.

### `IOrderedFilter`

```csharp
public interface IOrderedFilter : IFilterMetadata
{
    int Order { get; }
}
```

Filters with lower `Order` values run earlier in the before phase and later in the after phase. Filters at the same `Order` value fall back to scope ordering.

```
Order=-1  →  Order=0 (default)  →  Order=1
```

### Built-in filter order values

| Filter | Default Order |
|---|---|
| `[Authorize]` | `int.MinValue` (first) |
| `[ValidateAntiForgeryToken]` | no fixed order |
| Custom filters | 0 (default) |

`[Authorize]` runs at `int.MinValue` to ensure it always runs first, before any other filter. This is why authorization cannot be "bypassed" by setting a negative `Order` on a custom filter — you'd need to go below `int.MinValue`, which is impossible.

### Implementing `IOrderedFilter`

```csharp
public sealed class CorrelationIdFilter : IActionFilter, IOrderedFilter
{
    public int Order => -10; // run before all default (Order=0) filters

    public void OnActionExecuting(ActionExecutingContext context)
    {
        if (!context.HttpContext.Request.Headers.TryGetValue("X-Correlation-ID", out var id))
            id = Guid.NewGuid().ToString("N");

        context.HttpContext.Items["CorrelationId"] = id.ToString();
    }

    public void OnActionExecuted(ActionExecutedContext context)
    {
        var id = context.HttpContext.Items["CorrelationId"]?.ToString();
        context.HttpContext.Response.Headers["X-Correlation-ID"] = id;
    }
}
```

### Filter execution visualization with mixed orders

```
Filters registered:
  Global  CorrelationIdFilter  Order=-10
  Global  AuditFilter          Order=0  (default)
  Action  ValidateFilter       Order=0  (default)

Before phase execution order:
  CorrelationIdFilter.Before  (Order=-10, outermost)
  AuditFilter.Before          (Order=0, global scope)
  ValidateFilter.Before       (Order=0, action scope)
  → Action executes

After phase execution order:
  ValidateFilter.After
  AuditFilter.After
  CorrelationIdFilter.After   (outermost wrapper closes last)
```

### Using `FilterScope` constants

ASP.NET Core exposes `FilterScope` constants for clarity:

```csharp
public static class FilterScope
{
    public const int First   = int.MinValue;
    public const int Global  = 10;
    public const int Controller = 20;
    public const int Action  = 30;
    public const int Last    = int.MaxValue;
}
```

## Code Example

```csharp
// Filter ordering demo — three global filters with explicit orders
public sealed class FirstFilter : IActionFilter, IOrderedFilter
{
    public int Order => -10;
    public void OnActionExecuting(ActionExecutingContext ctx) =>
        Console.WriteLine("[FirstFilter] Before");
    public void OnActionExecuted(ActionExecutedContext ctx) =>
        Console.WriteLine("[FirstFilter] After");
}

public sealed class MiddleFilter : IActionFilter, IOrderedFilter
{
    public int Order => 0; // same as default
    public void OnActionExecuting(ActionExecutingContext ctx) =>
        Console.WriteLine("[MiddleFilter] Before");
    public void OnActionExecuted(ActionExecutedContext ctx) =>
        Console.WriteLine("[MiddleFilter] After");
}

public sealed class LastFilter : IActionFilter, IOrderedFilter
{
    public int Order => 10;
    public void OnActionExecuting(ActionExecutingContext ctx) =>
        Console.WriteLine("[LastFilter] Before");
    public void OnActionExecuted(ActionExecutedContext ctx) =>
        Console.WriteLine("[LastFilter] After");
}

// Registration
builder.Services.AddControllers(opts =>
{
    opts.Filters.Add<FirstFilter>();
    opts.Filters.Add<LastFilter>();
    opts.Filters.Add<MiddleFilter>();
});

// Output when action runs:
// [FirstFilter] Before
// [MiddleFilter] Before
// [LastFilter] Before
// [LastFilter] After
// [MiddleFilter] After
// [FirstFilter] After
```

```csharp
// Shorthand: custom ordered filter base attribute
public abstract class OrderedFilterAttribute(int order) : ActionFilterAttribute, IOrderedFilter
{
    public override int Order { get; } = order;
}

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public sealed class EarlyValidationAttribute() : OrderedFilterAttribute(-5) { ... }
```

## Common Follow-up Questions

- What is the execution order when `IOrderedFilter.Order` values are equal?
- Why does `[Authorize]` always run first, and can you place a filter before it?
- How does filter ordering interact with async filters that call `await next()`?
- What is the difference between `FilterScope.First` and `Order = int.MinValue`?
- How do you verify the effective filter execution order for a specific action at runtime?

## Common Mistakes / Pitfalls

- **Assuming higher `Order` value means "earlier"** — it's the opposite: lower `Order` = earlier in before phase = later in after phase (outermost wrapper).
- **Expecting scope to override explicit `Order`** — once `Order` is set, scope ordering is secondary. A global filter with `Order=100` runs after an action filter with `Order=0`.
- **Attempting to run a custom filter before `[Authorize]`** — `[Authorize]` has `Order = int.MinValue`. Custom filters cannot precede it with `IOrderedFilter` since you cannot go lower.
- **Not implementing `IOrderedFilter` on a filter registered via `MvcOptions.Filters.Add<T>()`** — without an explicit `Order`, the filter uses scope-based ordering, which may not match expectations when mixed with ordered filters.
- **Forgetting the "matryoshka" inversion** — the filter with the lowest `Order` wraps all others; its `OnActionExecuted` runs **last**, not first.

## References

- [Microsoft Learn — Filter ordering](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#filter-ordering)
- [Microsoft Learn — IOrderedFilter](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#iorderedfilter)
- [Microsoft — FilterScope constants source](https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Core/src/Filters/FilterScope.cs)
- [Andrew Lock — Understanding filter execution order](https://andrewlock.net/tag/filters/) (verify URL)
