# Test Data Builders

**Category:** Data Access / Testing Data Access
**Difficulty:** 🔴 Senior
**Tags:** `testing`, `test-data`, `builder-pattern`, `object-mother`, `Bogus`, `fixture`, `test-setup`

## Question

> What is the Test Data Builder (Object Mother) pattern? How do you use it to reduce test setup boilerplate in data access tests? What is the `Bogus` library, and when should you use realistic fake data vs hardcoded test data?

## Short Answer

The **Test Data Builder** pattern creates domain objects with sensible defaults in a fluent builder, allowing tests to override only the properties relevant to the scenario under test. The related **Object Mother** pattern is a factory class with predefined named configurations. Together they reduce test setup boilerplate, improve test readability, and centralize default values. **Bogus** is a .NET library that generates realistic fake data (names, emails, addresses, dates) using a seeded `Faker<T>` — useful for property-based testing and generating large realistic datasets, but random data makes tests non-deterministic unless you seed the faker.

## Detailed Explanation

### Test Data Builder Pattern

```csharp
// Builder with sensible defaults — tests override only what matters
public class OrderBuilder
{
    private int _customerId = 1;
    private decimal _total = 100m;
    private string _status = "Pending";
    private DateTime _createdAt = DateTime.UtcNow;
    private List<OrderLine> _lines = [];

    public OrderBuilder WithCustomerId(int customerId)
    {
        _customerId = customerId;
        return this;
    }

    public OrderBuilder WithTotal(decimal total)
    {
        _total = total;
        return this;
    }

    public OrderBuilder WithStatus(string status)
    {
        _status = status;
        return this;
    }

    public OrderBuilder WithLine(int productId, int quantity, decimal price)
    {
        _lines.Add(new OrderLine { ProductId = productId, Quantity = quantity, UnitPrice = price });
        return this;
    }

    public Order Build() => new()
    {
        CustomerId = _customerId,
        Total = _total,
        Status = _status,
        CreatedAt = _createdAt,
        Lines = _lines
    };
}
```

**Test usage — only specify what's relevant to the test**:
```csharp
// Test 1: status matters, other properties don't
var cancelledOrder = new OrderBuilder()
    .WithStatus("Cancelled")
    .Build();

// Test 2: total matters for pricing logic
var highValueOrder = new OrderBuilder()
    .WithCustomerId(42)
    .WithTotal(10_000m)
    .Build();

// Test 3: multiple lines matter for fulfillment test
var multiLineOrder = new OrderBuilder()
    .WithLine(productId: 1, quantity: 2, price: 50m)
    .WithLine(productId: 2, quantity: 1, price: 99m)
    .Build();
```

### Object Mother Pattern

A static factory class with named, pre-configured test objects:

```csharp
public static class TestOrders
{
    public static Order PendingOrder(int? customerId = null)
        => new OrderBuilder()
            .WithCustomerId(customerId ?? 1)
            .WithStatus("Pending")
            .WithTotal(99.99m)
            .Build();

    public static Order CancelledOrder()
        => new OrderBuilder().WithStatus("Cancelled").Build();

    public static Order HighValueOrder(int customerId)
        => new OrderBuilder()
            .WithCustomerId(customerId)
            .WithTotal(15_000m)
            .Build();

    public static IEnumerable<Order> ManyOrders(int count, int customerId = 1)
        => Enumerable.Range(1, count)
            .Select(i => new OrderBuilder()
                .WithCustomerId(customerId)
                .WithTotal(i * 10m)
                .Build());
}

// Usage in tests
var order = TestOrders.PendingOrder(customerId: 5);
var orders = TestOrders.ManyOrders(count: 20, customerId: 1);
```

### Bogus — Realistic Fake Data

`Bogus` (NuGet) generates realistic, seeded fake data:

```csharp
// NuGet: Bogus
using Bogus;

// Define a faker for Customer — same seed always produces same data
var faker = new Faker<Customer>()
    .RuleFor(c => c.Name, f => f.Name.FullName())
    .RuleFor(c => c.Email, f => f.Internet.Email())
    .RuleFor(c => c.Phone, f => f.Phone.PhoneNumber("###-###-####"))
    .RuleFor(c => c.Address, f => f.Address.StreetAddress());

// Generate 100 customers with consistent seed (for reproducible tests)
var customers = new Faker<Customer>()
    .UseSeed(42)  // ← fixed seed = deterministic data
    .RuleFor(c => c.Name, f => f.Name.FullName())
    .RuleFor(c => c.Email, f => f.Internet.Email())
    .Generate(100);
```

### When to Use What

| Scenario | Use |
|----------|-----|
| Test depends on a specific value (e.g., status = "Cancelled") | Hardcoded builder `.WithStatus("Cancelled")` |
| Test doesn't care about a value (e.g., name in an address test) | Bogus random value |
| Seeding a large dataset for performance testing | Bogus with `Generate(n)` |
| Ensuring tests are deterministic | Bogus with `.UseSeed(n)` |
| Shared, named configurations used in multiple tests | Object Mother |

### Database Integration with Builders

```csharp
// Builder that also persists to the database — "persisted builder"
public class OrderBuilder
{
    // ... previous fields ...
    private AppDbContext? _db;

    public OrderBuilder InDatabase(AppDbContext db)
    {
        _db = db;
        return this;
    }

    public async Task<Order> BuildAndSaveAsync(CancellationToken ct = default)
    {
        var order = Build();
        if (_db is not null)
        {
            _db.Orders.Add(order);
            await _db.SaveChangesAsync(ct);
        }
        return order;
    }
}

// Test: seed an order in the DB in one line
var order = await new OrderBuilder()
    .WithStatus("Pending")
    .InDatabase(db)
    .BuildAndSaveAsync();
```

## Code Example

```csharp
// Complete test showing builder + Object Mother + Bogus together
[Collection("Integration")]
public class CustomerOrderTests(IntegrationTestDatabase dbFixture)
{
    [Fact]
    public async Task HighValueCustomers_IncludeCustomersWithLargeOrders()
    {
        await using var db = dbFixture.CreateContext();

        // Use Bogus for non-relevant customer data, hardcode what matters
        var faker = new Faker<Customer>().UseSeed(42)
            .RuleFor(c => c.Name, f => f.Name.FullName())
            .RuleFor(c => c.Email, f => f.Internet.Email());

        var customer = faker.Generate();
        db.Customers.Add(customer);
        await db.SaveChangesAsync();

        // Use Object Mother for the meaningful order
        var order = TestOrders.HighValueOrder(customerId: customer.Id);
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        // Act
        var highValueCustomers = await db.Customers
            .Where(c => c.Orders.Any(o => o.Total > 10_000))
            .ToListAsync();

        // Assert
        Assert.Contains(highValueCustomers, c => c.Id == customer.Id);
    }
}
```

## Common Follow-up Questions

- How do you handle FK dependencies in test data builders (e.g., Order requires a Customer to exist first)?
- What is AutoFixture, and how does it compare to Bogus and hand-written builders?
- How do you generate test data that satisfies complex domain invariants (e.g., Order total must equal sum of line totals)?
- How do you share test data builders across multiple test projects without introducing circular dependencies?
- When should you prefer property-based testing (FsCheck, CsCheck) over example-based testing with fixed data?

## Common Mistakes / Pitfalls

- **Using unseeded random Bogus data in CI**: `new Faker<T>()` without `.UseSeed(n)` generates different data each run — a test may pass on Monday and fail on Tuesday due to a specific random value hitting an edge case. Always seed for deterministic tests.
- **Builder defaults that are invalid for the domain**: a default `Total = 0m` when the domain requires `Total > 0` will cause tests to fail in unexpected places. Use domain-valid defaults.
- **Not cleaning up data after integration tests**: builders that `BuildAndSaveAsync` to a shared database leave rows that affect other tests. Use transaction rollback or Respawn for cleanup.
- **Over-relying on Object Mother for fine-grained scenarios**: Object Mother works for a small number of named configurations. With 50 named methods, it becomes a god class. Use the builder pattern for parameterized variations.

## References

- [Test Data Builder pattern — natpryce.com](https://www.natpryce.com/articles/000714.html) (verify URL)
- [Bogus — GitHub](https://github.com/bchavez/Bogus)
- [Object Mother — MartinFowler.com](https://martinfowler.com/bliki/ObjectMother.html) (verify URL)
- [See: repository-testing-patterns.md](./repository-testing-patterns.md)
- [See: respawn-for-test-isolation.md](./respawn-for-test-isolation.md)
