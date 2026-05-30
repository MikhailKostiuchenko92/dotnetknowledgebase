# EF Core Inheritance Mapping Strategies

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `inheritance`, `TPH`, `TPT`, `TPC`, `discriminator`, `polymorphism`

## Question

> EF Core supports three inheritance mapping strategies: TPH, TPT, and TPC. What are the differences, when should you use each, and what are the performance and schema trade-offs?

## Short Answer

EF Core maps class hierarchies to SQL using three strategies. **TPH (Table Per Hierarchy)** — the default — stores all types in a single table with a discriminator column and nullable columns for derived-type properties; it's the simplest and fastest but wastes storage. **TPT (Table Per Type)** stores shared columns in the base table and type-specific columns in separate tables joined via shared PK; it normalizes storage but requires a JOIN for every query. **TPC (Table Per Concrete Type)**, added in EF Core 7, stores each concrete type in its own table with all columns duplicated; it avoids JOINs for single-type queries but makes polymorphic queries expensive. Choose TPH for most cases; consider TPC for wide hierarchies with rare polymorphic queries; avoid TPT unless you have strict normalization requirements.

## Detailed Explanation

### The Hierarchy

```csharp
public abstract class Payment
{
    public int Id { get; set; }
    public decimal Amount { get; set; }
    public DateTime PaidAt { get; set; }
}

public class CreditCardPayment : Payment
{
    public string CardLastFour { get; set; } = string.Empty;
    public string CardBrand    { get; set; } = string.Empty;
}

public class BankTransferPayment : Payment
{
    public string Iban       { get; set; } = string.Empty;
    public string BankName   { get; set; } = string.Empty;
}
```

### TPH — Table Per Hierarchy (Default)

All types stored in one table. A **discriminator column** identifies the concrete type.

```csharp
builder.UseTphMappingStrategy();  // or just omit — TPH is the default
builder.HasDiscriminator<string>("PaymentType")
       .HasValue<CreditCardPayment>("CreditCard")
       .HasValue<BankTransferPayment>("BankTransfer");
```

Generated schema:

```sql
CREATE TABLE Payments (
    Id            INT PRIMARY KEY,
    Amount        DECIMAL(18,2) NOT NULL,
    PaidAt        DATETIME2 NOT NULL,
    PaymentType   NVARCHAR(MAX) NOT NULL,   -- discriminator
    CardLastFour  NVARCHAR(MAX) NULL,        -- only for CreditCardPayment
    CardBrand     NVARCHAR(MAX) NULL,
    Iban          NVARCHAR(MAX) NULL,        -- only for BankTransferPayment
    BankName      NVARCHAR(MAX) NULL
);
```

- ✅ **No JOINs** — all data in one table.
- ✅ **Simple queries**: `SELECT * FROM Payments WHERE PaymentType = 'CreditCard'`.
- ❌ **Nullable columns** for derived-type properties — cannot enforce NOT NULL at DB level.
- ❌ **Table width grows** as hierarchy expands.

### TPT — Table Per Type

Each type gets its own table. Derived tables share the PK with the base table.

```csharp
builder.UseTptMappingStrategy();
```

Generated schema:

```sql
CREATE TABLE Payments (
    Id     INT PRIMARY KEY,
    Amount DECIMAL(18,2) NOT NULL,
    PaidAt DATETIME2 NOT NULL
);

CREATE TABLE CreditCardPayments (
    Id           INT PRIMARY KEY REFERENCES Payments(Id),
    CardLastFour NVARCHAR(MAX) NOT NULL,
    CardBrand    NVARCHAR(MAX) NOT NULL
);

CREATE TABLE BankTransferPayments (
    Id       INT PRIMARY KEY REFERENCES Payments(Id),
    Iban     NVARCHAR(MAX) NOT NULL,
    BankName NVARCHAR(MAX) NOT NULL
);
```

- ✅ **Fully normalized** — no nullable columns, columns can be `NOT NULL`.
- ✅ **Schema reflects class hierarchy**.
- ❌ **JOIN required** for every query: `SELECT * FROM Payments JOIN CreditCardPayments ON …`.
- ❌ **Polymorphic queries** (`db.Set<Payment>().ToList()`) generate complex SQL with outer joins to all derived tables — poor performance for large hierarchies.

### TPC — Table Per Concrete Type (EF Core 7+)

Each **concrete** class gets its own table with **all** columns (base + derived). No base table.

```csharp
builder.UseTpcMappingStrategy();
```

Generated schema:

```sql
CREATE TABLE CreditCardPayments (
    Id           INT PRIMARY KEY,
    Amount       DECIMAL(18,2) NOT NULL,
    PaidAt       DATETIME2 NOT NULL,
    CardLastFour NVARCHAR(MAX) NOT NULL,
    CardBrand    NVARCHAR(MAX) NOT NULL
);

CREATE TABLE BankTransferPayments (
    Id       INT PRIMARY KEY,
    Amount   DECIMAL(18,2) NOT NULL,
    PaidAt   DATETIME2 NOT NULL,
    Iban     NVARCHAR(MAX) NOT NULL,
    BankName NVARCHAR(MAX) NOT NULL
);
```

- ✅ **No JOINs** for single-type queries.
- ✅ **Columns can be `NOT NULL`**.
- ❌ **PKs cannot use IDENTITY** (different tables may generate colliding IDs). Use `HiLo` sequences or `Guid` instead.
- ❌ **Polymorphic queries** (`db.Set<Payment>()`) generate a `UNION ALL` across all tables — slow for many types.
- ❌ **Schema duplication** — base columns are repeated in every derived table.

### Comparison Table

| | TPH | TPT | TPC |
|--|-----|-----|-----|
| Tables | 1 | 1 per type | 1 per concrete type |
| NULL columns | Yes (derived) | No | No |
| Single-type query | No JOIN | 1 JOIN | No JOIN |
| Polymorphic query | No JOIN | Multiple outer JOINs | UNION ALL |
| IDENTITY PK | ✅ | ✅ | ❌ (use HiLo/Guid) |
| Default in EF Core | ✅ | — | — |
| Added in EF Core | 1.0 | 1.0 | 7.0 |

### When to Use Each

**Use TPH (default)** when:
- You have a moderate number of types (< ~5).
- Derived types have a relatively small number of extra columns.
- You frequently query the hierarchy polymorphically.

**Use TPC** when:
- Derived types have many unique columns.
- You rarely query polymorphically (usually query a specific concrete type).
- You're OK with `Guid` or HiLo for PKs.

**Use TPT** when:
- You have strict normalization requirements (DBA mandate).
- The hierarchy won't grow large.
- You can tolerate JOIN overhead on every read.

## Code Example

```csharp
// TPH configuration (the most common)
public sealed class PaymentConfiguration : IEntityTypeConfiguration<Payment>
{
    public void Configure(EntityTypeBuilder<Payment> builder)
    {
        builder.ToTable("payments");

        builder.HasDiscriminator<string>("payment_type")
               .HasValue<CreditCardPayment>("credit_card")
               .HasValue<BankTransferPayment>("bank_transfer");

        // Derived columns are nullable at DB level in TPH — document why
        builder.Property(p => p.Amount).HasPrecision(19, 4);
    }
}

// TPC configuration with HiLo to avoid PK collisions
public sealed class PaymentConfiguration : IEntityTypeConfiguration<Payment>
{
    public void Configure(EntityTypeBuilder<Payment> builder)
    {
        builder.UseTpcMappingStrategy();

        // HiLo generates unique IDs across tables without an IDENTITY column
        builder.Property(p => p.Id).UseHiLo("PaymentSequence");
    }
}

// Query: polymorphic (works for all strategies, SQL varies)
var allPayments = await db.Set<Payment>().ToListAsync(ct);

// Query: concrete type only (no join/union with TPH or TPC)
var creditCardPayments = await db.Set<CreditCardPayment>().ToListAsync(ct);

// Pattern match on materialized hierarchy
foreach (var payment in allPayments)
{
    var info = payment switch
    {
        CreditCardPayment cc => $"Card ending {cc.CardLastFour}",
        BankTransferPayment bt => $"IBAN {bt.Iban}",
        _ => "Unknown payment type"
    };
}
```

## Common Follow-up Questions

- How does EF Core handle inserting a derived type — does it insert into one table or two (for TPT)?
- Can you mix inheritance strategies within the same hierarchy (e.g., some types TPH, others TPT)?
- How does EF Core's generated SQL differ for a polymorphic `OfType<T>()` query across the three strategies?
- What are the implications of adding a new type to an existing TPH hierarchy in production?
- How do you handle the PK auto-generation problem in TPC if you must use an integer PK?

## Common Mistakes / Pitfalls

- **Using TPT for performance-critical queries**: Every `SELECT` on a derived type requires a JOIN. On large tables, this is significantly slower than TPH.
- **Forgetting HiLo/Guid with TPC**: Two `CreditCardPayments` inserted and two `BankTransferPayments` inserted will generate IDs 1, 2 in each table — conflicting PKs when queried polymorphically.
- **Discriminator values not set explicitly**: EF Core defaults to the CLR type name as the discriminator value. If you rename a class, all existing rows suddenly have an unknown discriminator — always set values explicitly.
- **Huge nullable column sprawl in TPH**: A hierarchy with 10 types × 10 unique columns each creates 100 nullable columns in one table. At this size, TPC is likely better.
- **Polymorphic queries on large TPC hierarchies**: `db.Set<Payment>()` with TPC and 20 concrete types generates a 20-table `UNION ALL`, which the query planner can't optimize well.

## References

- [Inheritance mapping — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/inheritance)
- [TPC (EF Core 7) — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-7.0/whatsnew#table-per-concrete-type-tpc-inheritance)
- [EF Core 7 What's New — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-7.0/whatsnew)
