# Aggregate Invariants

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `aggregate-invariants`, `always-valid`, `guard-clauses`, `domain-model`, `defensive-programming`

## Question

> What is the "always-valid domain model" principle? How do you enforce aggregate invariants using constructor guards, factory methods, and domain methods? What techniques prevent the aggregate from entering an invalid state?

## Short Answer

An **always-valid domain model** means the domain objects can never be in an invalid state — if a construction or mutation would violate a business rule, it throws immediately rather than allowing the invalid state to exist. This is enforced by: factory methods (hide constructor, validate before creating), private/`init`-only setters (prevent external mutation), method-based state transitions (`order.Submit()` not `order.Status = "Submitted"`), and guard clauses at the top of every method that changes state. Combined, these techniques make invalid states **unrepresentable** in the type system.

## Detailed Explanation

### The Core Principle

If an `Order` can only have a positive total, then `new Order { Total = -100 }` should be impossible. If only a `Pending` order can be submitted, then calling `Submit()` on a non-pending order should throw immediately, not set a flag that will be checked later by some validator.

### Technique 1: Factory Method (Hide the Constructor)

```csharp
public class Order : AggregateRoot
{
    // Private constructor — forces all creation through Create()
    private Order() { }

    // Factory method validates before constructing
    public static Order Create(CustomerId customerId, IEnumerable<OrderLine> lines)
    {
        ArgumentNullException.ThrowIfNull(customerId);
        var lineList = lines?.ToList() ?? [];
        if (lineList.Count == 0)
            throw new DomainException("An order must have at least one line.");
        if (lineList.Any(l => l.Quantity <= 0))
            throw new DomainException("All order lines must have positive quantity.");

        var order = new Order();
        order._customerId = customerId;
        foreach (var line in lineList) order._lines.Add(line);
        order.RecalculateTotal();
        return order;
    }
}
```

### Technique 2: Guard Clauses in Every Mutation

```csharp
public void AddLine(ProductId productId, int quantity, Money unitPrice)
{
    // Guard: state pre-conditions
    if (Status != OrderStatus.Draft)
        throw new DomainException($"Cannot add lines to an order in {Status} status.");

    // Guard: argument invariants
    ArgumentNullException.ThrowIfNull(productId);
    ArgumentOutOfRangeException.ThrowIfNegativeOrZero(quantity);
    ArgumentNullException.ThrowIfNull(unitPrice);
    if (unitPrice.Amount <= 0)
        throw new DomainException("Unit price must be positive.");

    // Guard: business invariant
    if (_lines.Count >= MaxLinesPerOrder)
        throw new DomainException($"An order cannot exceed {MaxLinesPerOrder} lines.");

    _lines.Add(new OrderLine(productId, quantity, unitPrice));
    RecalculateTotal();
}

private const int MaxLinesPerOrder = 100;
```

### Technique 3: State Machine Transitions

Represent status transitions explicitly — only valid transitions are methods:

```csharp
public enum OrderStatus { Draft, Submitted, Confirmed, Shipped, Cancelled }

public class Order : AggregateRoot
{
    public OrderStatus Status { get; private set; } = OrderStatus.Draft;

    // Only DRAFT orders can be submitted
    public void Submit()
    {
        GuardStatus(OrderStatus.Draft, "submit");
        if (!_lines.Any()) throw new DomainException("Cannot submit an empty order.");
        Status = OrderStatus.Submitted;
        Raise(new OrderSubmittedEvent(Id, _customerId, Total));
    }

    // Only SUBMITTED orders can be confirmed
    public void Confirm()
    {
        GuardStatus(OrderStatus.Submitted, "confirm");
        Status = OrderStatus.Confirmed;
        Raise(new OrderConfirmedEvent(Id));
    }

    // DRAFT or SUBMITTED orders can be cancelled (not shipped)
    public void Cancel(string reason)
    {
        if (Status is not (OrderStatus.Draft or OrderStatus.Submitted))
            throw new DomainException($"Cannot cancel an order in {Status} status.");
        Status = OrderStatus.Cancelled;
        Raise(new OrderCancelledEvent(Id, reason));
    }

    private void GuardStatus(OrderStatus required, string action)
    {
        if (Status != required)
            throw new DomainException($"Cannot {action} an order in {Status} status. Expected {required}.");
    }
}
```

### Technique 4: Encapsulate Collections

Never expose mutable collections — all modifications through methods:

```csharp
// ✅ Correct: private backing field, ReadOnly exposed
private readonly List<OrderLine> _lines = [];
public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();

// ❌ Wrong: public list lets anyone bypass guards
public List<OrderLine> Lines { get; set; } = [];
// caller can do: order.Lines.Add(new OrderLine(-1, -99)); // no invariant check
```

### Technique 5: Value Object Validation

Push validation into the Value Object — then any `Money`, `Email`, or `Address` is guaranteed valid by construction:

```csharp
public record Email
{
    public string Value { get; }

    public Email(string value)
    {
        if (!value.Contains('@') || value.Length < 5)
            throw new DomainException($"'{value}' is not a valid email address.");
        Value = value.Trim().ToLowerInvariant();
    }
}

// Now any method accepting Email is guaranteed to receive a valid one
public void UpdateContactEmail(Email email) => _contactEmail = email;
// No null check or format check needed in the method — Email ctor already validated
```

### Domain Exception vs ArgumentException

```csharp
// Use ArgumentException for: null/empty/range violations on method parameters
ArgumentNullException.ThrowIfNull(productId);                        // parameter validation
ArgumentOutOfRangeException.ThrowIfNegativeOrZero(quantity);

// Use DomainException for: business rule violations
if (Total > MaxOrderAmount)
    throw new DomainException($"Order total {Total} exceeds maximum {MaxOrderAmount}.");
if (Status != OrderStatus.Pending)
    throw new OrderNotPendingException(Id, Status);                   // more specific
```

## Code Example

```csharp
// Complete always-valid Order aggregate
public class Order : AggregateRoot
{
    private CustomerId _customerId;
    private readonly List<OrderLine> _lines = [];
    private static readonly Money MaxOrderAmount = new(50_000m);

    private Order() { }  // EF Core needs parameterless

    public OrderId Id { get; private set; }
    public CustomerId CustomerId => _customerId;
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();
    public Money Total { get; private set; } = Money.Zero;
    public OrderStatus Status { get; private set; } = OrderStatus.Draft;

    public static Order Create(CustomerId customerId)
    {
        ArgumentNullException.ThrowIfNull(customerId);
        var order = new Order { _customerId = customerId };
        return order;
    }

    public void AddLine(ProductId productId, int quantity, Money unitPrice)
    {
        if (Status != OrderStatus.Draft)
            throw new DomainException("Lines can only be added to draft orders.");
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(quantity);
        if (unitPrice.Amount <= 0)
            throw new DomainException("Unit price must be positive.");

        _lines.Add(new OrderLine(productId, quantity, unitPrice));
        RecalculateTotal();

        // Invariant: order total cap
        if (Total > MaxOrderAmount)
        {
            _lines.RemoveAt(_lines.Count - 1); // undo
            RecalculateTotal();
            throw new DomainException($"Adding this line would exceed the order maximum of {MaxOrderAmount}.");
        }
    }

    public void Submit()
    {
        if (Status != OrderStatus.Draft) throw new DomainException("Only draft orders can be submitted.");
        if (_lines.Count == 0) throw new DomainException("Cannot submit an empty order.");
        Status = OrderStatus.Submitted;
        Raise(new OrderSubmittedEvent(Id, _customerId, Total));
    }

    private void RecalculateTotal()
        => Total = _lines.Aggregate(Money.Zero, (acc, l) => acc + l.Subtotal);
}
```

## Common Follow-up Questions

- How do you handle invariants that require a database lookup (e.g., "product must exist")?
- Should domain exceptions extend `Exception` or be custom exception types?
- How do you test invariant enforcement without a full integration setup?
- When does an invariant belong in the aggregate vs in a domain service vs in an application handler?
- How do you handle concurrent modifications to the same aggregate — can two threads violate an invariant?

## Common Mistakes / Pitfalls

- **Validating in the application handler instead of the entity**: if `PlaceOrderHandler` checks "order total must be > 0" before calling a domain method, any other handler can bypass the check. The invariant belongs in the entity.
- **Invariants that depend on external state (I/O)**: an invariant like "product must be in the active catalog" requires a database lookup — that's not a domain invariant, it's a consistency check belonging in the Application layer.
- **Catch-all `DomainException` everywhere**: throwing generic `DomainException("something bad happened")` makes programmatic error handling impossible. Use specific exception types for specific violations.
- **Empty object anti-pattern**: allowing `new Order()` with no ID, no customer, no state to compile successfully and then relying on application code to "fill it in" violates the always-valid principle from the start.

## References

- [Always-valid domain model — Vladimir Khorikov](https://enterprisecraftsmanship.com/posts/always-valid-domain-model/) (verify URL)
- [Implementing value objects — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: domain-layer-design.md](./domain-layer-design.md)
- [See: entity-vs-value-object.md](./entity-vs-value-object.md)
