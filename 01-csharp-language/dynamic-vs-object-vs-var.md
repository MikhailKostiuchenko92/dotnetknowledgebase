# `dynamic` vs `object` vs `var`

**Category:** C# / Type System
**Difficulty:** 🟡 Middle
**Tags:** `dynamic`, `object`, `var`, `DLR`, `compile-time`, `runtime`, `type-inference`

## Question

> What is the difference between `dynamic`, `object`, and `var` in C#?

Additional phrasings:
- *"When would you choose `dynamic` over `object`?"*
- *"Does `var` have any runtime overhead compared to explicit type declarations?"*

## Short Answer

`var` is pure compile-time type inference — the compiler resolves the actual type at compile time, so there is zero runtime difference from an explicit declaration. `object` is the base type of all types; it holds any value, but member access is resolved at compile time and requires casting. `dynamic` defers member resolution entirely to runtime via the DLR; you can call any method on it without casting, but you lose compile-time safety and pay runtime overhead. Use `var` freely, use `object` when truly polymorphic, use `dynamic` only for interop scenarios (COM, dynamic languages, reflection-heavy code).

## Detailed Explanation

### `var` — Compile-Time Inference, Zero Runtime Cost

`var` instructs the compiler to infer the type from the right-hand side. The compiled IL is **identical** to using the explicit type. It is not "dynamic" in any sense:

```csharp
var x = 42;      // compiler infers int; IL: ldloc int32
int y = 42;      // identical IL
```

Rules:
- The right-hand side must have an unambiguous type at compile time.
- Cannot be used as a field, return type, or method parameter (only local variables and `foreach`).
- `var` declared with a lambda produces a `Func<...>` or `Action<...>` type.

**No runtime cost. No dynamic dispatch. No overhead.**

### `object` — Static Typing at the Base

`object` (alias for `System.Object`) is the root of the C# type hierarchy. Every type implicitly inherits from it, so you can store any value in an `object` variable:

```csharp
object o = 42;       // boxes the int — heap allocation
object s = "hello";  // reference to string on heap
```

Member access is **resolved at compile time** — only members defined on `System.Object` are accessible without a cast (`ToString()`, `GetHashCode()`, `Equals()`, `GetType()`). Accessing any other member requires an explicit cast and a potential `InvalidCastException` at runtime.

Key points:
- Storing a value type in `object` causes **boxing** — see [boxing-and-unboxing.md](./boxing-and-unboxing.md).
- Type safety is enforced by the compiler for what you can call; you must cast to access derived members.
- Used when you genuinely don't know or don't care about the concrete type at design time (e.g., legacy non-generic collections, serialization, plug-in systems).

### `dynamic` — Runtime Dispatch via the DLR

`dynamic` tells the compiler to skip static type checking for that expression and resolve all member access at runtime using the **Dynamic Language Runtime (DLR)**:

```csharp
dynamic d = 42;
d.FakeMethod(); // compiles! fails at runtime: RuntimeBinderException
```

The DLR resolves method calls, property access, and operators using runtime reflection and caching. It supports:
- Regular C# objects (via `IDynamicMetaObjectProvider` or fallback reflection).
- COM objects (where member names may not be known at compile time).
- `ExpandoObject` (a dictionary-backed dynamic object).
- IronPython / IronRuby objects.

Costs of `dynamic`:
- **Compile-time safety is gone** — typos become runtime errors.
- **Performance overhead** — DLR reflection and cache lookup, even with caching.
- **IntelliSense/refactoring tools don't work** on dynamic expressions.
- **AOT / trimming incompatibility** — `dynamic` relies on reflection, which is hostile to Native AOT.

> `dynamic` is syntactic sugar: the compiler emits `CallSite<T>` infrastructure that the DLR uses to cache dispatch decisions. After the first call, subsequent calls to the same site with the same runtime type are faster (cached), but still slower than static dispatch.

### Comparison Table

| Feature | `var` | `object` | `dynamic` |
|---|---|---|---|
| Type resolution | Compile time | Compile time | Runtime (DLR) |
| Requires cast to access members | N/A (type is known) | Yes | No |
| Compile-time type safety | ✅ Full | ✅ For `object` members | ❌ None |
| Boxing (for value types) | No | Yes | Depends on usage |
| Runtime overhead | None | None (after boxing) | Yes (DLR) |
| IntelliSense support | ✅ Full | ✅ For `object` members | ❌ None |
| Native AOT compatible | ✅ Yes | ✅ Yes | ❌ No |
| Primary use case | Readability/inference | Heterogeneous containers | COM / dynamic interop |

### When to Use `dynamic`

`dynamic` is the right tool in a narrow set of scenarios:
1. **COM interop** — Office automation APIs (Word, Excel) use late-bound dispatch; `dynamic` removes mountains of casting.
2. **Dynamic scripting hosts** — Hosting IronPython/IronRuby objects.
3. **`ExpandoObject`** — Building property bags for scenarios like JSON-like dynamic objects.
4. **Reflection-heavy code** — Sometimes `dynamic` is cleaner than `MethodInfo.Invoke`, but source generators or `Func<>` are usually better alternatives.

For all other cases: prefer static types, generics, or interfaces.

## Code Example

```csharp
// === var: compile-time inference, no overhead ===
var count = 0;                    // int
var name = "Alice";               // string
var items = new List<string>();   // List<string>
// var wrong;                     // ❌ compile error: no initializer

// === object: base type, requires cast ===
object o = 42;                    // boxes int
// o.CompareTo(43);               // ❌ compile error: CompareTo not on object
int n = (int)o;                   // unboxing
Console.WriteLine(o.GetType());   // System.Int32

object mixed = "hello";
if (mixed is string s)            // pattern match — no InvalidCastException risk
    Console.WriteLine(s.ToUpper()); // HELLO

// === dynamic: DLR runtime dispatch ===
dynamic d = "hello";
Console.WriteLine(d.ToUpper());   // works at runtime: "HELLO"
Console.WriteLine(d.Length);      // 5

d = 42;                           // reassign to a different type
Console.WriteLine(d + 8);        // 50 — DLR resolves + for int at runtime

// d.NonExistentMethod();         // compiles fine, throws RuntimeBinderException

// === dynamic for COM interop pattern ===
// (Illustrative — requires Office COM references)
// dynamic excel = Activator.CreateInstance(Type.GetTypeFromProgID("Excel.Application")!);
// excel.Visible = true;          // no cast needed

// === ExpandoObject with dynamic ===
dynamic expando = new System.Dynamic.ExpandoObject();
expando.Name = "Bob";             // adds "Name" property at runtime
expando.Greet = (Action)(() => Console.WriteLine($"Hi, {expando.Name}"));
expando.Greet();                  // Hi, Bob
```

## Common Follow-up Questions

- How does the DLR cache dispatch decisions, and what is a `CallSite<T>`?
- Is `dynamic` compatible with .NET Native AOT compilation? Why or why not?
- How does `ExpandoObject` work internally (hint: `IDictionary<string, object>`)?
- Can you use `dynamic` with generics — e.g., `List<dynamic>`?
- What is the performance difference between `dynamic` dispatch and a virtual method call?
- Why can't you use `var` for class fields or method return types?

## Common Mistakes / Pitfalls

- **Using `dynamic` to avoid writing a proper interface or generic.** This trades compile-time safety for runtime crashes; almost always a design smell outside of interop.
- **Thinking `var` is dynamic.** `var` is fully statically typed at compile time — the IL is identical to an explicit type declaration.
- **Using `object` where generics would be better.** Non-generic collections (`ArrayList`, `Hashtable`) cause boxing for value types and require casts. Use `List<T>`, `Dictionary<TKey, TValue>`, etc.
- **Using `dynamic` in a Native AOT or trimming-enabled project.** The DLR and reflection are incompatible with linker-trimmed assemblies; you'll get runtime failures.
- **Forgetting that `dynamic` member access is a `RuntimeBinderException`, not a `NullReferenceException`, on failure.** The error message can be confusing if you're not expecting it.

## References

- [dynamic type — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/reference-types#the-dynamic-type)
- [Using type dynamic — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/types/using-type-dynamic)
- [Implicitly typed local variables (var) — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/implicitly-typed-local-variables)
- [Dynamic Language Runtime overview — Microsoft Learn](https://learn.microsoft.com/dotnet/framework/reflection-and-codedom/dynamic-language-runtime-overview)
