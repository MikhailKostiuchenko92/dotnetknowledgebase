# Validation Strategies

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🟡 Middle
**Tags:** `FluentValidation`, `DataAnnotations`, `validation`, `application-layer`, `domain-layer`, `guard-clauses`, `validation-placement`

## Question

> What are the options for validation in a .NET application — `DataAnnotations`, `FluentValidation`, and domain guard clauses? Where should validation live (presentation layer vs application layer vs domain layer), and what should each layer validate?

## Short Answer

**Three layers of validation, each with a distinct purpose**: (1) **Domain guard clauses** — enforce business invariants that must always hold (`if (amount <= 0) throw new ArgumentException()`). (2) **Application layer validation** (FluentValidation) — validate command/query inputs before handler execution (format, required fields, business rules needing external data). (3) **Presentation layer** (DataAnnotations) — simple model binding validation for ASP.NET Core, primarily for Swagger documentation and model binding errors. Never substitute domain validation with just DataAnnotations — they only fire on HTTP model binding, not when domain code is called from tests or other contexts.

## Detailed Explanation

### DataAnnotations (Presentation Layer)

```csharp
// [Required], [Range], [StringLength], [EmailAddress], etc.
// Applied to API models / DTOs — validated by ASP.NET Core model binding
// Pros: Zero configuration, Swagger integration
// Cons: Logic-poor (no cross-field rules), coupled to ASP.NET Core, poor error messages

public record PlaceOrderRequest(
    [Required, Range(1, int.MaxValue)] int CustomerId,
    [Required, MinLength(1)] List<OrderLineRequest> Lines);

// Automatically validated by [ApiController] attribute — returns 400 on failure
```

### FluentValidation (Application Layer)

```csharp
// Expressive, testable, supports async rules, no framework coupling
// Register via DI — used in MediatR pipeline or manually

public class PlaceOrderCommandValidator : AbstractValidator<PlaceOrderCommand>
{
    public PlaceOrderCommandValidator(ICustomerRepository customers)
    {
        RuleFor(x => x.CustomerId)
            .GreaterThan(0)
            .MustAsync(async (id, ct) => await customers.ExistsAsync(id, ct))
            .WithMessage("Customer does not exist");

        RuleFor(x => x.Lines)
            .NotEmpty().WithMessage("Order must have at least one item");

        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(l => l.ProductId).GreaterThan(0);
            line.RuleFor(l => l.Quantity).InclusiveBetween(1, 1000);
        });
    }
}
```

### Domain Guard Clauses (Domain Layer)

```csharp
// Domain invariants — always-valid model principle
// The domain aggregate is responsible for its own consistency
// Guard clauses fire regardless of caller (HTTP, tests, CLI, batch jobs)

public class Money
{
    public decimal Amount { get; }
    public string Currency { get; }

    public Money(decimal amount, string currency)
    {
        // Domain invariant — must hold in ALL contexts
        if (amount < 0) throw new ArgumentException("Amount cannot be negative", nameof(amount));
        if (string.IsNullOrWhiteSpace(currency)) throw new ArgumentException("Currency required", nameof(currency));
        if (currency.Length != 3) throw new ArgumentException("Currency must be 3-char ISO code", nameof(currency));

        Amount = amount;
        Currency = currency;
    }
}

public class Order
{
    private Order() { }

    public static Order Create(CustomerId customerId, IReadOnlyList<OrderLine> lines)
    {
        if (!customerId.IsValid()) throw new ArgumentException("Invalid customer ID");
        if (lines.Count == 0) throw new BusinessRuleException("Order must have at least one line");
        // ... build and return
    }

    public void Cancel(string reason)
    {
        if (Status == OrderStatus.Shipped) throw new BusinessRuleException("Cannot cancel a shipped order");
        // ...
    }
}
```

### Validation Placement Rules

| Validation Type | Layer | When It Fires |
|----------------|-------|--------------|
| Input format (required, ranges, format) | Application (FluentValidation) | Before handler |
| Business rules needing DB lookup ("customer exists") | Application (FluentValidation async) | Before handler |
| Domain invariants ("amount > 0") | Domain (guard clauses) | When aggregate is created/mutated |
| HTTP model binding (Swagger docs) | Presentation (DataAnnotations) | HTTP request deserialization |
| Security/authz checks | Application + Infrastructure | Authorization middleware/handler |

### Cross-Field Validation

```csharp
// FluentValidation: cross-field rules that DataAnnotations can't express
public class DateRangeValidator : AbstractValidator<GetOrdersQuery>
{
    public DateRangeValidator()
    {
        RuleFor(x => x.EndDate)
            .GreaterThanOrEqualTo(x => x.StartDate)
            .WithMessage("End date must be after start date");

        RuleFor(x => x.EndDate)
            .LessThanOrEqualTo(x => x.StartDate.AddYears(1))
            .WithMessage("Date range cannot exceed 1 year");
    }
}
```

## Code Example

```csharp
// All three layers working together

// 1. DataAnnotations on API model (Swagger + model binding):
public record CreateOrderRequest([Required] int CustomerId, [Required, MinLength(1)] List<LineItem> Lines);

// 2. FluentValidation on Application command:
public class PlaceOrderCommandValidator : AbstractValidator<PlaceOrderCommand>
{
    public PlaceOrderCommandValidator()
    {
        RuleFor(x => x.CustomerId).GreaterThan(0);
        RuleFor(x => x.Lines).NotEmpty();
        RuleForEach(x => x.Lines).ChildRules(l => l.RuleFor(x => x.Quantity).GreaterThan(0));
    }
}

// 3. Domain guard clauses in aggregate:
public class Order
{
    public static Order Create(CustomerId cid, IReadOnlyList<OrderLine> lines)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(cid.Value);
        if (lines.Count == 0) throw new BusinessRuleException("No lines");
        // ...
    }
}
```

## Common Follow-up Questions

- How do you prevent duplicate validation logic between DataAnnotations and FluentValidation?
- When is it appropriate to use `IValidatableObject` vs FluentValidation?
- How do you validate configuration classes (`IOptions<T>`) at startup?
- How do you return structured validation errors in ProblemDetails RFC 7807 format?
- How do you test FluentValidation validators independently?

## Common Mistakes / Pitfalls

- **Only using DataAnnotations for domain validation**: DataAnnotations don't fire when domain code is invoked from unit tests or non-HTTP contexts. Domain invariants must be enforced in the domain itself.
- **Putting business rules in FluentValidation that belong in the domain**: "customer can't order more than $10,000 per day" is a business rule — putting it in a validator couples it to the application layer and makes it testable only through the HTTP stack.
- **Async FluentValidation for every field**: adding DB round-trips to validate every command field adds latency. Validate format/structure synchronously; only use `MustAsync` for rules genuinely requiring external data.
- **DataAnnotations on domain/application layer models**: DataAnnotations on domain entities couple them to ASP.NET Core, violating the clean architecture rule that domain layers have no framework dependencies.

## References

- [FluentValidation documentation](https://docs.fluentvalidation.net/)
- [DataAnnotations — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/api/system.componentmodel.dataannotations)
- [See: command-validation-pipeline.md](./command-validation-pipeline.md)
- [See: problem-details-rfc7807.md](./problem-details-rfc7807.md)
