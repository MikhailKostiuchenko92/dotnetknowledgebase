# Vertical Slice Architecture

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟡 Middle
**Tags:** `vertical-slice`, `feature-folders`, `Jimmy-Bogard`, `CQRS`, `MediatR`, `cohesion`

## Question

> What is Vertical Slice Architecture? How does it differ from Clean Architecture's horizontal layers? When should you use Vertical Slices instead of — or alongside — Clean Architecture?

## Short Answer

Vertical Slice Architecture (Jimmy Bogard) organises code by **feature** rather than by layer. Each "slice" is a self-contained folder containing the command/query, handler, validator, DTO, and any feature-specific infra code needed for one user operation (e.g., `Features/Orders/PlaceOrder/`). Instead of enforcing a strict horizontal dependency rule, the rule is: **slices don't depend on each other**; shared infrastructure and domain code lives in a `Common/` or `Domain/` shared kernel. It trades layer purity for feature cohesion — all the code for a feature is in one place.

## Detailed Explanation

### The Core Idea

Clean Architecture (horizontal slicing) organises by concern:
```
Application/
  Handlers/PlaceOrderHandler.cs
  Interfaces/IOrderRepository.cs
  DTOs/OrderDto.cs
Infrastructure/
  Persistence/EfOrderRepository.cs
Api/
  Controllers/OrdersController.cs
```

Vertical Slice Architecture organises by feature:
```
Features/
  Orders/
    PlaceOrder/
      PlaceOrderCommand.cs    ← command + response DTO
      PlaceOrderHandler.cs    ← handler + validator + mapping in one place
      PlaceOrderEndpoint.cs   ← Minimal API endpoint or controller action
    GetOrder/
      GetOrderQuery.cs
      GetOrderHandler.cs
    CancelOrder/
      CancelOrderCommand.cs
      CancelOrderHandler.cs
  Products/
    CreateProduct/
      ...
Domain/                       ← shared kernel: entities, value objects
Common/                       ← shared infra: DbContext, middleware
```

### Why Cohesion Matters

In a horizontal layer structure, adding a new feature ("Add discount code to order") touches 5+ files across 4 different projects. A reviewer must navigate between projects to understand the full change. With Vertical Slices, the entire change for `ApplyDiscountCode` fits in one folder — easy to review, easy to delete, easy to understand.

### Rules in Vertical Slice Architecture

1. **Slices must not depend on each other.** `PlaceOrderHandler` cannot call `GetProductHandler` — instead, directly query the database.
2. **Shared code lives in a Common/Domain project.** DbContext, domain entities, base behaviors, shared validators.
3. **Duplicate code between slices is acceptable.** If two slices need similar DB queries, having two slightly different queries is preferred over sharing a repository that introduces coupling.
4. **Each slice can choose its own approach.** A simple CRUD slice can directly use `DbContext`; a complex slice might use DDD aggregates and domain events.

### Comparison: Clean Architecture vs Vertical Slices

| Aspect | Clean Architecture | Vertical Slice |
|--------|-------------------|----------------|
| Organisation axis | Technical layer (domain/app/infra) | Feature / user operation |
| Cross-feature changes | Easy (single layer, multiple features) | Harder (each feature is self-contained) |
| Single-feature changes | Harder (multiple projects touched) | Easier (one folder) |
| Reuse between features | Encouraged via interfaces | Discouraged — duplication preferred |
| Learning curve | Higher initial setup | Lower per feature |
| Domain model protection | Explicit layer boundaries | Depends on discipline / shared Domain project |
| Onboarding new feature | Must understand layers | Just add a folder |

### When to Use Vertical Slices

**Prefer Vertical Slices when:**
- Features are relatively independent (low coupling between operations)
- The team works feature-by-feature and PRs are feature-sized
- The application has many CRUD-ish features with different shapes
- Speed of feature delivery is more important than domain model purity

**Prefer Clean Architecture when:**
- The domain has rich business rules shared across many use cases
- Multiple teams work on the same domain model
- Long-term domain model integrity is critical (DDD context)

**Combine them**: use a shared `Domain/` project with rich entities and domain rules (Clean Architecture domain layer), but organise the Application/Infrastructure code as vertical slices (feature folders). This is a popular hybrid approach.

## Code Example

```csharp
// Features/Orders/PlaceOrder/PlaceOrderCommand.cs
namespace YourApp.Features.Orders.PlaceOrder;

public record PlaceOrderCommand(int CustomerId, decimal Total) : IRequest<int>;

public record PlaceOrderResponse(int OrderId);

// Features/Orders/PlaceOrder/PlaceOrderHandler.cs
// Handler, validator, and mapping all in one file — everything for THIS slice
public class PlaceOrderHandler(AppDbContext db) : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // Vertical slice: query DB directly, no repository abstraction needed for simple cases
        var order = new Order
        {
            CustomerId = cmd.CustomerId,
            Total = cmd.Total,
            Status = "Pending",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
        return order.Id;
    }
}

public class PlaceOrderValidator : AbstractValidator<PlaceOrderCommand>
{
    public PlaceOrderValidator()
    {
        RuleFor(x => x.CustomerId).GreaterThan(0);
        RuleFor(x => x.Total).GreaterThan(0);
    }
}

// Features/Orders/PlaceOrder/PlaceOrderEndpoint.cs (Minimal API)
public static class PlaceOrderEndpoint
{
    public static IEndpointRouteBuilder MapPlaceOrder(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/orders", async (PlaceOrderCommand cmd, ISender sender, CancellationToken ct) =>
        {
            var id = await sender.Send(cmd, ct);
            return Results.Created($"/api/orders/{id}", new PlaceOrderResponse(id));
        })
        .WithName("PlaceOrder")
        .WithTags("Orders")
        .Produces<PlaceOrderResponse>(StatusCodes.Status201Created)
        .ProducesValidationProblem();
        return app;
    }
}
```

## Common Follow-up Questions

- How do you share common domain logic (e.g., discount calculations) between slices without creating coupling?
- How do you enforce the "slices don't depend on each other" rule in CI?
- Does Vertical Slice Architecture conflict with Domain-Driven Design?
- How do you handle transactions that span multiple slices?
- How do you organise integration tests for Vertical Slice Architecture?

## Common Mistakes / Pitfalls

- **Slices calling other slices**: `PlaceOrderHandler` importing `GetCustomerQuery` to validate the customer creates cross-slice coupling. Instead, validate inline or use a shared domain service.
- **Putting domain invariants in every slice**: if "order total must be > 0" is checked in 5 different handlers, a new way to create an order bypasses all of them. Rich domain entities centralize rules regardless of slice structure.
- **Fighting the approach for simple CRUD**: Vertical Slices excel for independent features. A `UserSettings` feature that's just CRUD doesn't need a rich slice — but shoehorning it into layers creates needless indirection.
- **No shared domain layer**: without a `Domain/` project, value objects and invariants get duplicated or skipped. Always keep a shared domain kernel even with Vertical Slices.

## References

- [Vertical Slice Architecture — Jimmy Bogard](https://www.jimmybogard.com/vertical-slice-architecture/) (verify URL)
- [Mixing Clean Architecture with Vertical Slices — Andrew Lock](https://andrewlock.net/) (verify URL)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
