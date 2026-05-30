# Dapper Type Handlers

**Category:** Data Access / Dapper
**Difficulty:** 🟡 Middle
**Tags:** `dapper`, `TypeHandler`, `SqlMapper`, `JSON`, `Guid`, `custom-mapping`, `value-objects`

## Question

> What is a Dapper `TypeHandler<T>`, when do you need one, and how do you implement custom type mapping — for example, mapping a JSON column to a C# object, or a `BINARY(16)` column to a `Guid`?

## Short Answer

A Dapper `TypeHandler<T>` is a custom converter that bridges between a .NET type and a database representation. You implement `SqlMapper.TypeHandler<T>` by overriding `SetValue` (writing to a `DbParameter`) and `Parse` (reading from a raw database value). Register it once at startup with `SqlMapper.AddTypeHandler(new MyHandler())`. You need type handlers when Dapper's default name-matching can't map the column — JSON columns stored as `NVARCHAR`, `BINARY(16)` GUIDs, custom value objects, strongly-typed IDs, or enums stored as strings.

## Detailed Explanation

### When Default Mapping Fails

Dapper maps column values to properties using `DbDataReader.GetValue()` + implicit conversion. This works for primitives (int, string, DateTime) but fails for:

- A `NVARCHAR(MAX)` column containing JSON that you want as `Address { Street, City }`.
- A `BINARY(16)` column you want as `Guid` (some DBs store Guids as binary for performance).
- A `VARCHAR(50)` column you want as a strongly-typed ID (`OrderId`, `CustomerId`).
- An `INT` column you want as a domain enum.

### Implementing a TypeHandler

```csharp
// Example: JSON column → Address object
public class Address
{
    public string Street { get; set; } = "";
    public string City { get; set; } = "";
    public string PostalCode { get; set; } = "";
}

public sealed class JsonTypeHandler<T> : SqlMapper.TypeHandler<T>
{
    public override void SetValue(IDbDataParameter parameter, T? value)
    {
        parameter.Value = value is null
            ? DBNull.Value
            : JsonSerializer.Serialize(value);

        parameter.DbType = DbType.String;  // maps to NVARCHAR/TEXT in SQL
    }

    public override T? Parse(object value)
    {
        if (value is DBNull or null) return default;
        return JsonSerializer.Deserialize<T>(value.ToString()!);
    }
}
```

### Registration

```csharp
// Register at application startup — once, globally
SqlMapper.AddTypeHandler(new JsonTypeHandler<Address>());
SqlMapper.AddTypeHandler(new JsonTypeHandler<OrderMetadata>());

// Generic registration helper
static void RegisterJsonHandler<T>() =>
    SqlMapper.AddTypeHandler(new JsonTypeHandler<T>());
```

After registration, any query that returns a column mapped to `Address` will use `JsonTypeHandler<Address>`:

```csharp
var customer = await conn.QuerySingleAsync<Customer>(
    "SELECT Id, Name, AddressJson AS Address FROM Customers WHERE Id = @Id",
    new { Id = id });
// customer.Address is deserialized from the JSON string automatically
```

### Guid as BINARY(16) — SQL Server-Specific

Some schemas store GUIDs as `BINARY(16)` for clustering performance. Dapper's default Guid mapping doesn't handle binary:

```csharp
public sealed class GuidAsBinaryHandler : SqlMapper.TypeHandler<Guid>
{
    public override void SetValue(IDbDataParameter parameter, Guid value)
    {
        parameter.Value = value.ToByteArray();
        parameter.DbType = DbType.Binary;
        parameter.Size = 16;
    }

    public override Guid Parse(object value)
        => value is byte[] bytes ? new Guid(bytes) : Guid.Empty;
}

SqlMapper.AddTypeHandler(new GuidAsBinaryHandler());
```

### Strongly-Typed IDs

```csharp
// Value object wrapping an int
public readonly record struct OrderId(int Value);

public sealed class OrderIdHandler : SqlMapper.TypeHandler<OrderId>
{
    public override void SetValue(IDbDataParameter p, OrderId value)
    {
        p.Value = value.Value;
        p.DbType = DbType.Int32;
    }

    public override OrderId Parse(object value)
        => new OrderId(Convert.ToInt32(value));
}

SqlMapper.AddTypeHandler(new OrderIdHandler());

// Now works transparently
var order = await conn.QuerySingleOrDefaultAsync<Order>(
    "SELECT Id, Reference FROM Orders WHERE Id = @Id",
    new { Id = new OrderId(42) });
```

### Enum as String

```csharp
public enum OrderStatus { Pending, Processing, Shipped, Cancelled }

public sealed class EnumStringHandler<T> : SqlMapper.TypeHandler<T> where T : struct, Enum
{
    public override void SetValue(IDbDataParameter p, T value)
    {
        p.Value = value.ToString();
        p.DbType = DbType.String;
    }

    public override T Parse(object value)
        => Enum.Parse<T>(value.ToString()!, ignoreCase: true);
}

SqlMapper.AddTypeHandler(new EnumStringHandler<OrderStatus>());
```

## Code Example

```csharp
// Complete setup in Program.cs
// Register all custom type handlers at startup
static void RegisterDapperTypeHandlers()
{
    SqlMapper.AddTypeHandler(new JsonTypeHandler<Address>());
    SqlMapper.AddTypeHandler(new JsonTypeHandler<OrderMetadata>());
    SqlMapper.AddTypeHandler(new EnumStringHandler<OrderStatus>());
    SqlMapper.AddTypeHandler(new EnumStringHandler<PaymentMethod>());
    // Remove Dapper's built-in Guid handler and add binary one if needed:
    // SqlMapper.RemoveTypeMap(typeof(Guid));
    // SqlMapper.AddTypeHandler(new GuidAsBinaryHandler());
}

// Entity using custom-mapped types
public class Order
{
    public int Id { get; set; }
    public string Reference { get; set; } = "";
    public Address ShippingAddress { get; set; } = new();  // ← JSON column
    public OrderStatus Status { get; set; }                // ← VARCHAR column
    public OrderMetadata Metadata { get; set; } = new();   // ← JSON column
}

// Query — type handlers fire transparently
var order = await conn.QuerySingleOrDefaultAsync<Order>(
    "SELECT Id, Reference, ShippingAddress, Status, Metadata FROM Orders WHERE Id = @Id",
    new { Id = id });
```

## Common Follow-up Questions

- How does Dapper's `TypeHandler` interact with `DynamicParameters` — does it apply automatically?
- Can you register a type handler for `IEnumerable<T>` — how does Dapper handle collection columns?
- What is the difference between `SqlMapper.AddTypeHandler` and `SqlMapper.SetTypeMap`?
- How do you remove a built-in Dapper type mapping (e.g., to override Guid handling)?
- Can type handlers be registered per-connection or per-query, or only globally?

## Common Mistakes / Pitfalls

- **Forgetting to register the handler before the first query**: Dapper caches type maps on first use. If you register a handler after the first query, cached maps may not include it. Always register at startup.
- **Returning `null` from `Parse` without handling `DBNull`**: `value` passed to `Parse` can be `DBNull.Value` (a singleton, not `null`). Check `if (value is DBNull or null)` before converting.
- **Not setting `DbType` in `SetValue`**: Without explicitly setting `DbType`, ADO.NET infers it from the C# type of `parameter.Value`. For byte arrays, this defaults to `DbType.Object` on some providers — always set `DbType.Binary` explicitly.
- **Using `value.ToString()` on non-string types**: For numeric types stored in the reader, `value` is a boxed `int`/`long`. Calling `JsonSerializer.Deserialize<T>(value.ToString())` fails if the column is actually JSON stored in NVARCHAR — verify the actual column type.
- **Global state causing issues in tests**: `SqlMapper.AddTypeHandler` modifies a static global. Tests that run in parallel may observe handlers registered by other tests. Register all handlers in test setup and consider isolation.

## References

- [TypeHandler — Dapper GitHub](https://github.com/DapperLib/Dapper#type-handlers)
- [Dapper custom type handling — Andrew Lock blog](https://andrewlock.net/using-strongly-typed-entity-ids-to-avoid-primitive-obsession-part-3/) (verify URL)
- [See: dapper-overview.md](./dapper-overview.md)
- [See: value-converters.md](../04-data-access/value-converters.md)
