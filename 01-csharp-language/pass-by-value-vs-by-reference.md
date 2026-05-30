# Pass by Value vs Pass by Reference

**Category:** C# / Type System
**Difficulty:** 🟡 Middle
**Tags:** `ref`, `out`, `in`, `pass-by-value`, `pass-by-reference`, `parameters`

## Question

> What is the difference between passing an argument by value and passing it by reference in C#?

Additional phrasings:
- *"If I pass a `class` object to a method, can the method change the caller's variable? What about a `struct`?"*
- *"What does `ref` actually do when applied to a reference-type parameter?"*

## Short Answer

By default, C# passes all arguments **by value**: a copy of the variable's content is made. For value types that means a copy of the data; for reference types it means a copy of the *reference* (pointer). Adding `ref` (or `out` / `in`) passes the variable **by reference** — the method receives the actual storage location, so it can replace the caller's variable entirely. This distinction is independent of whether the type is a value type or reference type.

## Detailed Explanation

### The Default: Pass by Value

When you call `Foo(x)`, C# copies the current content of `x` into the parameter slot:

- **Value type (`int`, `struct`):** the full bit-pattern of the value is copied. Mutations inside the method are invisible to the caller.
- **Reference type (`class`):** the *reference* (pointer) is copied. Both the caller's variable and the parameter now point to the same heap object. Mutating the object's fields is visible to the caller — but reassigning the parameter (`param = new Foo()`) only updates the local copy; the caller's variable still points to the original object.

This is the most common source of confusion: developers expect "reference type = pass by reference" but it isn't — passing a reference *by value* still allows you to mutate the shared object, but not to replace it from the caller's perspective.

### Pass by Reference with `ref`

Adding `ref` tells the compiler to pass a managed pointer to the variable's storage location:

```
Before call:  caller has variable at address 0x1A00 holding value 42
After ref:    method receives 0x1A00 directly — reads/writes go to the caller's memory
```

With `ref`:
- The method can **read and write** the caller's variable.
- The caller **must initialize** the variable before the call.
- Applies to both value types and reference types.

### Pass by Reference with `out`

`out` is like `ref` but with inverted initialization rules:
- The caller does **not** need to initialize the variable (it's treated as uninitialized on entry).
- The method **must assign** the variable before it returns.
- Commonly used for multiple return values (e.g., `TryParse`).

### Pass by Reference with `in`

`in` is a read-only reference parameter (introduced in C# 7.2):
- The method receives a reference but **cannot modify** the value (compiler-enforced).
- Intended for large `struct` parameters where copying is expensive but mutation is not desired.
- The caller passes a readable variable (can be `readonly` locals or expressions, where the compiler creates a temporary).

### Comparison Table

| Modifier | Caller must init? | Method can write? | Copies data? | Primary use case |
|---|---|---|---|---|
| *(none)* | Yes | Local copy only | Yes | Default, safe isolation |
| `ref` | Yes | Yes | No | Two-way data exchange |
| `out` | No | Must write | No | Multiple return values |
| `in` | Yes | No (read-only ref) | No | Large struct performance |

### Reference Type + `ref`: The Rarely-Needed Case

If you pass a reference-type variable with `ref`, the method can change *which object the caller's variable points to*. This is rarely the right design but is occasionally used in scenarios like object-pool exchanges.

```csharp
void Replace(ref string s) => s = "replaced";

string msg = "original";
Replace(ref msg);
Console.WriteLine(msg); // "replaced"
```

Without `ref`, `Replace` could only reassign its local copy of the reference.

[See also: ref-out-in-parameters.md](./ref-out-in-parameters.md) for more on the constraints and advanced use of these modifiers.

## Code Example

```csharp
// === Pass by value: value type ===
void DoubleIt(int n)
{
    n *= 2;             // only the local copy is changed
}
int x = 5;
DoubleIt(x);
Console.WriteLine(x);  // 5 — unchanged

// === Pass by value: reference type ===
void RenameFirst(List<string> names)
{
    names[0] = "Bob";       // mutates the shared object — visible to caller
    names = new List<string>(); // only replaces the local reference copy
}
var list = new List<string> { "Alice" };
RenameFirst(list);
Console.WriteLine(list[0]);         // "Bob"
Console.WriteLine(list.Count);      // 1 — list was NOT replaced

// === Pass by reference: ref ===
void DoubleRef(ref int n) => n *= 2;
int y = 5;
DoubleRef(ref y);
Console.WriteLine(y);  // 10 — caller's variable was modified

// === out: must be assigned, caller doesn't pre-init ===
bool TryDivide(int a, int b, out int result)
{
    if (b == 0) { result = 0; return false; }
    result = a / b;
    return true;
}
if (TryDivide(10, 2, out int quotient))
    Console.WriteLine(quotient);   // 5

// === in: read-only reference — no copy for large structs ===
readonly struct BigPoint(double X, double Y, double Z);

static double Magnitude(in BigPoint p) =>
    Math.Sqrt(p.X * p.X + p.Y * p.Y + p.Z * p.Z);
// p is not copied; cannot modify p.X inside Magnitude
```

## Common Follow-up Questions

- What are the restrictions on using `ref` and `out` parameters in `async` methods?
- When would you choose `in` over just passing by value for a small struct?
- Can you use `ref` with properties or array elements, and if so how?
- How do `ref return` and `ref local` extend these concepts?
- What is the difference between `out` and returning a tuple or `ValueTuple`?
- How does C# handle `ref` vs `out` at the IL level?

## Common Mistakes / Pitfalls

- **Believing "reference type = pass by reference."** A class instance passed without `ref` is passed *by value* (a value that happens to be a reference). The method gets its own copy of the pointer — reassignment is not visible to the caller.
- **Forgetting that `in` only prevents reassignment of the parameter, not mutation of its fields.** For a `struct`, the compiler defensively copies before calling methods on an `in` parameter unless the method is `readonly`. For a `class`, `in` merely prevents `param = new Foo()` — it can't prevent `param.Field = x`.
- **Forgetting to assign `out` parameters on every code path.** The compiler enforces this, but developers sometimes forget about exception paths or early-returns, leading to compilation errors.
- **Using `ref`/`out` for dependency injection or service locator patterns.** This produces unreadable code; use return values, tuples, or proper DI instead.
- **Passing a property with `ref`.** Properties don't have a storage location the compiler can take the address of; you'll get a compile error. Use a local variable as an intermediary.

## References

- [Passing parameters — C# Programming Guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/passing-parameters)
- [ref keyword — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/ref)
- [out parameter modifier — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/out-parameter-modifier)
- [in parameter modifier — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/in-parameter-modifier)
