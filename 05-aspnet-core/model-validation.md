# Model Validation in ASP.NET Core

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟡 Middle
**Tags:** `model-validation`, `DataAnnotations`, `ModelState`, `ApiController`, `FluentValidation`, `400`

## Question

> How does model validation work in ASP.NET Core? How does `[ApiController]` automate 400 responses, and how do you integrate FluentValidation?

## Short Answer

Model validation checks bound model objects against rules defined via Data Annotations (`[Required]`, `[Range]`, etc.) after model binding completes. `ModelState.IsValid` reflects the result. With `[ApiController]`, if `ModelState` is invalid the framework automatically returns a `400 Bad Request` with a `ValidationProblemDetails` body before the action runs. FluentValidation provides a richer, code-based alternative to attribute validation and integrates via `IValidator<T>`.

## Detailed Explanation

### Data Annotations validation

```csharp
public sealed class CreateProductRequest
{
    [Required]
    [MaxLength(200)]
    public string Name { get; init; } = string.Empty;

    [Range(0.01, 999_999.99, ErrorMessage = "Price must be between 0.01 and 999,999.99")]
    public decimal Price { get; init; }

    [Required]
    [StringLength(50, MinimumLength = 3)]
    public string Category { get; init; } = string.Empty;

    [Url]
    public string? ImageUrl { get; init; }
}
```

### `ModelState` — manual validation

Without `[ApiController]`, you check `ModelState` manually:

```csharp
[HttpPost]
public IActionResult Create([FromBody] CreateProductRequest request)
{
    if (!ModelState.IsValid)
        return BadRequest(ModelState); // 400 with error dictionary

    // proceed
}
```

### `[ApiController]` automatic 400

With `[ApiController]`, the framework adds an `IActionFilter` (before action runs) that:
1. Checks `ModelState.IsValid`.
2. If invalid, calls the `InvalidModelStateResponseFactory` delegate.
3. Returns `400 ValidationProblemDetails` automatically.

You don't need the `if (!ModelState.IsValid)` check:

```csharp
[ApiController]
[Route("api/products")]
public class ProductsController : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateProductRequest request)
    {
        // If request violates DataAnnotations, this action never runs
        var product = await _service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }
}
```

### Customizing the automatic 400 response

```csharp
builder.Services.Configure<ApiBehaviorOptions>(opts =>
{
    opts.InvalidModelStateResponseFactory = context =>
    {
        var problemDetails = new ValidationProblemDetails(context.ModelState)
        {
            Status = StatusCodes.Status422UnprocessableEntity,
            Title = "Validation failed",
            Instance = context.HttpContext.Request.Path
        };
        return new UnprocessableEntityObjectResult(problemDetails);
    };
});
```

### FluentValidation integration

FluentValidation provides rules in code, supports async validation, and enables complex cross-property rules:

```csharp
// Product validator
public sealed class CreateProductRequestValidator : AbstractValidator<CreateProductRequest>
{
    public CreateProductRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(200);

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .LessThanOrEqualTo(999_999.99m);

        RuleFor(x => x.Category)
            .NotEmpty()
            .MinimumLength(3)
            .MaximumLength(50);

        // Cross-property rule: luxury products must have image
        RuleFor(x => x.ImageUrl)
            .NotEmpty()
            .When(x => x.Price > 10_000, ApplyConditionTo.CurrentValidator)
            .WithMessage("Luxury products (price > 10,000) must have an image URL");
    }
}
```

```csharp
// Registration
builder.Services.AddValidatorsFromAssemblyContaining<CreateProductRequestValidator>();
// Integrates with ModelState when using FluentValidation.AspNetCore (legacy)
// Or use minimal API endpoint filter approach (recommended in .NET 7+)
```

```csharp
// Minimal API endpoint filter for FluentValidation
public sealed class ValidationFilter<T>(IValidator<T> validator) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx,
        EndpointFilterDelegate next)
    {
        if (ctx.Arguments.OfType<T>().FirstOrDefault() is { } model)
        {
            var result = await validator.ValidateAsync(model, ctx.HttpContext.RequestAborted);
            if (!result.IsValid)
                return TypedResults.ValidationProblem(result.ToDictionary());
        }
        return await next(ctx);
    }
}
```

## Code Example

```csharp
// Full validation flow with FluentValidation + minimal API

// CreateOrderRequest.cs
public sealed record CreateOrderRequest(
    [property: Required] string CustomerId,
    List<OrderLineRequest> Lines);

public sealed record OrderLineRequest(
    [property: Required] string ProductId,
    [property: Range(1, 1000)] int Quantity);

// OrderValidator.cs
public sealed class CreateOrderRequestValidator : AbstractValidator<CreateOrderRequest>
{
    public CreateOrderRequestValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty().MaximumLength(50);

        RuleFor(x => x.Lines).NotEmpty().WithMessage("Order must have at least one line");

        RuleForEach(x => x.Lines).SetValidator(new OrderLineValidator());
    }
}

public sealed class OrderLineValidator : AbstractValidator<OrderLineRequest>
{
    public OrderLineValidator()
    {
        RuleFor(x => x.ProductId).NotEmpty();
        RuleFor(x => x.Quantity).InclusiveBetween(1, 1000);
    }
}
```

```csharp
// Program.cs
builder.Services.AddValidatorsFromAssemblyContaining<Program>();

var orders = app.MapGroup("/api/orders").WithTags("Orders").RequireAuthorization();

orders.MapPost("/", async Task<Results<Created<Order>, ValidationProblem>>
    (CreateOrderRequest req,
     IOrderService svc,
     IValidator<CreateOrderRequest> validator,
     CancellationToken ct) =>
{
    var validation = await validator.ValidateAsync(req, ct);
    if (!validation.IsValid)
        return TypedResults.ValidationProblem(validation.ToDictionary());

    var order = await svc.CreateAsync(req, ct);
    return TypedResults.Created($"/api/orders/{order.Id}", order);
});
```

## Common Follow-up Questions

- How do you suppress the automatic 400 behavior from `[ApiController]` for specific actions?
- How do you add custom model validation that requires a database lookup (async validation)?
- How does FluentValidation compare to Data Annotations in performance and expressiveness?
- How do you return `422 Unprocessable Entity` instead of `400 Bad Request` for validation failures?
- How do you validate nested complex types and collections?

## Common Mistakes / Pitfalls

- **Relying solely on client-side validation** — never skip server-side validation; clients can bypass it.
- **Using Data Annotations for business rules** — `[Required]`, `[Range]` are for structural validation. Business rules (e.g., "customer must exist") belong in the domain/service layer.
- **Checking `ModelState.IsValid` after `[ApiController]` auto-400** — with `[ApiController]` the action is never called if `ModelState` is invalid; the check is dead code.
- **Not configuring `InvalidModelStateResponseFactory`** — the default response format may not match your API's error contract. Customize it to return consistent `ProblemDetails`.
- **FluentValidation validators with Scoped dependencies registered as Singleton** — if a validator injects a Scoped service (e.g., repository), register the validator as Scoped, not Singleton (which is the default in some versions).

## References

- [Microsoft Learn — Model validation in ASP.NET Core](https://learn.microsoft.com/aspnet/core/mvc/models/validation?view=aspnetcore-8.0)
- [Microsoft Learn — [ApiController] automatic HTTP 400 responses](https://learn.microsoft.com/aspnet/core/web-api/?view=aspnetcore-8.0#automatic-http-400-responses)
- [FluentValidation — Getting started](https://docs.fluentvalidation.net/en/latest/aspnet.html)
- [FluentValidation — ASP.NET Core integration](https://docs.fluentvalidation.net/en/latest/aspnet.html)
- [Andrew Lock — FluentValidation and minimal APIs](https://andrewlock.net/tag/validation/) (verify URL)
