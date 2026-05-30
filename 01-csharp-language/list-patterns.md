# List Patterns

**Category:** C# / Pattern Matching
**Difficulty:** Senior
**Tags:** `list-patterns`, `slice-pattern`, `switch`, `arrays`, `spans`, `pattern-matching`

## Question
> What are list patterns in C#, and how do they work with arrays and other list-like types?

Related phrasings:
- "How do C# list patterns and the slice pattern `..` work in practice?"
- "What kinds of types can participate in list patterns, and how are they commonly used in switch expressions?"
- "What are the trade-offs and limitations of list patterns compared with manual indexing logic?"

## Short Answer
List patterns let you match a sequence by its shape, length, and selected element values. Introduced in C# 11 and fully relevant in C# 12/13 on .NET 8/9, they support exact element checks like `[1, 2, 3]`, prefix or suffix matching, and slices via `..` to represent "the rest" of the sequence. They work best for readable protocol, route, and parser-style logic, but they rely on list-like shape rather than deep semantic understanding, so you still need to think about supported types, readability, and performance.

## Detailed Explanation

### What a List Pattern Matches
A list pattern matches the **shape** of a sequence. It can express:

- exact length: `[]`, `[x]`, `[x, y]`
- exact values: `["GET", "/health"]`
- prefix or suffix checks: `["api", ..]`, `[.., "health"]`
- mixed patterns: `[> 0, <= 10, ..]`

The mental model is close to destructuring by position. Each slot in the pattern corresponds to an element position in the target sequence.

### The Slice Pattern `..`
The slice pattern represents zero or more remaining elements. It can appear by itself or bind to a variable:

- `[1, ..]` means "starts with 1"
- `[.., 404]` means "ends with 404"
- `["api", .. var rest]` means "starts with `api` and bind the rest"

A list pattern can contain at most one slice. That rule keeps matching deterministic and readable.

| Pattern | Meaning |
|---|---|
| `[]` | Empty sequence |
| `[x]` | Exactly one element |
| `[head, ..]` | At least one element |
| `[.., tail]` | Ends with a specific element |
| `[first, .. var middle, last]` | Bind the middle slice |

### What Types Support List Patterns
List patterns are not restricted to arrays. They work with list-like types that expose the right shape to the compiler, typically a count/length and index access. In real .NET 8/9 code, common targets include:

- arrays
- `List<T>`
- spans and read-only spans in performance-sensitive code
- immutable collections and other custom list-like types that are countable and indexable

The key point is that the type must look like a sequence to the compiler. Pattern matching here is structural, not interface-driven in the broad "any `IEnumerable<T>`" sense.

> **Warning:** Do not describe list patterns as "working on any enumerable." They are for list-like, countable, indexable shapes, not arbitrary lazy sequences.

That distinction matters in interviews because many candidates incorrectly generalize them to all sequence abstractions.

### Why List Patterns Are Useful
List patterns are strongest when the sequence shape itself carries meaning. Examples include:

- URL or command segments
- tokens from a simple parser
- response status sequences
- CSV-like small records
- protocol headers or message frames

Instead of hand-writing `Length` checks and index access, you can let the pattern describe intent directly.

### Using List Patterns in Switch Expressions
List patterns become especially readable inside switch expressions because each arm can describe a distinct route or protocol shape.

For example, a route segment array can be classified like this:

- `[]` → home
- `["api", "health"]` → health endpoint
- `["api", "orders", .. var rest]` → orders subtree
- `_` → unknown route

That keeps branching declarative and pairs naturally with [switch-expressions.md](./switch-expressions.md).

### Trade-Offs and Performance Nuance
List patterns improve clarity, but they are not magic. A few trade-offs matter:

1. **Readability can degrade** if patterns become too dense.
2. **Supported-type shape matters**; not every collection abstraction qualifies.
3. **Performance still depends on the underlying type** because matching may involve length checks and indexed access.
4. **They are not regex for collections**. There is no arbitrary backtracking or multi-slice matching.

For hot paths, prefer measuring rather than assuming list patterns are automatically better or worse than manual indexing. The compiler-generated checks are often good, but the underlying collection shape still matters.

### List Patterns and Other Pattern Types
List patterns can combine with:

- constant patterns: `["api", "health"]`
- relational patterns: `[> 0, > 0]`
- discard patterns: `[_, _, _]`
- nested property patterns if list elements are objects

That combination is what makes them expressive in C# 12/13 rather than just syntactic sugar.

## Code Example
```csharp
using System;

string[] route = ["api", "orders", "42"];

string description = route switch
{
    [] => "Root",
    ["health"] => "Health endpoint",
    ["api", "orders"] => "Orders index",
    ["api", "orders", var id] => $"Single order route for id {id}",
    ["api", .. var rest] => $"API route with {rest.Length} remaining segment(s)",
    [.., "metrics"] => "Metrics endpoint",
    _ => "Unknown route"
};

Console.WriteLine(description);

int[] values = [1, 2, 3, 4];
Console.WriteLine(values is [1, .., 4]);   // True: starts with 1 and ends with 4.
Console.WriteLine(values is [> 0, > 0, ..]); // True: first two are positive.
```

## Common Follow-up Questions
- What is the difference between a list pattern and the slice pattern `..`?
- Which kinds of .NET types can participate in list patterns?
- Why do list patterns work well inside switch expressions?
- Can list patterns be combined with relational, constant, or property patterns?
- Why is it inaccurate to say list patterns work with any `IEnumerable<T>`?
- What performance considerations would you mention for hot paths?

## Common Mistakes / Pitfalls
- Claiming list patterns work with every enumerable sequence.
- Forgetting that only one slice pattern `..` is allowed in a single list pattern.
- Writing very clever but unreadable nested list patterns.
- Assuming list patterns are always the fastest option without measuring.
- Using manual indexing when a small list pattern would communicate intent much more clearly.

## References
- [Patterns - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/patterns)
- [Pattern matching overview](https://learn.microsoft.com/dotnet/csharp/fundamentals/functional/pattern-matching)
- [The `switch` expression - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/switch-expression)
- [See: pattern-matching-overview.md](./pattern-matching-overview.md)
- [See: property-and-positional-patterns.md](./property-and-positional-patterns.md)
- [See: switch-expressions.md](./switch-expressions.md)
