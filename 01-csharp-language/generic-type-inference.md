# Generic Type Inference

**Category:** C# / Generics
**Difficulty:** Middle
**Tags:** `generics`, `type-inference`, `compiler`, `roslyn`

## Question

> How does the C# compiler infer generic type arguments, and in what situations does inference fail and require explicit specification?

Also asked as:
- "When do you need to write `Method<int>(x)` versus just `Method(x)` — what is the compiler actually doing?"
- "Why can't C# infer the return type of a generic method when there are no typed arguments?"

## Short Answer

The C# compiler infers generic type arguments by matching the types of provided arguments against the method's parameter types. Inference succeeds when every unbound type parameter appears at least once in an input position (parameter type, not return type). It fails when a type parameter appears only in the return type, when arguments are ambiguous between overloads, or when lambda return types create circular dependencies. In those cases you must provide the type argument(s) explicitly.

## Detailed Explanation

### How Inference Works (Phase 1: Bound Fixing)

Roslyn runs a two-phase process:
1. **Input type collection** — for each argument, the compiler examines the parameter type and records a *type bound* (lower, upper, or exact) for each unbound `T`.
2. **Fixing** — once all bounds are collected, the compiler picks the *best common type* for each `T`. If a single consistent type fits all bounds, inference succeeds; otherwise it fails with a compile error.

```csharp
void Print<T>(T value) { }

Print(42);          // T fixed as int   — trivial
Print("hello");     // T fixed as string
```

### Return-Type-Only Inference Does Not Work

If `T` appears **only** in the return type, there are no argument types to infer from:

```csharp
T Create<T>() where T : new() => new T();

// Compiler cannot infer T — no argument provides any hint
var x = Create();             // ❌ CS0411 — type arguments cannot be inferred
var x = Create<StringBuilder>(); // ✅ explicit
```

### Method Group and Lambda Inference

Lambdas without explicit parameter types participate in inference:

```csharp
IEnumerable<int> nums = [1, 2, 3];
var doubled = nums.Select(x => x * 2);   // T = int, TResult = int — both inferred
```

But when the lambda's own inference creates a cycle, it fails:

```csharp
void Invoke<T>(Func<T, T> fn, T arg) { }

Invoke(x => x + 1, 5);    // ✅ T = int: arg fixes T, lambda param follows
Invoke(x => x + 1, ???);  // ❌ if arg is ambiguous, lambda can't be typed
```

### Overload Resolution vs Inference

Inference and overload resolution are interleaved. If two overloads could succeed, inference is attempted for each candidate and the best applicable candidate wins. If both infer different types for `T`, neither wins and you must specify explicitly.

### Partial Inference (Some Type Args Explicit)

C# is all-or-nothing: you cannot specify some type args and let others be inferred:

```csharp
void Zip<TSource, TResult>(IEnumerable<TSource> src, Func<TSource, TResult> fn) { }

// You cannot write Zip<int>(src, x => x.ToString())
// Either specify both or neither (let inference handle it)
Zip(src, x => x.ToString());            // ✅ both inferred
Zip<int, string>(src, x => x.ToString()); // ✅ both explicit
```

> **Note:** C# has had proposals to allow partial type argument specification, but as of C# 13 it is not supported.

### Inference Across Multiple Arguments — Best Common Type

When the same `T` is fixed by multiple arguments, the compiler picks the *best common type* — a type that all candidates convert to:

```csharp
T Max<T>(T a, T b) where T : IComparable<T> => a.CompareTo(b) > 0 ? a : b;

Max(1, 2);          // T = int
Max(1, 2.0);        // ❌ int and double — no single best common type; explicit required
Max<double>(1, 2.0); // ✅ explicit, 1 converts to double
```

### Interface / Variance Inference

Variance annotations (`in`/`out`) influence upper/lower bounds during inference. An `out T` position contributes a **lower bound**, `in T` an **upper bound**, and invariant positions contribute **exact bounds**. Exact bounds take priority and can cause inference to fail if they conflict with variance bounds.

### Practical Rules

| Situation | Inference outcome |
|---|---|
| `T` in all parameter positions, unambiguous | ✅ inferred |
| `T` in return type only | ❌ must specify |
| `T` only in `out` parameter | ❌ must specify |
| Conflicting bounds from multiple args | ❌ must specify |
| Partial specification (only some type args) | ❌ not supported |
| Generic delegate/lambda, param types known | ✅ inferred |
| Method group conversion | ✅ usually inferred |

## Code Example

```csharp
using System;
using System.Collections.Generic;

// ------ CASE 1: Successful inference ------
T Echo<T>(T value) => value;

string s = Echo("hello");   // T inferred as string
int n = Echo(42);            // T inferred as int

// ------ CASE 2: Return-type-only — must specify ------
T Default<T>() => default!;

// var bad = Default();          // CS0411 — cannot infer
var ok = Default<DateTime>();   // explicit required

// ------ CASE 3: Two type params, both inferred ------
TOut Transform<TIn, TOut>(TIn input, Func<TIn, TOut> fn) => fn(input);

// Both TIn = int, TOut = string inferred from arguments:
string result = Transform(42, x => x.ToString());

// ------ CASE 4: Ambiguous — must be explicit ------
T Max<T>(T a, T b) where T : IComparable<T> => a.CompareTo(b) >= 0 ? a : b;

// Max(1, 2.0);                 // CS0411 — int vs double conflict
double d = Max<double>(1, 2.0); // explicit resolves conflict

// ------ CASE 5: Partial specification not allowed ------
void Zip<TSource, TResult>(IEnumerable<TSource> src, Func<TSource, TResult> fn)
    => Console.WriteLine($"{typeof(TSource).Name} -> {typeof(TResult).Name}");

int[] arr = [1, 2, 3];
Zip(arr, x => x.ToString());                  // ✅ both inferred
Zip<int, string>(arr, x => x.ToString());      // ✅ both explicit
// Zip<int>(arr, x => x.ToString());          // ❌ partial — not allowed
```

## Common Follow-up Questions

- How does `var` interact with generic type inference — are they the same mechanism?
- What is the "best common type" algorithm and when does it produce a base type rather than failing?
- How does C# 9+ target-type inference change `new()` expressions in generic code?
- Why can't the compiler infer `T` from `Func<T>` return types when the lambda is provided?
- How does generic type inference work with extension methods versus static methods?

## Common Mistakes / Pitfalls

- **Expecting inference from the return type.** Many developers are surprised that `var x = Parse<int>(str)` is fine but `var x = Create<???>()` requires an explicit argument — the return type isn't an input to inference.
- **Assuming partial type arg specification is allowed.** It isn't — you must specify all or none. This trips up developers coming from languages like Swift or Kotlin that support partial inference.
- **Not specifying type args when two methods overload identically.** If two generic overloads are both applicable, the compiler may fail to resolve them; explicit type arguments disambiguate.
- **Forgetting that `null` doesn't infer a type.** `Echo(null)` fails because `null` alone has no type; use `Echo((string?)null)` or explicit `Echo<string?>(null)`.
- **Relying on inference inside nested generic expressions** (e.g., `Tuple.Create(List.Create(1))`). Deep nesting can break inference unexpectedly; extracting an intermediate `var` often fixes it.

## References

- [Type Inference — C# Language Specification §12.6.3 (ECMA)](https://ecma-international.org/publications-and-standards/standards/ecma-334/) (verify URL)
- [Generic Methods — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/generic-methods)
- [Roslyn Type Inference Source (GitHub)](https://github.com/dotnet/roslyn/blob/main/src/Compilers/CSharp/Portable/Binder/Binder_Invocation.cs) (verify URL)
- [See: generics-basics.md](./generics-basics.md)
- [See: generic-constraints.md](./generic-constraints.md)
