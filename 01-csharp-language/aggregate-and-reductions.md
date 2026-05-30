# `Aggregate` and Reduction Operations

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `LINQ`, `Aggregate`, `Sum`, `Min`, `Max`, `Average`, `Reduce`, `accumulator`

## Question

> How does `Aggregate` work in LINQ, and how does it relate to `Sum`, `Min`, `Max`, and `Average`?

Additional phrasings:
- *"What is the accumulator pattern and how does `Aggregate` implement it?"*
- *"When would you use `Aggregate` instead of a `foreach` loop?"*

## Short Answer

`Aggregate` is the general-purpose fold/reduce operation: it applies a function repeatedly to an accumulator and each element, building up a single result. `Sum`, `Min`, `Max`, `Average`, and `Count` are all specialised reductions that `Aggregate` can express — but the dedicated methods are faster (optimized implementations, SIMD in some cases) and more readable. Use `Aggregate` when no built-in reduction fits, such as building a string, computing a running product, or folding a complex data structure.

## Detailed Explanation

### The Accumulator Pattern

A reduction takes a sequence and collapses it to a single value by applying a binary operation repeatedly:

```
sequence: [a, b, c, d]
seed: s
step 1: acc = f(s, a)
step 2: acc = f(acc, b)
step 3: acc = f(acc, c)
step 4: acc = f(acc, d)
result: acc
```

### `Aggregate` Overloads

**Overload 1: No seed — uses first element as starting accumulator**
```csharp
TSource Aggregate<TSource>(
    IEnumerable<TSource> source,
    Func<TSource, TSource, TSource> func)
```
Throws `InvalidOperationException` on empty sequences (no first element to start with).

**Overload 2: With seed**
```csharp
TAccumulate Aggregate<TSource, TAccumulate>(
    IEnumerable<TSource> source,
    TAccumulate seed,
    Func<TAccumulate, TSource, TAccumulate> func)
```
The accumulator can be a different type than the source elements. Safe on empty sequences (returns the seed).

**Overload 3: With seed + result selector**
```csharp
TResult Aggregate<TSource, TAccumulate, TResult>(
    IEnumerable<TSource> source,
    TAccumulate seed,
    Func<TAccumulate, TSource, TAccumulate> func,
    Func<TAccumulate, TResult> resultSelector)
```
Applies a final transformation to the accumulated value before returning.

### Built-in Reductions vs `Aggregate`

| Built-in | `Aggregate` equivalent | Notes |
|---|---|---|
| `Sum()` | `Aggregate(0, (acc, x) => acc + x)` | Dedicated impl is faster |
| `Min()` | `Aggregate((a, b) => a < b ? a : b)` | Uses `IComparable<T>` |
| `Max()` | `Aggregate((a, b) => a > b ? a : b)` | Uses `IComparable<T>` |
| `Count()` | `Aggregate(0, (acc, _) => acc + 1)` | Checks `ICollection<T>.Count` first |
| `Average()` | Not directly — needs sum + count | More complex accumulator |

The built-in methods should always be preferred over `Aggregate` equivalents for simple reductions because:
- They have dedicated, optimized implementations.
- Some use vectorized (SIMD) arithmetic in .NET 8+.
- They are semantically clear.

### When `Aggregate` Is the Right Tool

1. **No built-in reduction exists** for the operation.
2. **The accumulator type differs** from the element type.
3. **Complex folding** over a data structure.

Examples:
- Concatenating strings with a separator (though `string.Join` is better).
- Computing a running product.
- Folding a list of functions into a composed function.
- Building a `HashSet<T>` while accumulating elements.

### `Aggregate` vs `foreach`

`Aggregate` is functionally equivalent to a `foreach` with an accumulator variable. The choice is stylistic:
- `Aggregate` is a one-liner, works in LINQ pipelines, and is expression-bodied.
- `foreach` is more readable for complex multi-step logic inside the loop.
- They produce identical IL; neither is faster than the other for equivalent logic.

### .NET 6+ Additions: `MinBy`, `MaxBy`, `DistinctBy`, `Chunk`

.NET 6 added operators that reduce common `Aggregate` patterns:

```csharp
// Old: need Aggregate or OrderBy().First()
var cheapest = products.Aggregate((min, p) => p.Price < min.Price ? p : min);

// .NET 6+: clear intent, optimized
var cheapest = products.MinBy(p => p.Price);
```

## Code Example

```csharp
using System.Linq;

int[] nums = [1, 2, 3, 4, 5];

// === Built-in reductions — prefer these ===
Console.WriteLine(nums.Sum());      // 15
Console.WriteLine(nums.Min());      // 1
Console.WriteLine(nums.Max());      // 5
Console.WriteLine(nums.Average());  // 3.0
Console.WriteLine(nums.Count());    // 5

// === Aggregate: general fold ===

// Overload 1: no seed — first element is starting accumulator
int product = nums.Aggregate((acc, x) => acc * x);
Console.WriteLine(product); // 120  (1*2*3*4*5)

// Overload 2: with seed (different accumulator type)
string sentence = nums.Aggregate(
    seed: "Numbers: ",
    func: (acc, x) => acc + x + " ");
Console.WriteLine(sentence); // "Numbers: 1 2 3 4 5 "

// Overload 3: seed + result selector
string result = nums.Aggregate(
    seed: new System.Text.StringBuilder(),
    func: (sb, x) => { sb.Append(x); if (x < 5) sb.Append('-'); return sb; },
    resultSelector: sb => sb.ToString());
Console.WriteLine(result); // "1-2-3-4-5"

// === Compose functions with Aggregate ===
var transforms = new Func<int, int>[] { x => x + 1, x => x * 2, x => x - 3 };
Func<int, int> composed = transforms.Aggregate(
    seed: (Func<int, int>)(x => x),          // identity
    func: (f, g) => x => g(f(x)));            // compose: first f, then g

Console.WriteLine(composed(10)); // ((10+1)*2)-3 = 19

// === MinBy / MaxBy (.NET 6+) ===
var products = new[]
{
    new { Name = "Apple",  Price = 1.2m },
    new { Name = "Banana", Price = 0.5m },
    new { Name = "Cherry", Price = 3.0m },
};

var cheapest = products.MinBy(p => p.Price);
var priciest = products.MaxBy(p => p.Price);
Console.WriteLine($"Cheapest: {cheapest?.Name}"); // Banana
Console.WriteLine($"Priciest: {priciest?.Name}"); // Cherry

// === Aggregate to build a dictionary (accumulator != element type) ===
var wordCounts = "the quick brown fox jumps over the lazy fox".Split()
    .Aggregate(
        seed: new Dictionary<string, int>(),
        func: (dict, word) => { dict[word] = dict.TryGetValue(word, out var c) ? c + 1 : 1; return dict; });

foreach (var (word, count) in wordCounts.Where(kv => kv.Value > 1))
    Console.WriteLine($"{word}: {count}"); // the: 2, fox: 2
```

## Common Follow-up Questions

- When should you use `Sum(selector)` vs `Select(selector).Sum()`?
- How do `Min(selector)` and `MinBy(selector)` differ in what they return?
- Is `Aggregate` thread-safe for parallel use with PLINQ?
- What is `Enumerable.TryGetNonEnumeratedCount` (.NET 6+) and how does it relate to `Count()`?
- How would you implement a running (cumulative) sum using `Aggregate`?
- What is the behavior of `Aggregate` on a single-element sequence without a seed?

## Common Mistakes / Pitfalls

- **Using `Aggregate` without a seed on an empty collection.** The no-seed overload throws `InvalidOperationException` if the sequence is empty — there's no first element to use as the accumulator. Always provide a seed when the sequence might be empty.
- **Using `Aggregate` for `Sum`, `Min`, or `Max`.** The built-in methods are optimized and communicate intent clearly. `Aggregate((a,b) => a + b)` is a code smell when `Sum()` exists.
- **Mutating the accumulator object and forgetting to return it.** In the `StringBuilder` example above, the lambda must return the same `StringBuilder` instance. Forgetting `return sb;` returns `null` and causes a `NullReferenceException` on the next iteration.
- **Using `Aggregate` as a substitute for `foreach` when the body is complex.** A 5-line lambda inside `Aggregate` is harder to read and debug than a `foreach` loop. Use `Aggregate` for concise, functional one-liners.
- **Confusing `MinBy` (returns the element) with `Min(selector)` (returns the minimum value).** `products.Min(p => p.Price)` returns `0.5m` (the price). `products.MinBy(p => p.Price)` returns the product object with the lowest price.

## References

- [Enumerable.Aggregate — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable.aggregate)
- [Enumerable.MinBy / MaxBy — .NET 6 API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable.minby)
- [Aggregation operations in LINQ — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/linq/standard-query-operators/aggregation-operations)
- [Enumerable.Sum — .NET API](https://learn.microsoft.com/dotnet/api/system.linq.enumerable.sum)
