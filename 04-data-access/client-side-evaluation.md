# Client-Side Evaluation in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `client-evaluation`, `query-translation`, `performance`, `IEnumerable`, `silent-full-scan`

## Question

> What is client-side evaluation in EF Core, when does it occur, and why is it dangerous? How do you detect it, and what are the strategies to prevent it?

## Short Answer

Client-side evaluation happens when EF Core encounters a LINQ expression it cannot translate to SQL — instead of throwing, it fetches all rows matching the server-translatable portion of the query to memory, then evaluates the untranslatable part in C#. In EF Core 3+, most untranslatable expressions throw `InvalidOperationException` rather than silently evaluating on the client. The dangerous case that remains is calling `.AsEnumerable()` or receiving `IEnumerable<T>` from a repository — everything chained after that point runs in memory regardless of how much data is loaded. Always test queries with SQL logging enabled, and prefer EF Core 3+ exceptions over silent client evaluation.

## Detailed Explanation

### History: The Silent Performance Bomb (EF Core 1 & 2)

In EF Core 1.x and 2.x, if any part of a LINQ query couldn't be translated to SQL, EF Core would silently:
1. Execute the translatable portion as SQL (potentially `SELECT * FROM Table`).
2. Pull **all matching rows** into memory.
3. Evaluate the untranslatable portion in C#.

This looked correct but could silently produce full table scans. Developers running with 100 rows in dev would discover their production query was loading 10 million rows.

### EF Core 3+: Throws by Default

EF Core 3 changed the default to throw `InvalidOperationException` when it encounters an untranslatable expression:

```
InvalidOperationException: The LINQ expression ... could not be translated.
Either rewrite the query in a form that can be translated, or switch to client
evaluation explicitly by inserting a call to 'AsEnumerable', 'AsAsyncEnumerable',
'ToList', or 'ToArray'.
```

This is a breaking change that made many EF Core 1/2 apps fail on upgrade — but it's the right default.

### When Client Evaluation Still Occurs (EF Core 3+)

**1. After `.AsEnumerable()` or `.ToList()`** — intentional but often misused:

```csharp
// ❌ Loads entire Orders table; filters in C#
var pending = db.Orders
    .AsEnumerable()
    .Where(o => MyUntranslatableMethod(o.Reference));  // ← all rows fetched
```

**2. In projections with untranslatable methods** — EF Core throws for `Where` but may still client-eval inside `Select` in some scenarios:

```csharp
// EF Core 6+ throws here too — but test it for your exact EF Core version
db.Orders.Select(o => new { o.Id, Formatted = MyFormat(o.Total) })
```

**3. `GroupBy` materializing groups** — as covered in [basic-linq-queries.md](./basic-linq-queries.md):

```csharp
// EF Core 6+ throws; earlier versions silently client-eval
db.Orders.GroupBy(o => o.Status).ToList()
```

### How to Detect Client-Side Evaluation

**1. SQL Logging:**

```csharp
// In Program.cs (dev only)
options.UseSqlServer(connString)
       .LogTo(Console.WriteLine, LogLevel.Information)
       .EnableSensitiveDataLogging();
```

If the logged SQL is `SELECT * FROM Orders` when you expected a filtered query, you're doing client eval.

**2. EF Core Query Log Category:**

```csharp
// appsettings.Development.json — log EF Core queries
{
  "Logging": {
    "LogLevel": {
      "Microsoft.EntityFrameworkCore.Query": "Warning"  // surfaces client-eval warnings
    }
  }
}
```

**3. MiniProfiler or Application Insights** — shows row counts returned vs rows expected.

### Common Untranslatable Patterns and Fixes

| ❌ Untranslatable | ✅ Fix |
|-----------------|--------|
| `o.Tags.Contains(tag)` (where `Tags` is `List<string>`) | Use a related table + `Any()` or value converter |
| `MyHelper.ComputeScore(o)` | Move logic to SQL via `EF.Functions` or a computed column |
| `Regex.IsMatch(o.Ref, pattern)` | Use `EF.Functions.Like` or store pre-processed values |
| `o.CreatedAt.ToString("yyyy-MM")` | Use `EF.Functions.DateDiffMonth` or project raw date |
| `string.Format(...)` | Compose format in memory after projection |
| `.FirstOrDefault()` inside `Select` | Use `.Select(o => o.Items.Select(...).FirstOrDefault())` — often translatable as correlated subquery |

### Legitimate Uses of Client Evaluation

After a narrow server-side query, client-side evaluation for enrichment is fine:

```csharp
// ✅ Server narrows to 20 rows; client enriches with non-translatable logic
var orders = await db.Orders
    .Where(o => o.Status == "Pending")      // SQL filter
    .Take(20)
    .Select(o => new { o.Id, o.Reference, o.Total })  // SQL projection
    .ToListAsync(ct);                        // ← materialize 20 rows

// Client-side enrichment on small result set — fine
var enriched = orders.Select(o => new OrderDto(
    o.Id, FormatReference(o.Reference), CurrencyHelper.Format(o.Total)));
```

The key: **narrow first in SQL, enrich in memory on a bounded result set**.

## Code Example

```csharp
// ❌ DANGEROUS: silent full table scan (pre-EF Core 3 behavior; throws in 3+)
var expensive = db.Orders
    .Where(o => CalcPriority(o) > 5)  // ← can't translate CalcPriority
    .ToList();

// ❌ STILL DANGEROUS in all versions: full table to memory via AsEnumerable
var also_bad = db.Orders
    .AsEnumerable()
    .Where(o => CalcPriority(o) > 5)  // runs in C# — entire table loaded
    .ToList();

// ✅ FIX OPTION 1: Add a translated pre-filter to minimize rows before client eval
var better = await db.Orders
    .Where(o => o.Status == "Pending")  // SQL filter reduces rows to manageable set
    .ToListAsync(ct)                    // materialize bounded result
    .ContinueWith(t => t.Result.Where(o => CalcPriority(o) > 5).ToList());

// ✅ FIX OPTION 2: Move the logic into the database (computed column or view)
// Add a persisted computed column or store PriorityScore as a real column
var best = await db.Orders
    .Where(o => o.Status == "Pending" && o.PriorityScore > 5)
    .ToListAsync(ct);

// ✅ FIX OPTION 3: Use EF.Functions for database-side string operations
var withEfFunctions = await db.Orders
    .Where(o => EF.Functions.Like(o.Reference, "URGENT-%"))
    .ToListAsync(ct);

// Detecting: enable logging and watch for unexpected SQL
services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(connStr)
       .LogTo(sql => Debug.WriteLine(sql), LogLevel.Information));
```

## Common Follow-up Questions

- What exactly changed between EF Core 2 and EF Core 3 regarding client evaluation — what was the breaking change?
- How do `AsEnumerable()` and `AsAsyncEnumerable()` differ in their client-evaluation behaviour for large streaming results?
- How do you safely call a custom C# function inside an EF Core projection without triggering a full table scan?
- What is a DbFunction, and how does it let you map a C# method to a SQL function?
- How can you add EF Core `DbFunction` mappings to call database scalar functions from LINQ?

## Common Mistakes / Pitfalls

- **Returning `IEnumerable<T>` from a repository method**: Any LINQ applied after crossing the `IEnumerable` boundary runs in memory. Repositories should return `Task<List<T>>` or `IQueryable<T>` (with care).
- **Upgrading from EF Core 2 to 3+ without testing queries**: Apps that relied on silent client evaluation suddenly throw `InvalidOperationException`. Treat the exception as a helpful diagnostic, not a nuisance — fix the query.
- **Assuming `Select` can call any C# method**: In EF Core 3+, untranslatable `Select` expressions may throw or may evaluate client-side depending on the exact pattern. Always verify with query logging.
- **Not checking SQL logs during development**: The only way to know if a query is doing what you think is to look at the SQL. Enable logging in `Development` and review it when writing new queries.
- **Large `AsEnumerable` for "just a few rows"**: The filter deciding which rows are "just a few" runs in SQL — but if the filter doesn't work, it loads everything. Test with realistic data volumes.

## References

- [Client vs server evaluation — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/client-eval)
- [EF Core 3.0 breaking changes — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-3.x/breaking-changes#linq-queries-are-no-longer-evaluated-on-the-client)
- [Database functions — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/database-functions)
- [See: iqueryable-vs-ienumerable.md](./iqueryable-vs-ienumerable.md)
- [See: basic-linq-queries.md](./basic-linq-queries.md)
