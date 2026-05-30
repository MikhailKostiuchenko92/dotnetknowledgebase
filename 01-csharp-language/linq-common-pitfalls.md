# LINQ Common Pitfalls

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `LINQ`, `multiple-enumeration`, `side-effects`, `captured-variables`, `deferred-execution`, `N+1`

## Question

> What are the most common pitfalls when using LINQ in C#?

Additional phrasings:
- *"What is the multiple enumeration problem and how do you detect it?"*
- *"How can a captured loop variable in a LINQ query cause unexpected results?"*

## Short Answer

The top LINQ pitfalls are: (1) **multiple enumeration** — enumerating a lazy `IEnumerable<T>` more than once re-executes the pipeline; (2) **closure capture of mutable variables** — a loop counter captured in a query is evaluated at enumeration time, not definition time; (3) **side effects in projections** — `Select`/`Where` lambdas should be pure; (4) **`Count()` on a lazy sequence** — iterates everything if there's no `ICollection<T>` shortcut; (5) **`First()` throwing on empty** — prefer `FirstOrDefault` with a null check. Understanding deferred execution is the root of most of these.

## Detailed Explanation

### Pitfall 1: Multiple Enumeration

Every time you iterate a lazy `IEnumerable<T>`, the pipeline re-runs:

```csharp
IEnumerable<Order> active = allOrders.Where(o => o.IsActive); // lazy

int count = active.Count();    // pipeline runs: iterates all orders
var list  = active.ToList();   // pipeline runs AGAIN
```

For in-memory collections this is just wasted CPU. For database-backed `IQueryable<T>`, it fires two SQL queries. For network streams or generators with side effects, it can produce wrong results.

**Fix:** materialize with `.ToList()` / `.ToArray()` before multiple passes.
**Detection:** Roslyn analyzer `CA1851` — "Possible multiple enumerations of IEnumerable."

### Pitfall 2: Captured Mutable Variables (Loop Variable Capture)

Lambdas capture a **reference** to the variable, not its value at capture time:

```csharp
var queries = new List<Func<int>>();
for (int i = 0; i < 3; i++)
    queries.Add(() => i); // captures reference to i

// By the time we call them, i == 3
foreach (var q in queries)
    Console.Write(q()); // 3 3 3 — not 0 1 2!
```

**Fix:** copy the loop variable into a local inside the loop:
```csharp
for (int i = 0; i < 3; i++)
{
    int capture = i;                 // new local per iteration
    queries.Add(() => capture);
}
// Now: 0 1 2 ✅
```

> **Note:** `foreach` loop variables in C# 5+ are scoped per iteration (the spec was fixed), so `foreach (var item in list) list2.Add(() => item)` works correctly. The problem primarily affects `for` loops and `while` loops.

### Pitfall 3: Side Effects in LINQ Lambdas

LINQ operators (`Select`, `Where`, `OrderBy`) are meant to be **pure functions** — no observable side effects. Side effects in lambdas are unpredictable because:
- Deferred queries re-run on each enumeration.
- Operators like `OrderBy` buffer all elements before yielding — running `Select` on every element before any result is returned.
- Framework code may enumerate your query internally (serialization, logging, etc.).

```csharp
var logged = items.Select(item => {
    _logger.Log(item); // ❌ side effect — runs unpredictable number of times
    return item.Transform();
});
```

**Fix:** enumerate with `foreach` explicitly when side effects are needed, or materialize first.

### Pitfall 4: `Count()` on Lazy Sequences

`Enumerable.Count()` checks if the source implements `ICollection<T>` and uses `.Count` if so. For a raw lazy pipeline, it iterates **all** elements just to count them:

```csharp
var expensive = dbContext.Orders          // IQueryable<T>
    .Where(o => o.Total > 100)
    .AsEnumerable();                      // switches to in-memory!

int count = expensive.Count();            // loads ALL matching orders, counts
bool any   = expensive.Any();             // also iterates (though stops at first)
```

**Fix:** stay on `IQueryable<T>` for counts (translated to `COUNT(*)` in SQL), or materialize once and call `.Count` on the list.

### Pitfall 5: `First()` / `Single()` Throwing on Empty

`First()` and `Single()` throw `InvalidOperationException` when the sequence is empty. In code that processes potentially empty results this causes unhandled exceptions:

```csharp
var order = orders.Where(o => o.Id == id).First(); // ❌ throws if not found
```

**Fix:** use `FirstOrDefault()` and check for `null` (or use pattern matching):

```csharp
var order = orders.FirstOrDefault(o => o.Id == id);
if (order is null) return NotFound();
```

`Single()` additionally throws if more than one match exists. Use it only when exactly one result is a business invariant — and be prepared for the exception.

### Pitfall 6: `OrderBy` inside `SelectMany` / Nested Queries

`OrderBy` applied to an inner sequence inside a `SelectMany` does not affect the final output order — the outer `SelectMany` flattens in source order, discarding inner ordering:

```csharp
var result = categories
    .SelectMany(c => c.Products.OrderBy(p => p.Name)); // inner OrderBy is useless
// The products within each category are sorted, but the outer ordering depends on categories
```

**Fix:** Apply `OrderBy` to the final result, not to inner sequences.

### Pitfall 7: `Where` Before `Select` vs After

`Where` before `Select` is (slightly) more efficient — it filters elements before projecting them, avoiding wasted projection work:

```csharp
// ✅ Filter first, then project
source.Where(x => x.IsActive).Select(x => new Dto(x))

// ❌ Project everything first, then filter on the projected type
source.Select(x => new Dto(x)).Where(dto => dto.IsActive)
```

For EF Core `IQueryable<T>`, the query translator handles order; for in-memory LINQ, filter first.

### Pitfall 8: The EF Core N+1 Problem via Lazy Navigation

```csharp
var customers = dbContext.Customers.ToList(); // 1 query: SELECT * FROM Customers

foreach (var c in customers)
    Console.WriteLine(c.Orders.Count); // N queries: SELECT * FROM Orders WHERE CustomerId = ?
```

**Fix:** use `Include` / `ThenInclude` to eager-load, or project with `Select` to fetch exactly what you need in one query.

## Code Example

```csharp
using System.Linq;

var numbers = Enumerable.Range(1, 5).Select(n => { Console.Write($"[gen{n}]"); return n; });

// === Pitfall 1: multiple enumeration ===
Console.WriteLine("Count:");
int c = numbers.Count();    // generates all 5
Console.WriteLine("\nToList:");
var list = numbers.ToList(); // generates all 5 AGAIN

// Fix: materialize once
var materialized = Enumerable.Range(1, 5)
    .Select(n => { Console.Write($"[gen{n}]"); return n; })
    .ToList(); // generates once
Console.WriteLine($"\nCount: {materialized.Count}, Sum: {materialized.Sum()}"); // uses list

// === Pitfall 2: captured variable ===
var funcs = new List<Func<int>>();
for (int i = 0; i < 3; i++)
{
    int captured = i;           // ✅ copy per iteration
    funcs.Add(() => captured);
}
Console.WriteLine(string.Join(" ", funcs.Select(f => f()))); // 0 1 2

// === Pitfall 3: side effect in projection ===
var log = new List<string>();
var safe = numbers.ToList() // materialize first
    .Select(n => { log.Add($"processed {n}"); return n * 2; }) // now single run
    .ToList();

// === Pitfall 5: FirstOrDefault vs First ===
int[] empty = [];
int result1 = empty.FirstOrDefault(-1);     // -1 (safe)
// int result2 = empty.First();             // ❌ throws InvalidOperationException

// === Pitfall 8: N+1 awareness ===
// ✅ Use projection to fetch flat data in one query
// var dtos = dbContext.Customers
//     .Select(c => new CustomerDto
//     {
//         Name = c.Name,
//         OrderCount = c.Orders.Count() // translated to subquery in SQL
//     })
//     .ToList();
```

## Common Follow-up Questions

- How does `CA1851` detect multiple enumerations at compile time?
- What is the EF Core N+1 problem, and how does `Include` solve it?
- Why did the C# specification change the scoping of `foreach` loop variables in C# 5?
- How does `Parallel.ForEach` interact with LINQ side effects?
- Is `OrderBy` stable in .NET LINQ? (Yes — it uses a stable sort.)
- What is the difference between `Where(x).Count()` and `Count(x)` overload?

## Common Mistakes / Pitfalls

- **Using `Count() > 0` instead of `Any()`.** `Any()` short-circuits at the first element; `Count() > 0` iterates everything. Always prefer `Any()` for existence checks.
- **Enumerating `IQueryable<T>` in a property getter.** If a property returns `IQueryable<T>.ToList()`, every access fires a database query. Use a method name that signals I/O (`GetOrdersAsync()`).
- **Calling `.Result` or `.GetAwaiter().GetResult()` on async LINQ projections inside a query.** This blocks threads and can deadlock in ASP.NET Classic. Use `await` properly.
- **Forgetting that `Distinct()` uses `Equals`/`GetHashCode` — not `==` operator.** For complex types without `IEquatable<T>`, pass a custom `IEqualityComparer<T>` or use `.DistinctBy(x => x.Key)` (.NET 6+).
- **Using `Select` + `Where` on `IEnumerable<T>` and assuming SQL-level optimization.** For in-memory collections, `OrderBy` allocates a sort buffer; there's no query optimizer. Profile hot paths.

## References

- [Deferred vs immediate execution — LINQ guide](https://learn.microsoft.com/dotnet/csharp/linq/get-started/introduction-to-linq-queries#deferred-execution)
- [CA1851 — Possible multiple enumerations](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1851)
- [Client evaluation warning — EF Core docs](https://learn.microsoft.com/dotnet/efcore/querying/client-eval)
- [Eager loading with Include — EF Core docs](https://learn.microsoft.com/dotnet/efcore/querying/related-data/eager)
