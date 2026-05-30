# Delegates Explained

**Category:** C# / Delegates, Events, Lambdas
**Difficulty:** Junior
**Tags:** `delegate`, `Action`, `Func`, `Predicate`, `multicast`

## Question

> What is a delegate in C#? What are `Action`, `Func`, and `Predicate`, and when do you use each?

Also asked as:
- "How is a delegate different from a function pointer?"
- "What does `delegate` compile to under the hood?"

## Short Answer

A delegate is a type-safe object that holds a reference to one or more methods with a matching signature. The CLR implements each delegate as a class derived from `System.MulticastDelegate`. `Action<T>` wraps a void-returning method, `Func<T, TResult>` wraps a method that returns a value, and `Predicate<T>` wraps a bool-returning method that tests a condition. You use the built-in generic forms (`Action`/`Func`) instead of defining custom delegate types in almost every modern scenario.

## Detailed Explanation

### What a Delegate Really Is

Every `delegate` declaration is syntactic sugar for a sealed class the compiler generates, inheriting `MulticastDelegate`. The generated class has:
- A constructor taking `(object target, IntPtr methodPointer)`.
- An `Invoke(...)` method matching the signature.
- `BeginInvoke`/`EndInvoke` (legacy, no longer recommended).

```
public delegate int MathOp(int a, int b);

// Compiler generates approximately:
public sealed class MathOp : MulticastDelegate
{
    public int Invoke(int a, int b);
    // ...
}
```

Because a delegate is an object, it:
- Can be stored in a variable or field.
- Can be passed as a method argument.
- Can be combined (multicast) with `+` / `+=`.
- Is subject to garbage collection when no longer referenced.

### Delegate vs Function Pointer

| | Delegate | Function pointer (`delegate*`) |
|---|---|---|
| Type safety | ✅ full | ✅ full |
| Heap allocation | ✅ allocates an object | ❌ value (pointer only) |
| Supports instance methods | ✅ captures `this` | ❌ static / unmanaged only |
| Multicast (multiple targets) | ✅ | ❌ |
| Supported since | C# 1 | C# 9 (unsafe context) |

Use `delegate*` only in high-performance unmanaged interop scenarios. For all normal application code, use delegates.

### The Built-in Generic Delegate Families

**`Action` (void return):**

| Type | Signature |
|---|---|
| `Action` | `void ()` |
| `Action<T>` | `void (T arg1)` |
| `Action<T1, T2>` | `void (T1, T2)` |
| … | up to 16 type parameters |

**`Func` (non-void return):**

| Type | Signature |
|---|---|
| `Func<TResult>` | `TResult ()` |
| `Func<T, TResult>` | `TResult (T arg1)` |
| `Func<T1, T2, TResult>` | `TResult (T1, T2)` |
| … | up to 16 input + 1 return |

**`Predicate<T>` (bool test):**

| Type | Signature |
|---|---|
| `Predicate<T>` | `bool (T item)` |

> `Predicate<T>` is equivalent to `Func<T, bool>`. It exists for historical reasons (pre-LINQ) and appears in `List<T>.FindAll`, `Array.FindAll`, etc. Prefer `Func<T, bool>` in new code for consistency with LINQ.

### When to Define a Custom Delegate

- When you need `ref`, `in`, or `out` parameters (generic `Action`/`Func` don't support them).
- When semantic clarity matters more than conciseness (e.g., `ComparisonCallback<T>` vs `Func<T, T, int>`).
- When consuming legacy APIs that require a named delegate type.
- When working with events (see [events-vs-delegates.md](./events-vs-delegates.md)).

Otherwise, `Action`/`Func` are preferred — they avoid cluttering the codebase with single-use delegate types.

### Delegates Are Objects — Implications

Because delegates are heap objects, passing a lambda or method group creates an allocation. In hot paths, capture-free static lambdas (C# 9) or caching the delegate in a `static readonly` field avoids repeated allocations:

```csharp
// Allocates a new closure object each call if x is captured:
list.FindAll(item => item > x);

// No allocation when nothing is captured:
static readonly Predicate<int> _isPositive = n => n > 0;
list.FindAll(_isPositive);
```

## Code Example

```csharp
using System;
using System.Collections.Generic;

// --- Custom delegate (rarely needed in modern C#) ---
delegate int BinaryMath(int a, int b);

BinaryMath add = (a, b) => a + b;
BinaryMath mul = (a, b) => a * b;
Console.WriteLine(add(3, 4));   // 7
Console.WriteLine(mul(3, 4));   // 12

// --- Action<T> — void-returning callback ---
Action<string> log = msg => Console.WriteLine($"[LOG] {msg}");
log("App started");

// Method group assignment:
Action<string> writeErr = Console.Error.WriteLine;
writeErr("Something went wrong");

// --- Func<T, TResult> — value-returning transform ---
Func<int, int, int> max = (a, b) => a > b ? a : b;
Console.WriteLine(max(5, 9));   // 9

// LINQ uses Func internally:
var evens = new List<int> { 1, 2, 3, 4, 5 }.FindAll(n => n % 2 == 0);

// --- Predicate<T> --- 
Predicate<string> longEnough = s => s.Length > 5;
var words = new List<string> { "hi", "hello", "world", "go" };
var results = words.FindAll(longEnough);  // ["hello", "world"]

// --- Passing delegates as parameters ---
static T ApplyTwice<T>(T value, Func<T, T> transform)
    => transform(transform(value));

int quadrupled = ApplyTwice(3, x => x * 2);  // 12
```

## Common Follow-up Questions

- What is a multicast delegate and what happens when it returns a value?
- How does `+=` on a delegate differ from `+=` on an event?
- What is the allocation cost of capturing variables in a lambda, and how do you avoid it?
- How do delegates relate to expression trees (`Expression<Func<T>>`)?
- When would you choose `delegate*` over `Func` for performance?

## Common Mistakes / Pitfalls

- **Ignoring the return value of multicast delegates.** When multiple targets are combined, `Invoke` only returns the value from the **last** target; intermediate return values are discarded. Use explicit looping if all results are needed.
- **Forgetting delegates are immutable objects.** `myDelegate += newMethod` creates a **new** delegate object; it doesn't mutate the existing one. The variable is re-assigned.
- **Using `Predicate<T>` in LINQ chains.** LINQ extension methods accept `Func<T, bool>`, not `Predicate<T>`. You'll need an explicit cast or a lambda wrapper if you have a `Predicate<T>` variable.
- **Creating a new lambda every call instead of caching.** A capture-free lambda that appears inside a hot loop still allocates a new delegate object on each call unless the JIT caches it (it usually does for static capture-free lambdas, but relying on this is fragile).
- **Storing a delegate that captures `this` in a long-lived collection.** The captured `this` prevents GC of the object — effectively a memory leak pattern similar to event subscriptions.

## References

- [Delegates — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/delegates/)
- [System.MulticastDelegate — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.multicastdelegate)
- [Action Delegate — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.action)
- [Func Delegate — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.func-2)
- [See: multicast-delegates.md](./multicast-delegates.md)
- [See: lambda-expressions-and-closures.md](./lambda-expressions-and-closures.md)
