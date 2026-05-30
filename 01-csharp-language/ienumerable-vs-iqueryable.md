# `IEnumerable<T>` vs `IQueryable<T>`

**Category:** C# / Collections & LINQ
**Difficulty:** 🔴 Senior
**Tags:** `IEnumerable`, `IQueryable`, `LINQ`, `expression-trees`, `EF Core`, `deferred-execution`, `ORM`

## Question

> What is the difference between `IEnumerable<T>` and `IQueryable<T>` in C#? Why does it matter for Entity Framework Core?

Additional phrasings:
- *"Why does calling `.Where()` on a `DbSet<T>` produce different SQL depending on whether you use `IQueryable<T>` or `IEnumerable<T>`?"*
- *"What is an expression tree, and how does `IQueryable<T>` use it to translate LINQ to SQL?"*

## Short Answer

`IEnumerable<T>` executes query operations in-process using compiled delegates — the full data is pulled into memory first, then filtered. `IQueryable<T>` extends `IEnumerable<T>` with an `Expression` (an AST of the query) and a `Provider` that translates that expression into a native query (SQL, OData, etc.) executed on the server. With EF Core, using `IQueryable<T>` means the `WHERE`, `ORDER BY`, and `SELECT` clauses are sent to the database; accidentally switching to `IEnumerable<T>` causes client-side evaluation — loading the entire table into memory before filtering.

## Detailed Explanation

### `IEnumerable<T>`: In-Process Execution

`IEnumerable<T>` LINQ extension methods (in `System.Linq.Enumerable`) accept and return delegates (`Func<T, bool>`, etc.):

```csharp
// Enumerable.Where signature:
public static IEnumerable<TSource> Where<TSource>(
    this IEnumerable<TSource> source,
    Func<TSource, bool> predicate) // compiled delegate
```

The `Func<TSource, bool>` is a compiled IL method. To execute it, the runtime must have the data in memory to pass each element through the delegate. For database scenarios, this means: **fetch all rows from the database, then filter in C#.**

### `IQueryable<T>`: Expression-Tree-Based Execution

`IQueryable<T>` LINQ extension methods (in `System.Linq.Queryable`) accept `Expression<Func<T, bool>>` — an **expression tree** (AST), not a compiled delegate:

```csharp
// Queryable.Where signature:
public static IQueryable<TSource> Where<TSource>(
    this IQueryable<TSource> source,
    Expression<Func<TSource, bool>> predicate) // expression tree — AST
```

The expression tree is a data structure that represents the query as objects (`MethodCallExpression`, `BinaryExpression`, `MemberExpression`, etc.). The `IQueryable<T>` implementation (e.g., EF Core's `IQueryable` provider) can **inspect and translate** this tree at runtime into SQL, OData, or another query language.

### Expression Trees

An `Expression<Func<T, bool>>` is compiled by the C# compiler into a tree of objects — not IL. Consider:

```csharp
Expression<Func<Customer, bool>> expr = c => c.Age > 30 && c.City == "London";
```

The compiler generates:
```
BinaryExpression (AndAlso)
├─ BinaryExpression (GreaterThan)
│   ├─ MemberExpression (c.Age)
│   └─ ConstantExpression (30)
└─ BinaryExpression (Equal)
    ├─ MemberExpression (c.City)
    └─ ConstantExpression ("London")
```

EF Core walks this tree and produces: `WHERE Age > 30 AND City = 'London'`.

### The EF Core Trap

```csharp
// ❌ Forces client evaluation — loads ALL customers from DB, then filters in C#
IEnumerable<Customer> allCustomers = dbContext.Customers; // note: IEnumerable
var result = allCustomers.Where(c => c.Age > 30);         // Enumerable.Where — runs in C#

// ✅ Translates to SQL WHERE clause — only matching rows are fetched
IQueryable<Customer> query = dbContext.Customers;          // IQueryable
var result2 = query.Where(c => c.Age > 30);               // Queryable.Where — SQL
```

Both produce the same results but the first fetches the entire table. For a table with 10 million rows, the difference is catastrophic.

A subtle version of the same bug:

```csharp
// ❌ AsEnumerable() switches to in-memory processing — rest of the pipeline runs in C#
var result = dbContext.Customers
    .AsEnumerable()                   // switches to IEnumerable<T> here!
    .Where(c => c.Age > 30)          // C# — entire table already loaded
    .OrderBy(c => c.LastName);

// ✅ Stay in IQueryable<T> until you need to materialize
var result2 = dbContext.Customers
    .Where(c => c.Age > 30)
    .OrderBy(c => c.LastName)
    .ToList();                        // materializes once — all logic in SQL
```

### When `AsEnumerable()` Is Intentional

EF Core cannot translate every C# expression to SQL. When a LINQ operator has no SQL equivalent, use `AsEnumerable()` **deliberately** to bring data into memory and process it in C#:

```csharp
var result = dbContext.Products
    .Where(p => p.IsActive)          // SQL: WHERE IsActive = 1
    .AsEnumerable()                  // intentional: switch to C# processing
    .Where(p => MyComplexCSharpLogic(p)); // can't be translated to SQL
```

The rule: **push as much filtering/projection to the server (stay IQueryable) as possible, then switch to IEnumerable only when necessary.**

### `IQueryable<T>` Members

```csharp
public interface IQueryable<out T> : IEnumerable<T>
{
    Type ElementType { get; }
    Expression Expression { get; }   // the AST of the entire query
    IQueryProvider Provider { get; } // translates and executes the AST
}
```

The `Provider.Execute(Expression)` is called when you materialize (`.ToList()`, `.FirstOrDefault()`, `foreach`).

### Repository Pattern Consideration

A common design mistake is returning `IEnumerable<T>` from a repository method that wraps a `DbSet<T>`:

```csharp
// ❌ Forces loading everything — callers can't append SQL predicates
IEnumerable<Customer> GetAll() => _dbContext.Customers;

// ✅ Returns IQueryable — callers can add .Where/.OrderBy/.Take before materializing
IQueryable<Customer> GetAll() => _dbContext.Customers;
```

Whether to expose `IQueryable<T>` from repositories is a design debate (it leaks the data access concern). A pragmatic compromise: expose specific methods (`GetActiveCustomers(int page, int size)`) that accept filter parameters and return `IReadOnlyList<T>`.

## Code Example

```csharp
using System.Linq;
using System.Linq.Expressions;

// === Demonstrating the difference without EF Core ===

// In-memory list (IEnumerable<T>)
var numbers = Enumerable.Range(1, 1_000_000).ToList();

// IEnumerable path: all 1M numbers pass through the Where delegate
IEnumerable<int> slow = numbers.Where(n => n > 999_990);

// IQueryable with a custom provider would translate the predicate to
// a native query — but for in-memory sources, AsQueryable() is trivial:
IQueryable<int> asQ = numbers.AsQueryable().Where(n => n > 999_990);
// For List<T>, AsQueryable() still runs in-process — the difference
// only matters with a real remote provider (EF Core, LINQ to SQL, etc.)

// === Expression tree inspection ===
Expression<Func<int, bool>> expr = n => n > 999_990;
Console.WriteLine(expr);           // n => (n > 999990)
Console.WriteLine(expr.Body);      // (n > 999990)
Console.WriteLine(expr.Body.NodeType); // GreaterThan

// Compile and run as a delegate when needed
Func<int, bool> compiled = expr.Compile();
Console.WriteLine(compiled(999_991)); // true

// === EF Core pattern (illustrative — requires EF Core package) ===
// IQueryable<Customer> query = dbContext.Customers     // SELECT * FROM Customers
//     .Where(c => c.IsActive)                          // WHERE IsActive = 1
//     .Where(c => c.Region == "EU")                    // AND Region = 'EU'
//     .OrderBy(c => c.LastName)                        // ORDER BY LastName
//     .Skip(0).Take(20);                               // OFFSET 0 ROWS FETCH NEXT 20
//
// var page = await query.ToListAsync();                // executes ONE SQL query

// === AsEnumerable: deliberate switch ===
// var result = dbContext.Orders
//     .Where(o => o.Status == "Active")      // SQL filter
//     .AsEnumerable()                         // bring to C#
//     .GroupBy(o => o.CustomerRegion(/*complex C# method*/));  // C# grouping
```

## Common Follow-up Questions

- How does EF Core handle `IQueryable<T>` expressions that cannot be translated to SQL?
- What is the `IQueryProvider` interface and how would you implement a custom LINQ provider?
- How do `Select` projections on `IQueryable<T>` reduce the columns fetched from the database?
- What does `AsNoTracking()` do to a `DbSet<T>` query, and how does it relate to `IQueryable`?
- How does `IAsyncQueryProvider` extend `IQueryable<T>` for async database operations?
- What is the N+1 query problem, and how does using `IQueryable<T>` correctly help avoid it?

## Common Mistakes / Pitfalls

- **Accidentally switching to `IEnumerable<T>` mid-pipeline.** The most dangerous pattern: `foreach (var item in dbContext.SomeTable)` — this fetches all rows before the loop body filters them. Always append `.Where()` before materializing.
- **Calling `.ToList()` before filtering.** `var list = dbContext.Customers.ToList().Where(...)` — materializes everything, then filters in memory.
- **Passing a captured C# method as a LINQ predicate thinking it will be SQL.** A closure or instance method that can't be expressed as a `BinaryExpression` will cause either a runtime translation failure or silent client evaluation in older EF versions.
- **Returning `IQueryable<T>` from a method with `using var ctx = new DbContext()`.** The `DbContext` is disposed before the caller enumerates the `IQueryable<T>`, causing an `ObjectDisposedException`. Materialize inside the `using` scope or manage context lifetime carefully.
- **Using `IQueryable<T>` with in-memory collections and expecting SQL semantics.** `List<T>.AsQueryable()` wraps a thin shim that still runs in-process; it does not execute SQL. The `IQueryable<T>` benefits only apply when backed by a real query provider.

## References

- [IQueryable<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.iqueryable-1)
- [IEnumerable<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerable-1)
- [Expression Trees — C# programming guide](https://learn.microsoft.com/dotnet/csharp/advanced-topics/expression-trees/)
- [Client vs Server Evaluation — EF Core documentation](https://learn.microsoft.com/dotnet/efcore/querying/client-eval)
- [How LINQ queries work — C# guide](https://learn.microsoft.com/dotnet/csharp/linq/get-started/introduction-to-linq-queries)
