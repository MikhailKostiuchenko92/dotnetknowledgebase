# `Select` vs `SelectMany`

**Category:** C# / Collections & LINQ
**Difficulty:** 🟢 Junior
**Tags:** `LINQ`, `Select`, `SelectMany`, `projection`, `flattening`, `nested-collections`

## Question

> What is the difference between `Select` and `SelectMany` in LINQ?

Additional phrasings:
- *"When would you use `SelectMany` instead of nested `Select` calls?"*
- *"What is `SelectMany` equivalent to in query syntax?"*

## Short Answer

`Select` applies a transformation to each element and returns one output per input — a one-to-one mapping. `SelectMany` applies a transformation that returns a **sequence** per input element and then **flattens** all those sequences into a single output sequence — a one-to-many mapping. Use `SelectMany` whenever you need to "unpack" a nested collection: a list of orders each having multiple items, a list of directories each containing multiple files, etc.

## Detailed Explanation

### `Select` — One-to-One Projection

`Select(source, selector)` maps each element to exactly one result:

```
Input:  [A, B, C]
Select: x => x.Value
Output: [A.Value, B.Value, C.Value]
```

The output sequence has the **same number of elements** as the input.

### `SelectMany` — One-to-Many Flatten

`SelectMany(source, collectionSelector)` maps each element to a **sequence**, then concatenates all those sequences:

```
Input:  [Order1 {Items=[I1,I2]}, Order2 {Items=[I3]}]
SelectMany: o => o.Items
Output: [I1, I2, I3]   — one flat sequence
```

Without `SelectMany`, a nested `Select` returns `IEnumerable<IEnumerable<T>>` — a sequence of sequences. `SelectMany` collapses that into `IEnumerable<T>`.

### The Two `SelectMany` Overloads

**Overload 1: projection only**
```csharp
SelectMany<TSource, TResult>(
    IEnumerable<TSource> source,
    Func<TSource, IEnumerable<TResult>> collectionSelector)
```
Returns the flattened inner elements.

**Overload 2: projection + result selector**
```csharp
SelectMany<TSource, TCollection, TResult>(
    IEnumerable<TSource> source,
    Func<TSource, IEnumerable<TCollection>> collectionSelector,
    Func<TSource, TCollection, TResult> resultSelector)
```
Returns a projected result combining the outer element and each inner element — used to preserve context (e.g., keep the parent order alongside each item).

### Query Syntax Equivalent

Multiple `from` clauses in query syntax compile to `SelectMany`:

```csharp
// Query syntax
var result = from order in orders
             from item in order.Items
             select new { order.Id, item.Name };

// Equivalent method syntax
var result = orders.SelectMany(
    order => order.Items,
    (order, item) => new { order.Id, item.Name });
```

### Common Use Cases

| Scenario | How `SelectMany` helps |
|---|---|
| Order → line items | `orders.SelectMany(o => o.Items)` |
| Blog posts → tags | `posts.SelectMany(p => p.Tags).Distinct()` |
| Directories → files | `dirs.SelectMany(d => d.GetFiles())` |
| String → chars | `words.SelectMany(w => w)` (string is `IEnumerable<char>`) |
| Optional value (like `flatMap`) | `items.SelectMany(i => i.OptionalValue.HasValue ? [i.OptionalValue.Value] : [])` |

### `SelectMany` as `flatMap`

`SelectMany` is .NET's equivalent of `flatMap` in functional languages — it corresponds to the monadic bind operation on sequences. If you've used Haskell's `>>=`, Scala's `flatMap`, or JavaScript's `Array.flatMap`, `SelectMany` is the same concept.

## Code Example

```csharp
using System.Linq;

// === Select: one result per input ===
var names = new[] { "alice", "bob", "charlie" };
var upper = names.Select(n => n.ToUpper());
// ["ALICE", "BOB", "CHARLIE"] — same count as input

// Nested Select WITHOUT SelectMany → sequence of sequences
var chars_nested = names.Select(n => n.ToCharArray());
// [['a','l','i','c','e'], ['b','o','b'], ['c','h','a','r','l','i','e']]
Console.WriteLine(chars_nested.GetType().Name); // WhereSelectArrayIterator → IEnumerable<char[]>

// === SelectMany: flatten the nested sequences ===
var chars_flat = names.SelectMany(n => n.ToCharArray());
// ['a','l','i','c','e','b','o','b','c','h','a','r','l','i','e'] — all chars flat
Console.WriteLine(string.Join("", chars_flat)); // alicebobcharlie

// === Practical: orders with line items ===
var orders = new[]
{
    new { Id = 1, Items = new[] { "apple", "banana" } },
    new { Id = 2, Items = new[] { "cherry" } },
    new { Id = 3, Items = new[] { "date", "elderberry", "fig" } },
};

// All items across all orders (flat list)
var allItems = orders.SelectMany(o => o.Items);
Console.WriteLine(string.Join(", ", allItems));
// apple, banana, cherry, date, elderberry, fig

// Preserve parent context using result selector overload
var itemsWithOrderId = orders.SelectMany(
    o => o.Items,
    (o, item) => new { o.Id, Item = item });

foreach (var x in itemsWithOrderId)
    Console.WriteLine($"Order {x.Id}: {x.Item}");
// Order 1: apple
// Order 1: banana
// Order 2: cherry
// ...

// === Query syntax equivalent ===
var itemsQuery = from o in orders
                 from item in o.Items
                 select new { o.Id, Item = item };

// === Distinct tags across posts ===
var posts = new[]
{
    new { Title = "A", Tags = new[] { "csharp", "dotnet" } },
    new { Title = "B", Tags = new[] { "dotnet", "async" } },
};
var allTags = posts.SelectMany(p => p.Tags).Distinct();
Console.WriteLine(string.Join(", ", allTags)); // csharp, dotnet, async

// === String as IEnumerable<char> ===
var words = new[] { "Hello", "World" };
var letters = words.SelectMany(w => w);         // flattens strings to chars
Console.WriteLine(string.Join("", letters));    // HelloWorld
```

## Common Follow-up Questions

- How does `SelectMany` differ from `Flatten` in other languages?
- Can `SelectMany` be used with `IQueryable<T>` and EF Core to generate a JOIN query?
- What is the result of `SelectMany` on an empty outer collection?
- How does `SelectMany` with the result selector overload differ from `Join`?
- Is `SelectMany` lazy (deferred execution) like `Select`?

## Common Mistakes / Pitfalls

- **Using `Select` when you need `SelectMany` and getting `IEnumerable<IEnumerable<T>>`.** The type gives it away — if your `Select` produces a nested collection type, you almost certainly need `SelectMany`.
- **Forgetting that `SelectMany` preserves source order.** The output elements come in source order (outer collection first, then inner items left-to-right per outer element). This is not a random merge.
- **Not using the result-selector overload when you need the parent.** A common pattern: `orders.SelectMany(o => o.Items)` loses the order reference. Use `orders.SelectMany(o => o.Items, (o, i) => new { o.Id, Item = i })` to keep it.
- **Using `SelectMany` on strings expecting word-level flattening.** `words.SelectMany(w => w)` flattens to individual `char` values, not words. Use `.SelectMany(w => w.Split(' '))` for word-level splitting.
- **Calling `.SelectMany(x => x)` instead of `.SelectMany(x => x, ...)` and losing context.** Both are valid but serve different purposes; make sure the overload you choose produces the data shape you need.

## References

- [Enumerable.SelectMany — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable.selectmany)
- [Enumerable.Select — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable.select)
- [Projection operations in LINQ — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/linq/standard-query-operators/projection-operations)
