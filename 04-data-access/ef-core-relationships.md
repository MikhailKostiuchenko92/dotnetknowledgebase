# EF Core Relationships

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `relationships`, `foreign-key`, `navigation-properties`, `cascade-delete`, `many-to-many`

## Question

> How do you configure one-to-many, one-to-one, and many-to-many relationships in EF Core? What are navigation properties, and how do you control cascade delete behaviour?

## Short Answer

EF Core relationships are configured through navigation properties and Fluent API calls (`HasOne`, `HasMany`, `WithOne`, `WithMany`). One-to-many is the most common: the dependent entity holds a foreign key and a reference navigation; the principal entity has a collection navigation. Many-to-many in EF Core 5+ can be implicit (no join entity class needed) or explicit (you define the join entity for extra payload). Cascade delete defaults to `Cascade` when the FK is required and `ClientSetNull` when optional; you almost always want to configure this explicitly to avoid accidental data loss.

## Detailed Explanation

### One-to-Many

The most common relationship: one `Customer` has many `Orders`.

```csharp
public class Customer
{
    public int Id { get; set; }
    public ICollection<Order> Orders { get; set; } = [];  // collection navigation
}

public class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }       // FK (required)
    public Customer Customer { get; set; } = null!;  // reference navigation
}
```

EF Core discovers this by convention (FK name matches navigation + "Id"). To configure explicitly:

```csharp
builder.HasMany(c => c.Orders)
       .WithOne(o => o.Customer)
       .HasForeignKey(o => o.CustomerId)
       .OnDelete(DeleteBehavior.Restrict);
```

### One-to-One

Each entity has at most one related entity — e.g., `Order` and `OrderShippingAddress`.

```csharp
builder.HasOne(o => o.ShippingAddress)
       .WithOne(a => a.Order)
       .HasForeignKey<OrderShippingAddress>(a => a.OrderId);
```

> **Convention note:** In one-to-one, EF Core cannot always determine which entity holds the FK. Always call `HasForeignKey<TDependent>()` explicitly.

### Many-to-Many

**Implicit (EF Core 5+)** — EF Core creates a hidden join table automatically:

```csharp
public class Product
{
    public int Id { get; set; }
    public ICollection<Tag> Tags { get; set; } = [];
}

public class Tag
{
    public int Id { get; set; }
    public ICollection<Product> Products { get; set; } = [];
}
// EF Core generates "ProductTag" join table automatically
```

**Explicit (join entity with payload)** — required when the join table has extra columns:

```csharp
public class Order
{
    public ICollection<OrderProduct> OrderProducts { get; set; } = [];
}

public class OrderProduct   // join entity with payload
{
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; }    // extra column
    public decimal UnitPrice { get; set; }

    public Order Order { get; set; } = null!;
    public Product Product { get; set; } = null!;
}

// Configuration:
builder.HasKey(op => new { op.OrderId, op.ProductId });  // composite PK
builder.HasOne(op => op.Order).WithMany(o => o.OrderProducts).HasForeignKey(op => op.OrderId);
builder.HasOne(op => op.Product).WithMany().HasForeignKey(op => op.ProductId);
```

### Cascade Delete Behaviours

| `DeleteBehavior` | FK required? | On principal delete | When to use |
|-----------------|--------------|---------------------|-------------|
| `Cascade` | Required | Delete dependent rows | Parent owns children (e.g., Order → OrderLines) |
| `Restrict` | Either | Throw exception | Prevent accidental deletes (e.g., Customer with orders) |
| `SetNull` | Optional | Set FK to NULL | Soft ownership (optional relationship) |
| `ClientSetNull` | Optional | Set FK to NULL in memory, no DB constraint | Default for optional; only works for tracked entities |
| `NoAction` | Either | DB decides (no ON DELETE rule added) | Fine-grained DB control |

> **Warning:** `Cascade` on an **optional** relationship is unusual — it means "delete the dependent even when it might have its own lifetime." Be explicit and deliberate when choosing `Cascade`.

### Required vs Optional Relationships

A relationship is **required** when the FK property is non-nullable (`int CustomerId`). It is **optional** when the FK is nullable (`int? CustomerId`).

```csharp
// Required: Order must have a Customer
public int CustomerId { get; set; }

// Optional: Order may or may not have a Discount
public int? DiscountId { get; set; }
```

EF Core defaults: required FK → `Cascade` delete; optional FK → `ClientSetNull`.

## Code Example

```csharp
// Domain entities
public class Blog
{
    public int Id { get; set; }
    public string Url { get; set; } = string.Empty;
    public ICollection<Post> Posts { get; set; } = [];
}

public class Post
{
    public int Id { get; set; }
    public int BlogId { get; set; }      // required FK → Cascade by default
    public Blog Blog { get; set; } = null!;
    public ICollection<Tag> Tags { get; set; } = [];  // many-to-many
}

public class Tag
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public ICollection<Post> Posts { get; set; } = [];
}

// Configuration
public sealed class BlogConfiguration : IEntityTypeConfiguration<Blog>
{
    public void Configure(EntityTypeBuilder<Blog> builder)
    {
        builder.HasMany(b => b.Posts)
               .WithOne(p => p.Blog)
               .HasForeignKey(p => p.BlogId)
               .OnDelete(DeleteBehavior.Cascade);  // explicit: deleting blog deletes posts
    }
}

public sealed class PostConfiguration : IEntityTypeConfiguration<Post>
{
    public void Configure(EntityTypeBuilder<Post> builder)
    {
        // Many-to-many with implicit join table (EF Core 5+)
        builder.HasMany(p => p.Tags)
               .WithMany(t => t.Posts)
               .UsingEntity(j => j.ToTable("PostTags")); // name the join table
    }
}
```

## Common Follow-up Questions

- What is the difference between `ClientSetNull` and `SetNull`, and when does `ClientSetNull` silently break?
- How do you configure a self-referential relationship (e.g., an `Employee` with a `ManagerId` pointing to another `Employee`)?
- How do you load related entities — what is the difference between `Include`, lazy loading proxies, and `Entry().Reference().Load()`?
- If you delete a principal entity without including its dependents, what happens with `ClientSetNull` vs `Cascade`?
- How does EF Core handle many-to-many with the implicit join table if you later need to add a column to that table?

## Common Mistakes / Pitfalls

- **Forgetting `HasForeignKey` in one-to-one**: EF Core can't infer which entity holds the FK; it will guess and often get it wrong, causing "multiple cascade paths" SQL Server errors.
- **Unintentional `Cascade` deletes**: Relying on the default cascade behaviour without understanding it. Always set `OnDelete` explicitly in configuration.
- **Loading the whole collection to add one item**: `order.Items.Add(item)` on a lazy-loaded nav property triggers loading all items first. Use `db.Entry(order).Collection(o => o.Items).IsLoaded` or just `db.Add(item)` directly.
- **Circular cascade paths (SQL Server)**: Multiple cascade paths to the same table cause SQL Server to reject the migration. Fix by setting one of the FKs to `DeleteBehavior.Restrict` or `NoAction`.
- **Using `List<T>` instead of `ICollection<T>`**: EF Core lazy loading proxies require virtual navigation properties and cannot override `List<T>`. Use `ICollection<T>` or `IEnumerable<T>` and initialise with `= []`.

## References

- [Relationships — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/relationships)
- [Cascade delete — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/cascade-delete)
- [Many-to-many relationships — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/relationships/many-to-many)
- [See: eager-vs-lazy-vs-explicit-loading.md](./eager-vs-lazy-vs-explicit-loading.md)
