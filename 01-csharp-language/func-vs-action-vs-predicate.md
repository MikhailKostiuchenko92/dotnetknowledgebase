# Func vs Action vs Predicate

**Category:** C# / Delegates, Events, Lambdas
**Difficulty:** Junior
**Tags:** `Func`, `Action`, `Predicate`, `delegate`, `callback`

## Question

> When do you use `Func<T>`, `Action<T>`, and `Predicate<T>`? What are the differences in their signatures?

Also asked as:
- "What is the difference between `Func<int, bool>` and `Predicate<int>`?"
- "When would you define your own delegate type instead of using `Action` or `Func`?"

## Short Answer

`Action` wraps any void-returning method, `Func` wraps any value-returning method (the last type parameter is the return type), and `Predicate<T>` is a special-purpose delegate that tests a condition and returns `bool`. `Predicate<T>` is semantically identical to `Func<T, bool>` and exists for historical/readability reasons. Prefer `Action` and `Func` in new code for consistency with LINQ and the rest of the BCL.

## Detailed Explanation

### Signature Summary

| Delegate | Signature | Example |
|---|---|---|
| `Action` | `void ()` | `Action print = () => Console.WriteLine("hi");` |
| `Action<T>` | `void (T)` | `Action<string> log = msg => Console.Write(msg);` |
| `Action<T1,T2>` | `void (T1, T2)` | `Action<int,int> add = (a,b) => total += a+b;` |
| `Func<TResult>` | `TResult ()` | `Func<DateTime> now = () => DateTime.UtcNow;` |
| `Func<T,TResult>` | `TResult (T)` | `Func<string,int> len = s => s.Length;` |
| `Func<T1,T2,TResult>` | `TResult (T1,T2)` | `Func<int,int,int> max = (a,b) => a>b?a:b;` |
| `Predicate<T>` | `bool (T)` | `Predicate<int> pos = n => n > 0;` |

All three families are generic delegates defined in `System` and support up to 16 input type parameters (`Action<T1…T16>`, `Func<T1…T16, TResult>`).

### `Func<T, bool>` vs `Predicate<T>`

They are structurally equivalent but are **different types** at the CLR level. You cannot pass a `Predicate<int>` where a `Func<int, bool>` is expected without a conversion:

```csharp
Predicate<int> p = n => n > 0;
Func<int, bool> f = n => n > 0;

// These are not interchangeable directly:
// IEnumerable<int>.Where() expects Func<int, bool>:
var pos1 = new[] {-1,2}.Where(f);   // ✅
var pos2 = new[] {-1,2}.Where(p);   // ❌ CS1503 — type mismatch

// Explicit conversion via lambda wrapper:
var pos3 = new[] {-1,2}.Where(n => p(n));   // ✅
```

`Predicate<T>` appears in older APIs (`List<T>.Find`, `List<T>.FindAll`, `Array.Find`, `Array.Exists`). LINQ was designed with `Func<T, bool>` consistently.

### When to Define a Custom Delegate Type

Prefer `Action`/`Func` in most cases. Define a named delegate when:

1. **`ref`/`out`/`in` parameters** are needed — generic delegates don't support them.
2. **Semantic clarity** outweighs brevity in a public API — `FileTransformer` is more meaningful than `Func<Stream, Stream, CancellationToken, Task>`.
3. **Recursive delegates** that reference themselves.
4. **COM interop or P/Invoke** requires a named delegate type.
5. **Events** — always use `EventHandler<T>` or a named delegate for event signatures.

### `Action` vs Return-Type Callbacks

A critical design choice when exposing a callback parameter:

| Use | When |
|---|---|
| `Action<T>` | Caller supplies side-effect behavior; return value not needed |
| `Func<T, TResult>` | Caller supplies a computation that produces a value |
| `Func<T, bool>` / `Predicate<T>` | Caller supplies a filter or condition |
| `Func<T, Task>` | Async void-like callback (fire and forget async) |
| `Func<T, Task<TResult>>` | Async callback that returns a result |

> **Rule:** Never use `async void` for callbacks that should propagate exceptions back to the caller. Use `Func<T, Task>` instead — callers can `await` it.

### Variance

`Func` and `Action` are covariant/contravariant in their type parameters (the BCL definitions use `out`/`in`):

```csharp
Func<string> getString = () => "hello";
Func<object> getObject = getString;   // ✅ covariant TResult (out TResult)

Action<object> logObject = o => Console.WriteLine(o);
Action<string> logString = logObject;  // ✅ contravariant T (in T)
```

This variance makes higher-order functions and composition pipelines composable without explicit casts.

## Code Example

```csharp
using System;
using System.Collections.Generic;
using System.Linq;

// --- Action variants ---
Action greet = () => Console.WriteLine("Hello!");
Action<string> greetName = name => Console.WriteLine($"Hello, {name}!");
Action<int, int> logSum = (a, b) => Console.WriteLine($"{a} + {b} = {a + b}");

greet();                // Hello!
greetName("Alice");     // Hello, Alice!
logSum(3, 4);           // 3 + 4 = 7

// --- Func variants ---
Func<int> getYear = () => DateTime.UtcNow.Year;
Func<string, int> wordCount = s => s.Split(' ').Length;
Func<int, int, int> add = (a, b) => a + b;

Console.WriteLine(getYear());                  // 2026 (or current year)
Console.WriteLine(wordCount("hello world"));   // 2
Console.WriteLine(add(10, 20));                // 30

// --- Predicate<T> vs Func<T, bool> ---
Predicate<string> isLong = s => s.Length > 5;
Func<string, bool> isLongFunc = s => s.Length > 5;

var words = new List<string> { "hi", "hello", "world", "go" };
List<string> filtered = words.FindAll(isLong);           // Predicate<T> ✅
IEnumerable<string> linqFiltered = words.Where(isLongFunc); // Func<T,bool> ✅

// Bridging: wrap Predicate in lambda to use with LINQ
var bridged = words.Where(w => isLong(w));

// --- Higher-order function with Func ---
static IEnumerable<TResult> Map<T, TResult>(IEnumerable<T> items, Func<T, TResult> fn)
    => items.Select(fn);

var lengths = Map(words, s => s.Length);
Console.WriteLine(string.Join(", ", lengths));   // 2, 5, 5, 2

// --- Async callback: Func<T, Task> not Action ---
static async Task ProcessAsync(string[] items, Func<string, Task> handler)
{
    foreach (var item in items)
        await handler(item);   // exceptions propagate correctly
}

await ProcessAsync(["a", "b"], async s =>
{
    await Task.Delay(1);
    Console.Write(s + " ");
});
// a b
```

## Common Follow-up Questions

- How does `Func<T1, T2, TResult>` compose with higher-order functions like `Compose` or `Pipe`?
- What is `Converter<TInput, TOutput>` and when does it appear in the BCL?
- How do you handle nullable return types with `Func<T, TResult?>` — does null flow differently?
- How does C#'s variance (`in`/`out`) on `Action` and `Func` interact with generic interface constraints?
- When is it worth creating a custom `delegate` type for a public API versus using `Func`?

## Common Mistakes / Pitfalls

- **Using `Action` for callbacks that should propagate exceptions asynchronously.** `async void` (the async form of Action-like callbacks) swallows exceptions to the `SynchronizationContext`. Always use `Func<Task>` or `Func<T, Task>` for async callbacks.
- **Expecting `Predicate<T>` and `Func<T, bool>` to be interchangeable.** They have the same runtime shape but are different CLR delegate types. Use a lambda bridge or explicit cast.
- **Too many type parameters in `Func` making code unreadable.** `Func<string, int, CancellationToken, Task<Result>>` is hard to read; define a named delegate or introduce a named type.
- **Forgetting that `Func`/`Action` up to 16 parameters covers all practical needs.** There is no built-in `Func<T1...T17, TResult>` — if you need more, you're overloading a single method; consider a parameter object.
- **Using `Action<T>` for an event callback instead of `EventHandler<T>`.** `Action` works but lacks the `sender` parameter and misses framework conventions (e.g., WPF binding infrastructure).

## References

- [Action Delegate — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.action)
- [Func Delegate — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.func-2)
- [Predicate Delegate — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.predicate-1)
- [Delegates — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/delegates/)
- [See: delegates-explained.md](./delegates-explained.md)
- [See: lambda-expressions-and-closures.md](./lambda-expressions-and-closures.md)
