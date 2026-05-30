# Lambda Expressions and Closures

**Category:** C# / Delegates, Events, Lambdas
**Difficulty:** Middle
**Tags:** `lambda`, `closure`, `captured-variable`, `delegate`, `allocation`

## Question

> How do lambda expressions work in C#, and what is a closure? What are the allocation and mutation side effects of capturing variables?

Also asked as:
- "What does the compiler generate when you write a lambda that captures a local variable?"
- "Why does capturing a loop variable in a lambda often produce surprising results?"

## Short Answer

A lambda expression is anonymous syntax for creating a delegate. When a lambda references variables from the enclosing scope, the compiler generates a **closure** — a hidden class whose fields hold the captured variables. The lambda becomes an instance method on that class. Captured variables are shared by reference between the lambda and the enclosing code, meaning mutations in one are visible in the other; this causes the classic loop-variable capture bug.

## Detailed Explanation

### What the Compiler Generates

For a capture-free lambda, the compiler emits a **static method** and caches a single delegate instance:

```csharp
Func<int, int> double_ = x => x * 2;
// Compiler emits: private static int <M>b__0(int x) => x * 2;
// + a cached static field for the delegate
```

No allocation at the call site after the first use (the cached delegate is reused).

For a lambda that captures variables, the compiler generates a **closure class**:

```csharp
int multiplier = 3;
Func<int, int> mul = x => x * multiplier;

// Compiler generates approximately:
private sealed class <>c__DisplayClass
{
    public int multiplier;    // lifted from local variable
    public int <M>b__0(int x) => x * this.multiplier;
}

// Usage:
var closure = new <>c__DisplayClass { multiplier = 3 };
Func<int, int> mul = closure.<M>b__0;
```

A **new heap object** is allocated for every closure instantiation.

### Variables Are Captured by Reference (Shared)

The local variable `multiplier` ceases to exist as a stack slot; it becomes a **field on the closure object**. Both the enclosing method and the lambda read/write the same field:

```csharp
int count = 0;
Action increment = () => count++;
increment();
increment();
Console.WriteLine(count);   // 2 — the local 'count' was the closure field all along
```

### The Loop Variable Capture Bug

The classic pitfall: capturing a `for`/`foreach` loop variable captures the *variable*, not a snapshot of its value:

```csharp
var actions = new List<Action>();
for (int i = 0; i < 3; i++)
    actions.Add(() => Console.WriteLine(i));   // captures 'i' (the variable)

actions.ForEach(a => a());   // prints: 3  3  3  (not 0 1 2!)
```

All three lambdas share the same `i` field in the closure. When invoked after the loop, `i == 3`.

**Fix:** capture a copy inside the loop body:

```csharp
for (int i = 0; i < 3; i++)
{
    int copy = i;                                // new variable = new field in closure
    actions.Add(() => Console.WriteLine(copy));  // each lambda has its own 'copy'
}
actions.ForEach(a => a());   // 0  1  2 ✅
```

> **Note:** `foreach` with C# 5+ **does not** have this bug for the iteration variable itself — the compiler generates a fresh variable per iteration. Only `for` loops and captured index variables are affected.

### Allocation Cost Analysis

| Lambda form | Allocation |
|---|---|
| No captures | Zero (static method + cached delegate, reused) |
| Captures only static fields | Zero (same as no-capture) |
| Captures `this` only | One delegate object per registration (method group equivalent) |
| Captures local variable(s) | New closure object per lambda creation site execution |
| Captures multiple scopes | One closure per scope (can be several objects) |

In hot paths (tight loops, per-request middleware), closure allocation can be significant. Use `static` lambda (C# 9) or pull the captured value out of the loop to avoid repeated allocation.

### `static` Lambdas (C# 9) — Explicitly Disallow Captures

Annotating a lambda with `static` makes it a compile-time error to capture instance members or non-static locals:

```csharp
Func<int, int> pure = static x => x * 2;   // guaranteed no closure, no allocation

int y = 5;
Func<int, int> bad = static x => x + y;    // ❌ CS8820 — static lambda captures local
```

Use `static` lambdas in LINQ chains and high-frequency callbacks to self-document intent and enforce allocation-free semantics.

### Closures Extend Variable Lifetime

Because the closure object (heap) holds the variable, the variable lives **as long as the closure object is reachable**:

```csharp
Func<int> makeCounter()
{
    int n = 0;
    return () => ++n;   // 'n' is on the heap now; outlives the method call
}
var c = makeCounter();
Console.WriteLine(c());  // 1
Console.WriteLine(c());  // 2
```

This is intentional and useful — it's the basis of generators, memoization, and encapsulated state machines.

## Code Example

```csharp
using System;
using System.Collections.Generic;

// --- 1. Capture-free: zero allocation ---
Func<int, int> square = static x => x * x;
Console.WriteLine(square(5));   // 25

// --- 2. Captures a local: closure object allocated ---
int threshold = 10;
Func<int, bool> above = x => x > threshold;
Console.WriteLine(above(15));   // True
threshold = 20;
Console.WriteLine(above(15));   // False — shared field, mutation visible!

// --- 3. Loop variable bug and fix ---
var buggy  = new List<Action>();
var correct = new List<Action>();

for (int i = 0; i < 3; i++)
{
    buggy.Add(() => Console.Write(i + " "));    // all share same 'i'
    int snap = i;
    correct.Add(() => Console.Write(snap + " ")); // each gets own 'snap'
}

Console.WriteLine("Buggy:  ");  buggy.ForEach(a => a());    // 3 3 3
Console.WriteLine();
Console.WriteLine("Fixed:  ");  correct.ForEach(a => a());  // 0 1 2
Console.WriteLine();

// --- 4. Counter factory — closure survives method return ---
static Func<int> MakeCounter(int start = 0)
{
    int count = start;
    return () => ++count;   // count lives on heap inside closure
}

var c1 = MakeCounter();
var c2 = MakeCounter(100);
Console.WriteLine(c1());  // 1
Console.WriteLine(c1());  // 2
Console.WriteLine(c2());  // 101 — independent closure

// --- 5. static lambda enforces no-capture ---
// Func<int, int> broken = static x => x + threshold;  // CS8820 ❌
Func<int, int> safe = static x => x + 0;               // ✅
```

## Common Follow-up Questions

- How do closures interact with `async`/`await` — what gets captured when you `await` inside a lambda?
- What is the difference between a lambda and a local function (`static` or otherwise) from an allocation perspective?
- How does the compiler handle two lambdas in the same method that capture different sets of variables?
- Can a closure cause a deadlock if it captures a lock object?
- How does `Expression<Func<T>>` differ from `Func<T>` and what does "capturing" mean for expression trees?

## Common Mistakes / Pitfalls

- **Loop variable capture producing identical outputs.** The single most common lambda bug in C#. Always create an inner `var copy = loopVar;` before capturing in a loop.
- **Mutating a captured variable without realizing it's shared.** The enclosing method and the lambda both write to the same field; this can cause race conditions in multithreaded scenarios.
- **Storing event-subscribing lambdas without saving a reference.** You cannot unsubscribe an anonymous lambda unless you saved the delegate in a field. See [event-memory-leaks.md](./event-memory-leaks.md).
- **Not using `static` lambda for allocation-sensitive code.** A lambda inside a tight loop that doesn't actually capture anything still creates a new closure instantiation if written carelessly. Add `static` to prove (and enforce) zero capture.
- **Assuming closures from separate call sites are independent when they share a scope.** Two lambdas defined in the same method that each capture the same variable share a single closure object and can interfere with each other.

## References

- [Lambda Expressions — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/lambda-expressions)
- [Outer Variables and Closures — C# Language Spec §12.19.6 (ECMA)](https://ecma-international.org/publications-and-standards/standards/ecma-334/) (verify URL)
- [static anonymous functions — C# 9 what's new](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-9#static-anonymous-functions)
- [See: delegates-explained.md](./delegates-explained.md)
- [See: event-memory-leaks.md](./event-memory-leaks.md)
