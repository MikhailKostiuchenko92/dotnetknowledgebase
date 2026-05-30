# Null-Conditional and Null-Coalescing Operators

**Category:** C# / Nullability & Null Handling
**Difficulty:** Junior
**Tags:** `null-conditional`, `null-coalescing`, `null-coalescing-assignment`, `short-circuiting`, `null-safety`

## Question
> What do the null-conditional and null-coalescing operators do in C#?

Related phrasings:
- "How do `?.`, `?[]`, `??`, and `??=` work, and when should I use them?"
- "What does short-circuiting mean for null-conditional access?"
- "Are `?.Invoke()` and `??=` enough to make code thread-safe?"

## Short Answer
`?.` and `?[]` let you safely access a member or indexer only when the left side is not null, while `??` and `??=` provide fallback values when an expression is null. In modern C# 12/13 on .NET 8/9, these operators are standard tools for null-safe, readable code. They reduce boilerplate, but they do not make shared mutable state automatically thread-safe, so you still need proper synchronization when multiple threads can update the same data.

## Detailed Explanation

### Null-Conditional Operators: `?.` and `?[]`
A null-conditional operator stops evaluation when the left operand is null.

| Operator | Meaning |
|---|---|
| `?.` | Access member if receiver is non-null |
| `?[]` | Access indexer/array element if receiver is non-null |

Example:

```csharp
customer?.Address?.City
```

If `customer` is null, the whole expression becomes null immediately. If `customer` exists but `Address` is null, the result is still null. That is the short-circuiting behavior.

### Null-Coalescing Operators: `??` and `??=`
`??` gives a fallback value when the left operand is null:

```csharp
var city = customer?.Address?.City ?? "Unknown";
```

`??=` assigns only when the left side is null:

```csharp
cache ??= new Dictionary<string, string>();
```

This is concise for lazy initialization of local or instance state.

### Short-Circuiting and Evaluation
Short-circuiting means the rest of the chain is skipped once a null receiver is found. That avoids `NullReferenceException` and avoids unnecessary work.

> **Tip:** These operators improve readability most when they express a simple access chain. If the expression becomes long and dense, a few named locals or guard clauses can be easier to maintain.

### Thread-Safety Nuance
This is a common interview trap. `?.` and `??=` are null-handling operators, not synchronization primitives.

- `handler?.Invoke(...)` is useful because the event/delegate reference is evaluated once for that call.
- But it does **not** make the underlying object graph thread-safe.
- `cache ??= new Cache()` is convenient, but if multiple threads race to initialize shared state, you may still need `lock`, `Lazy<T>`, or another synchronization mechanism.

So the correct statement is: these operators help with null safety and concise code, not general concurrency safety.

### When to Use Them
These operators are ideal for:

- optional navigation through object graphs
- fallback defaults
- lazy initialization of simple state
- code working with [nullable-reference-types.md](./nullable-reference-types.md)

They are less appropriate when heavy business logic is hidden inside a complex chain.

## Code Example
```csharp
using System;
using System.Collections.Generic;

User? user = new(
    new Address("Kyiv"),
    ["admin", "editor"]);

string city = user?.Address?.City ?? "Unknown";
string firstRole = user?.Roles?[0] ?? "guest";

Console.WriteLine(city);      // Kyiv
Console.WriteLine(firstRole); // admin

Dictionary<string, string>? cache = null;
cache ??= new Dictionary<string, string>(); // Initialize only if null.
cache["theme"] = "dark";

Action? onSaved = () => Console.WriteLine("Saved");
onSaved?.Invoke(); // Convenient null-safe delegate invocation.

user = null;
Console.WriteLine(user?.Address?.City ?? "Unknown");

public sealed record Address(string City);
public sealed record User(Address? Address, string[]? Roles);
```

## Common Follow-up Questions
- What is the difference between `?.` and `??`?
- How does `?[]` behave compared with normal indexing?
- Why does short-circuiting matter for null-safe access chains?
- Why does `??=` not guarantee thread-safe lazy initialization?
- When would a guard clause be clearer than a long null-conditional chain?

## Common Mistakes / Pitfalls
- Assuming `??=` is a synchronization mechanism for shared state.
- Building very long `?.` chains that become hard to debug and read.
- Forgetting that `?[]` only protects against a null receiver, not an out-of-range index.
- Using `??` when null should actually be treated as a bug and validated explicitly.

## References
- [Member access operators - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/member-access-operators)
- [The null-coalescing operators `??` and `??=` - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/null-coalescing-operator)
- [Nullable reference types](https://learn.microsoft.com/dotnet/csharp/nullable-references)
- [See: nullable-reference-types.md](./nullable-reference-types.md)
- [See: null-forgiving-operator.md](./null-forgiving-operator.md)
