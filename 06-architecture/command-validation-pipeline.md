# Command Validation Pipeline

**Category:** Architecture / Mediator & Pipeline
**Difficulty:** 🔴 Senior
**Tags:** `MediatR`, `FluentValidation`, `IPipelineBehavior`, `ValidationException`, `Result-pattern`, `error-handling`

## Question

> How do you implement command validation in the MediatR pipeline with FluentValidation? Compare throwing `ValidationException` vs returning a `Result<T>` — trade-offs and when to use each approach.

## Short Answer

The standard approach: `ValidationBehavior<TRequest, TResponse>` runs FluentValidation validators before the handler and throws `ValidationException` on failure — caught by an exception handler middleware that returns HTTP 400. The `Result<T>` pattern alternative: the behavior (or handler) returns `Result<T>` containing either the value or a list of errors — no exceptions thrown. Throwing is simpler and more idiomatic for public APIs where validation failures are exceptional. The Result pattern is better for internal service calls where exceptions are expensive, or when the "failure" is a normal business outcome (not exceptional).

## Detailed Explanation

### FluentValidation + Behavior (Exception-Based)

```csharp
// FluentValidation validator — co-located with command
public class PlaceOrderCommandValidator : AbstractValidator<PlaceOrderCommand>
{
    public PlaceOrderCommandValidator(IProductRepository products)
    {
        RuleFor(x => x.CustomerId)
            .GreaterThan(0).WithMessage("Customer ID is required");

        RuleFor(x => x.Lines)
            .NotEmpty().WithMessage("Order must have at least one line");

        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.ProductId).GreaterThan(0);
            line.RuleFor(l => l.Quantity).GreaterThan(0).LessThanOrEqualTo(100);
            line.RuleFor(l => l.Price).GreaterThan(0);
        });

        // Async rule: validate ProductId exists
        RuleFor(x => x.Lines)
            .MustAsync(async (lines, ct) =>
            {
                var ids = lines.Select(l => l.ProductId);
                var count = await products.CountByIdsAsync(ids, ct);
                return count == ids.Distinct().Count();
            }).WithMessage("One or more product IDs do not exist");
    }
}

// Behavior: validate all commands before handler runs
public class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var ctx = new ValidationContext<TRequest>(req);
        var failures = (await Task.WhenAll(validators.Select(v => v.ValidateAsync(ctx, ct))))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count > 0) throw new ValidationException(failures);
        return await next();
    }
}

// Global exception handler: maps ValidationException → HTTP 400
public class ValidationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        if (ex is not ValidationException ve) return false;

        ctx.Response.StatusCode = StatusCodes.Status400BadRequest;
        await ctx.Response.WriteAsJsonAsync(new ValidationProblemDetails(
            ve.Errors.GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray())
        ), ct);
        return true;
    }
}
```

### Result Pattern Alternative

```csharp
// Result<T>: discriminated union — either success or error list
public class Result<T>
{
    public T? Value { get; private init; }
    public List<string> Errors { get; private init; } = [];
    public bool IsSuccess => Errors.Count == 0;

    public static Result<T> Success(T value) => new() { Value = value };
    public static Result<T> Failure(IEnumerable<string> errors) => new() { Errors = errors.ToList() };
}

// ValidationBehavior with Result pattern: no exceptions thrown
public class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, Result<TResponse>>
    where TRequest : notnull
{
    public async Task<Result<TResponse>> Handle(
        TRequest req, RequestHandlerDelegate<Result<TResponse>> next, CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var ctx = new ValidationContext<TRequest>(req);
        var failures = (await Task.WhenAll(validators.Select(v => v.ValidateAsync(ctx, ct))))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .Select(f => f.ErrorMessage)
            .ToList();

        return failures.Count > 0
            ? Result<TResponse>.Failure(failures)
            : await next();
    }
}

// Handler uses Result<T>
public class PlaceOrderHandler : IRequestHandler<PlaceOrderCommand, Result<int>>
{
    public async Task<Result<int>> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // Validation already done by behavior — handler only has business logic
        var order = Order.Create(new CustomerId(cmd.CustomerId));
        await _orders.AddAsync(order, ct);
        return Result<int>.Success(order.Id.Value);
    }
}

// Controller: explicit Result handling
var result = await sender.Send(new PlaceOrderCommand(7, 99.99m), ct);
return result.IsSuccess ? Created(result.Value) : BadRequest(result.Errors);
```

### Comparison

| | ValidationException | Result<T> |
|--|--------------------|---------| 
| **HTTP 400 mapping** | Global exception handler | Explicit in controller |
| **Stack trace overhead** | Yes (expensive) | No |
| **Code clarity** | Clean (no if/else in handler) | Explicit (more verbose at call sites) |
| **Testing** | Assert.Throws | Assert result.IsSuccess |
| **Best for** | Public API input validation | Internal service calls, domain logic failures |
| **Library support** | Well-supported (FluentValidation.AspNetCore) | Requires custom Result type or OneOf/ErrorOr |

### ErrorOr Library (Modern Result Pattern)

```csharp
// NuGet: ErrorOr
using ErrorOr;

public record PlaceOrderCommand(int CustomerId, decimal Total) : IRequest<ErrorOr<int>>;

public class PlaceOrderHandler : IRequestHandler<PlaceOrderCommand, ErrorOr<int>>
{
    public async Task<ErrorOr<int>> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        if (cmd.CustomerId <= 0)
            return Error.Validation("CustomerId", "Customer ID must be positive");

        var order = Order.Create(new CustomerId(cmd.CustomerId));
        await _orders.AddAsync(order, ct);
        return order.Id.Value; // ← implicit conversion to ErrorOr<int>
    }
}

// Controller: match on success/error
var result = await sender.Send(cmd, ct);
return result.Match<IActionResult>(
    id => Created($"/orders/{id}", id),
    errors => Problem(errors.First().Description));
```

## Code Example

```csharp
// Full FluentValidation + MediatR setup
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());

builder.Services.AddValidatorsFromAssemblyContaining<PlaceOrderCommand>();

builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddProblemDetails();
```

## Common Follow-up Questions

- How do you return structured validation errors in ProblemDetails format (RFC 7807)?
- How do you validate business rules that require DB access (e.g., "customer exists")?
- What is the `OneOf` library, and how does it compare to ErrorOr?
- How do you test validation behavior independently of the actual command handler?
- When does throwing exceptions become a performance problem in high-throughput APIs?

## Common Mistakes / Pitfalls

- **Business rule validation in FluentValidation**: FluentValidation is for input format/structure validation (format, ranges, required fields). Business rules ("can only order if account is not suspended") belong in the domain aggregate or application handler.
- **Calling the database in FluentValidation async rules for every request**: DB round-trips in validators add latency. Prefer fast structural validation in FluentValidation and do DB-dependent checks in the handler.
- **Missing exception handler registration**: `ValidationException` not handled globally produces a 500 Internal Server Error instead of 400 Bad Request.
- **Mixed Exception + Result pattern**: using `ValidationException` for some commands and `Result<T>` for others in the same codebase creates inconsistent error handling. Choose one approach and apply it consistently.

## References

- [FluentValidation with ASP.NET Core](https://docs.fluentvalidation.net/en/latest/aspnet.html)
- [ErrorOr library — GitHub](https://github.com/amantinband/error-or)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
- [See: problem-details-rfc7807.md](./problem-details-rfc7807.md)
