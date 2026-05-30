# Value Converters in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `value-converters`, `IValueConverter`, `json-columns`, `enum-mapping`, `money-type`

## Question

> What are value converters in EF Core and when do you need them? How do you write a custom `IValueConverter`, and how does JSON column mapping in EF Core 7+ relate to value converters?

## Short Answer

Value converters tell EF Core how to translate a CLR type to a database type and back. They're needed when the default mapping is wrong or insufficient — for example, storing an enum as a string instead of an integer, persisting a `Money` value object as a `decimal`, serializing a complex type to JSON, or mapping a `DateTimeOffset` to UTC ticks. EF Core ships with a set of built-in converters; you write custom ones by implementing `ValueConverter<TModel, TProvider>` and registering them via `HasConversion`. EF Core 7+ adds first-class JSON column support (`ToJson()`), which handles object graphs without manual serialisation code.

## Detailed Explanation

### How Value Converters Work

A value converter has two functions:

- **`ConvertToProvider`**: CLR → database (called before INSERT/UPDATE).
- **`ConvertFromProvider`**: database → CLR (called after SELECT).

Both must be **pure, deterministic lambda expressions** — EF Core sometimes calls them at model build time (for SQL translation), so they can't use services or closures over mutable state.

### Built-in Converters

EF Core ships converters for the most common cases. You activate them via shorthand:

```csharp
// Enum → string
builder.Property(o => o.Status).HasConversion<string>();

// Enum → int (explicit — same as default for numeric enums)
builder.Property(o => o.Status).HasConversion<int>();

// bool → "Y"/"N" string
builder.Property(o => o.IsActive)
       .HasConversion(v => v ? "Y" : "N", v => v == "Y");

// DateTimeOffset → UTC ticks (for databases that don't support timezone offset)
builder.Property(o => o.CreatedAt)
       .HasConversion(
           v => v.UtcTicks,
           v => new DateTimeOffset(v, TimeSpan.Zero));
```

### Custom `ValueConverter<TModel, TProvider>`

For reusable converters, subclass `ValueConverter<TModel, TProvider>`:

```csharp
// Money value object → decimal in DB
public sealed class MoneyConverter : ValueConverter<Money, decimal>
{
    public MoneyConverter()
        : base(
            money   => money.Amount,                          // CLR → DB
            amount  => new Money(amount, Currency.USD))       // DB → CLR
    { }
}
```

Register it in entity configuration:

```csharp
builder.Property(o => o.Price).HasConversion(new MoneyConverter());
```

For full fidelity (currency + amount), serialize to JSON instead — see below.

### JSON Columns (EF Core 7+)

`ToJson()` maps a navigation property to a single JSON column. The entire object graph is serialised as JSON using `System.Text.Json`:

```csharp
public class Order
{
    public int Id { get; set; }
    public OrderDetails Details { get; set; } = new();   // stored as JSON
}

public class OrderDetails
{
    public string Notes     { get; set; } = string.Empty;
    public string Source    { get; set; } = string.Empty;
    public List<string> Tags { get; set; } = [];
}
```

Configuration:

```csharp
builder.OwnsOne(o => o.Details, d => d.ToJson());
```

Generated schema:

```sql
ALTER TABLE Orders ADD Details NVARCHAR(MAX);   -- JSON column
```

EF Core 7+ can **filter and project inside the JSON column** in SQL (on SQL Server and PostgreSQL):

```csharp
// SQL Server: generates JSON_VALUE / OPENJSON queries
var orders = await db.Orders
    .Where(o => o.Details.Source == "web")
    .Select(o => new { o.Id, o.Details.Notes })
    .ToListAsync(ct);
```

### Enum as String (Most Common Use Case)

Storing enum as string is safer for schema evolution — adding a new enum member doesn't break existing rows:

```csharp
// ❌ Default: OrderStatus.Shipped stored as integer 2
// Problem: reordering enum members silently corrupts data

// ✅ Store as string — robust to reordering and renaming (via migration)
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.Property(o => o.Status)
               .HasConversion<string>()
               .HasMaxLength(30);
    }
}
```

### Applying a Converter to All Properties of a Type (Bulk Configuration)

EF Core 7+ `ConfigureConventions` applies converters globally:

```csharp
protected override void ConfigureConventions(ModelConfigurationBuilder conventions)
{
    // All enum properties stored as strings globally
    conventions.Properties<Enum>().HaveConversion<string>();

    // All DateTimeOffset properties stored as UTC ticks
    conventions.Properties<DateTimeOffset>()
               .HaveConversion<DateTimeOffsetToUtcTicksConverter>();
}
```

### Limitations of Value Converters

> **Warning:** EF Core cannot always translate a value converter's `ConvertToProvider` expression to SQL. If you use a converter that isn't translatable, EF Core silently pulls data to the client for filtering — causing a full table scan. Always test complex converters with query logging enabled.

Composite value objects (e.g., `Money` with amount + currency) need two columns or JSON — a single `ValueConverter` converts to a single provider type. For multi-column VOs, use `OwnsOne` instead.

## Code Example

```csharp
// Custom converter: strongly-typed ID → int (prevents primitive obsession errors)
public sealed class OrderId
{
    public int Value { get; }
    public OrderId(int value) => Value = value;
    public static implicit operator int(OrderId id) => id.Value;
    public static implicit operator OrderId(int id) => new(id);
}

public sealed class OrderIdConverter : ValueConverter<OrderId, int>
{
    public OrderIdConverter()
        : base(id => id.Value, value => new OrderId(value)) { }
}

// Register in configuration
builder.Property(o => o.Id)
       .HasConversion(new OrderIdConverter());

// Full example: Order with all three patterns
public class Order
{
    public OrderId       Id      { get; set; }    // strongly-typed ID → int
    public OrderStatus   Status  { get; set; }    // enum → string
    public OrderDetails  Details { get; set; } = new();  // JSON column (.NET 7+)
}

public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Id).HasConversion(new OrderIdConverter());

        builder.Property(o => o.Status)
               .HasConversion<string>()
               .HasMaxLength(30);

        builder.OwnsOne(o => o.Details, d => d.ToJson());
    }
}
```

## Common Follow-up Questions

- Why can't you use a value converter's `ConvertToProvider` function in a LINQ `Where` clause and expect SQL translation?
- How does EF Core 7+ JSON column mapping compare to manually serialising to a string column?
- What is the difference between `HasConversion` and `OwnsOne(...).ToJson()` for complex objects?
- How do you write a value converter for a `List<string>` stored as a comma-separated string?
- Can you combine a value converter with a `ValueComparer` to ensure EF Core detects changes correctly?

## Common Mistakes / Pitfalls

- **Missing `ValueComparer` for collection converters**: When converting `List<T>` to a JSON string, EF Core uses reference equality by default to detect changes. Without a custom `ValueComparer`, the change tracker won't detect in-place mutations. Always pair converters on mutable types with a `ValueComparer`.
- **Non-translatable converters in `Where` clauses**: A converter involving complex logic (e.g., calling a method) won't translate to SQL. EF Core may silently evaluate client-side — monitor with query logging.
- **Applying `HasConversion<string>()` on a large enum set without max length**: Results in an `NVARCHAR(MAX)` column — set `.HasMaxLength(N)` alongside the conversion.
- **Multi-column value objects via single converter**: A `Money(decimal Amount, string Currency)` can't be stored in one column without losing information (unless you serialise to JSON). Use `OwnsOne` for multi-property VOs.
- **`ToJson()` with SQL providers that don't support JSON querying**: SQLite supports `ToJson()` for storage but doesn't translate JSON path queries to SQL — queries fall back to client evaluation silently.

## References

- [Value converters — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/value-conversions)
- [JSON columns — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-7.0/whatsnew#json-columns)
- [Bulk configuration — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/bulk-configuration)
- [See: owned-entities.md](./owned-entities.md)
