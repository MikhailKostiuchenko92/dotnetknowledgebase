# EF Core Conventions

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `conventions`, `primary-key`, `foreign-key`, `data-type-mapping`

## Question

> How does EF Core discover the schema automatically using conventions? What rules does it follow for primary keys, foreign keys, and column data types — and what happens when conventions don't match your model?

## Short Answer

EF Core uses a set of built-in conventions to infer the database schema from your entity classes without any explicit configuration. It looks for a property named `Id` or `<TypeName>Id` and maps it as the primary key; it detects foreign keys from navigation properties and names them `<NavigationProperty>Id`; and it maps .NET types to provider-specific SQL types (e.g., `string` → `nvarchar(max)`, `int` → `int`). When conventions don't fit — unusual naming, value objects, precision requirements — you override them with data annotations or the Fluent API.

## Detailed Explanation

### Primary Key Convention

EF Core recognizes a property as the primary key if its name is:

- `Id` (case-insensitive), or
- `<EntityTypeName>Id` (e.g., `OrderId` on class `Order`)

```csharp
public class Order
{
    public int Id { get; set; }          // ✅ detected as PK by convention
}

public class Customer
{
    public Guid CustomerId { get; set; } // ✅ also detected as PK by convention
}

public class Invoice
{
    public int Number { get; set; }      // ❌ not detected — needs [Key] or Fluent API
}
```

If no convention match is found, EF Core throws at model build time: `The entity type 'Invoice' requires a primary key to be defined`.

Key types supported by convention: `int`, `long`, `Guid`, `string`. EF Core auto-generates values for `int`/`long` (IDENTITY) and `Guid` (via `Guid.NewGuid()` before INSERT by default; in .NET 8+ you can use `newsequentialid()` via `UseSequentialGuids()`).

### Foreign Key Convention

EF Core infers a foreign key when it finds a navigation property plus a matching scalar property:

```csharp
public class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }   // FK — matches navigation property name + "Id"
    public Customer Customer { get; set; } = null!;  // navigation property
}
```

Convention rules (in priority order):
1. `<NavigationPropertyName>Id` (e.g., `CustomerId`)
2. `<PrincipalEntityTypeName>Id` (e.g., `CustomerId` on any entity)
3. Shadow property `<NavigationPropertyName>Id` created automatically if no scalar found

### Column Type Mapping

| .NET Type | SQL Server | PostgreSQL |
|-----------|------------|------------|
| `string` | `nvarchar(max)` | `text` |
| `int` | `int` | `integer` |
| `long` | `bigint` | `bigint` |
| `bool` | `bit` | `boolean` |
| `DateTime` | `datetime2(7)` | `timestamp with time zone` |
| `decimal` | `decimal(18,2)` | `numeric` |
| `Guid` | `uniqueidentifier` | `uuid` |
| `byte[]` | `varbinary(max)` | `bytea` |

> **Warning:** `decimal` defaults to `decimal(18,2)` on SQL Server. For financial amounts, configure precision explicitly: `.HasPrecision(19, 4)` or `[Precision(19, 4)]`.

### Index Convention

EF Core automatically creates:
- A **unique index** on the PK column.
- A **non-unique index** on every FK column (introduced in EF Core 7 — helps JOIN performance).

It does **not** automatically create indexes on other columns; those require explicit configuration.

### Nullability Convention (.NET 6+)

When nullable reference types (NRTs) are enabled (the default in .NET 6+ projects), EF Core maps:
- `string name` → `NOT NULL`
- `string? name` → `NULL`

This dramatically reduces the need for `[Required]` attributes on string properties.

### When to Override Conventions

| Situation | Solution |
|-----------|----------|
| Unusual PK name | `[Key]` annotation or `.HasKey()` |
| Max length on string | `[MaxLength(100)]` or `.HasMaxLength(100)` |
| Specific decimal precision | `[Precision(19,4)]` or `.HasPrecision(19,4)` |
| Table/column name differs | `[Table("tbl_orders")]` / `[Column("cust_id")]` or Fluent API |
| Composite PK | `.HasKey(e => new { e.OrderId, e.LineNumber })` (no annotation equiv.) |

## Code Example

```csharp
// All conventions in action — no explicit config needed
public class Order
{
    public int Id { get; set; }           // PK by convention (int → IDENTITY)
    public int CustomerId { get; set; }   // FK by convention
    public Customer Customer { get; set; } = null!;
    public string Reference { get; set; } = string.Empty; // NOT NULL (NRT enabled)
    public string? Notes { get; set; }    // NULL (NRT enabled)
    public decimal Total { get; set; }    // decimal(18,2) by convention — often wrong for money!
    public DateTime CreatedAt { get; set; }
}

// ❌ Problem: decimal(18,2) may lose precision for financial data
// ✅ Fix with data annotation:
public class OrderFixed
{
    public int Id { get; set; }
    [Precision(19, 4)]                   // override default decimal mapping
    public decimal Total { get; set; }
}

// ✅ Fix with Fluent API (in IEntityTypeConfiguration<Order>):
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.Property(o => o.Total).HasPrecision(19, 4);
        builder.Property(o => o.Reference).HasMaxLength(50);
    }
}
```

## Common Follow-up Questions

- How do you change EF Core's naming convention to use snake_case for all columns (e.g., for PostgreSQL)?
- What is a shadow property and when does EF Core create one automatically?
- How does EF Core handle composite primary keys — can you use a convention, or must you use the Fluent API?
- How do nullable reference types affect EF Core column nullability inference?
- What is the difference between `[Required]` and not-null reference types in EF Core 6+?

## Common Mistakes / Pitfalls

- **Decimal precision**: Relying on the `decimal(18,2)` default for financial values — always configure precision explicitly.
- **Missing `[Key]` on non-standard PK names**: If your PK is `OrderNumber`, EF Core won't find it by convention and will throw at startup.
- **String `NOT NULL` without NRTs**: In projects with NRTs disabled, all strings are nullable by convention unless decorated with `[Required]`. Enable NRTs globally (the .NET 6+ default) to match conventions to C# intent.
- **Index on FK assumption**: Prior to EF Core 7, FK indexes were not created by convention. Running on an older project may have missing FK indexes causing slow JOINs.
- **`DateTime` vs `DateTimeOffset`**: `DateTime` maps to `datetime2` in SQL Server, which has no timezone info. Use `DateTimeOffset` for UTC-aware timestamps stored with offset.

## References

- [Conventions in EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/conventions)
- [Keys — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/keys)
- [Relationships — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/relationships)
- [Nullable reference types — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/miscellaneous/nullable-reference-types)
