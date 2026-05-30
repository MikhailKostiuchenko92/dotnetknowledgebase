# `ref`, `out`, and `in` Parameters

**Category:** C# / Type System
**Difficulty:** 🟡 Middle
**Tags:** `ref`, `out`, `in`, `parameters`, `by-reference`, `performance`

## Question

> What is the difference between `ref`, `out`, and `in` parameter modifiers in C#? When would you use each?

Additional phrasings:
- *"Why can't you use `ref` or `out` parameters in an `async` method?"*
- *"What is `in` for, and does it actually help performance?"*

## Short Answer

`ref` passes a variable by reference — the caller must initialize it, and the method can both read and write it. `out` is also by reference but the caller need not initialize it — the method must assign it before returning. `in` is a read-only reference — no copy is made, but the method cannot modify the value. Use `ref` for two-way exchange, `out` for multiple return values, and `in` to avoid copying large structs in performance-sensitive code.

## Detailed Explanation

### `ref` — Bidirectional Reference

`ref` tells the compiler to pass the variable's **storage location** rather than a copy. The method can read the current value *and* overwrite it:

- **Caller requirement:** the variable must be definitely assigned before the call.
- **Method requirement:** none — the method can read, write, or ignore the value.
- Applies to both value types and reference types. On a reference type, `ref` lets the method replace the caller's reference (i.e., make the caller's variable point to a different object).

Typical uses: swap utilities, accumulator patterns, or when modifying a struct without boxing.

### `out` — Output-Only Reference

`out` is syntactic sugar for a `ref` that carries an "uninitialized on entry" contract:

- **Caller requirement:** no initialization needed (the compiler treats it as unassigned).
- **Method requirement:** all code paths must assign the `out` parameter before returning; the compiler enforces this.
- Starting from C# 7, you can declare `out` variables inline: `int.TryParse(s, out int n)`.

Typical uses: `TryXxx` patterns, methods that naturally produce multiple outputs (e.g., `DateTime.TryParse`).

### `in` — Read-Only Reference

`in` (C# 7.2+) passes by reference but prevents the method from writing to the parameter:

- **Caller requirement:** a readable value (can be a variable, a field, or an expression — when an expression is used, the compiler creates a hidden temporary).
- **Method requirement:** cannot assign to the parameter or call non-`readonly` methods on it without triggering a defensive copy.
- On value types, the JIT passes a pointer rather than copying, which can be significant for structs larger than ~16 bytes on hot paths.

> **Gotcha with `in` and non-readonly structs:** If you call a method on a struct passed via `in` and that method isn't marked `readonly`, the compiler **silently creates a defensive copy** to ensure the `in` contract is maintained. This can negate the performance benefit. Mark struct methods `readonly` to avoid this.

### Restrictions

| Feature | `ref` | `out` | `in` |
|---|---|---|---|
| Caller must initialize | ✅ Yes | ❌ No | ✅ Yes |
| Method must assign | ❌ No | ✅ Yes | ❌ No (read-only) |
| Works in `async` methods | ❌ No | ❌ No | ❌ No |
| Works in iterators (`yield`) | ❌ No | ❌ No | ❌ No |
| Overloading: can differ from value param | ✅ Yes | ✅ Yes | ✅ Yes |

The async/iterator restriction exists because the compiler transforms `async` methods into a state machine class — there is no stable storage location that can hold a `ref`/`out`/`in` across `await` suspension points.

### `ref` Returns and `ref` Locals (Advanced)

C# 7+ allows methods to return references and locals to hold them:

```csharp
ref int Find(int[] arr, int val) { ... }
ref int slot = ref Find(arr, 42);
slot = 99; // modifies the array element in-place
```

This is advanced API design, primarily used in high-performance scenarios to avoid copying array elements.

### Modern Alternatives for Multiple Returns

Before `out` became ergonomic (inline declaration in C# 7), developers used `out` heavily for multiple returns. Today, **tuples** and **ValueTuple** are often cleaner:

```csharp
// Old style
bool TryGet(out string value) { ... }

// Modern alternative
(bool found, string value) TryGet() { ... }
```

`out` is still the right tool for `TryXxx` patterns where callers commonly discard the output value and just care about success (e.g., `Dictionary.TryGetValue`).

[See: pass-by-value-vs-by-reference.md](./pass-by-value-vs-by-reference.md) for the conceptual foundation.

## Code Example

```csharp
// === ref: two-way exchange ===
static void Swap<T>(ref T a, ref T b) => (a, b) = (b, a);

int p = 1, q = 2;
Swap(ref p, ref q);
Console.WriteLine($"{p}, {q}"); // 2, 1

// === out: must be assigned; caller doesn't need to init ===
static bool TryParseFraction(string s, out double numerator, out double denominator)
{
    var parts = s.Split('/');
    if (parts.Length != 2 ||
        !double.TryParse(parts[0], out numerator) ||
        !double.TryParse(parts[1], out denominator))
    {
        numerator = denominator = 0;
        return false;
    }
    return true;
}
if (TryParseFraction("3/4", out double num, out double den))
    Console.WriteLine(num / den); // 0.75

// === in: avoid copying a large struct ===
readonly struct Matrix4x4(float[] data)
{
    private readonly float[] _data = data;
    public readonly float Trace() => _data[0] + _data[5] + _data[10] + _data[15];
}

static float ComputeTrace(in Matrix4x4 m) => m.Trace(); // no copy

// === GOTCHA: non-readonly method on 'in' param → defensive copy ===
struct Counter
{
    public int Value;
    public void Increment() => Value++; // NOT readonly
}

static void Bad(in Counter c)
{
    c.Increment(); // compiler makes a temp copy; c.Value is unchanged after call
}

static void Good(in Counter c)
{
    // Access c.Value directly (read-only field access) — no copy needed
    Console.WriteLine(c.Value);
}
```

## Common Follow-up Questions

- How do `ref` returns and `ref` locals work, and when are they useful?
- Why does the compiler require `out` parameters to be assigned on every code path rather than just the happy path?
- What happens if you pass an `in` parameter to a method that accepts `ref`?
- How does the JIT optimize `in` parameter passing for small vs large structs?
- How does `in` compare to `readonly ref` in terms of codegen?
- What is `ref readonly` and how does it differ from `in`?

## Common Mistakes / Pitfalls

- **Using `ref` when `out` is more appropriate.** If the value is always written before being read inside the method, `out` communicates intent better and relaxes the initialization burden on callers.
- **Non-readonly methods on `in` parameters causing silent defensive copies.** Mark all struct methods that don't modify state as `readonly` to prevent this. The copy is silent — no warning, no error, just a subtle perf regression.
- **Trying to use `ref`/`out` in `async` methods.** This is a compile error; refactor to use `Task<T>` return types or wrap values in a class/tuple.
- **Passing a property directly as `ref`/`out`.** Properties don't have an addressable backing variable (from the caller's perspective); you need a local variable intermediary.
- **Overusing `ref` for simple "return a second value" cases.** Modern C# tuples (`(int a, int b) Foo()`) are cleaner for most such scenarios.

## References

- [ref keyword — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/ref)
- [out parameter modifier — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/out-parameter-modifier)
- [in parameter modifier — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/in-parameter-modifier)
- [Write safe and efficient C# code — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/write-safe-efficient-code)
