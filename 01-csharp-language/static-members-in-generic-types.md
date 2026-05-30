# Static Members in Generic Types

**Category:** C# / Generics
**Difficulty:** Senior
**Tags:** `generics`, `static-members`, `generic-math`, `INumber`, `closed-type`

## Question

> How do static fields and static members behave in generic types, and how does this interact with C# 11 static abstract members and the generic math (`INumber<T>`) feature?

Also asked as:
- "Why does `Counter<int>` and `Counter<string>` each have their own separate static field?"
- "What are static abstract interface members and how do they enable generic math in .NET 7+?"

## Short Answer

Each distinct closed generic type (e.g., `Counter<int>`, `Counter<string>`) gets its own separate copy of every static field. This per-closed-type isolation is a first-class CLR feature, not a C# trick. In .NET 7 (C# 11), static abstract and static virtual interface members were added, enabling algorithms to call static operations (operators, `Parse`, `Zero`) through a generic type parameter — the foundation of the generic math APIs in `System.Numerics`.

## Detailed Explanation

### Per-Closed-Type Static Fields

When the JIT compiles a generic type, it creates a distinct method table for each unique combination of type arguments. Static fields are stored in that method table's associated data, so they are **isolated per closed type**:

```
Counter<int>    → its own _count field (int storage)
Counter<string> → its own _count field (string storage)
Counter<>       → no instance at all; open types have no statics
```

This is intentional: it lets you build type-specific singletons and caches with zero explicit synchronization between type instantiations.

### Reference-Type Sharing at the JIT Level

The JIT shares a single native code body for all **reference-type** instantiations (`Counter<string>` and `Counter<object>` share IL code), but they still get **separate static field storage**. Value-type instantiations (`Counter<int>`, `Counter<long>`) each get fully specialized native code **and** separate storage.

### Common Patterns That Exploit This

**Type-specific singleton / pool:**

```csharp
public class TypedPool<T>
{
    private static readonly Stack<T[]> _free = new();   // one Stack per T
}
```

**Per-type cache with lazy initialization:**

```csharp
public static class MetadataCache<T>
{
    public static readonly PropertyInfo[] Properties =
        typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance);
}
```

Both patterns work because no cross-type pollution is possible.

### Static Abstract Interface Members (C# 11 / .NET 7)

Before C# 11 you could not call `T.Parse(str)` in a generic method because `Parse` is a static method and generic type parameters only expose instance members via constraints. C# 11 adds **static abstract** (and **static virtual**) members to interfaces:

```csharp
interface IAddable<T> where T : IAddable<T>
{
    static abstract T Zero { get; }
    static abstract T operator +(T a, T b);
}
```

Now you can write a generic sum:

```csharp
T Sum<T>(IEnumerable<T> items) where T : IAddable<T>
{
    T total = T.Zero;        // calling a static member through a type parameter ✅
    foreach (var item in items)
        total = total + item;
    return total;
}
```

### Generic Math (`System.Numerics`) — .NET 7+

.NET 7 introduced a hierarchy of numeric interfaces that use static abstract members:

| Interface | Key static members |
|---|---|
| `INumber<T>` | `Zero`, `One`, `IsNaN`, `Abs`, `Parse`, operators |
| `IAdditionOperators<T,T,T>` | `operator +` |
| `IComparisonOperators<T,T,bool>` | `operator <`, `>`, `<=`, `>=` |
| `IParsable<T>` | `T.Parse(string, IFormatProvider?)` |
| `IMinMaxValue<T>` | `MinValue`, `MaxValue` |

All built-in numeric types (`int`, `double`, `decimal`, `Half`, `Int128`, …) implement `INumber<T>`. Your own types can implement it too.

### Static Virtual (Default Implementation)

`static virtual` provides a default body; concrete types can optionally override it. This enables opt-in customization without breaking existing implementors.

```csharp
interface IShape<TSelf> where TSelf : IShape<TSelf>
{
    static abstract double Area(TSelf shape);
    static virtual string Description(TSelf shape) => $"Area: {TSelf.Area(shape):F2}";
}
```

### Gotchas with Per-Type Statics

> **Pitfall:** If a static initializer on a generic type throws, the entire closed type becomes poisoned with a `TypeInitializationException` for the process lifetime. This is the same as non-generic types, but harder to diagnose because the error appears attached to `MyClass<int>` rather than `MyClass`.

> **Pitfall:** `Counter<int>` and `Counter<long>` are completely unrelated types. A `List<Counter<int>>` cannot hold a `Counter<long>`. Developers sometimes expect shared state to flow between them.

### Thread Safety of Static Fields in Generic Types

Static fields in generic types follow the same rules as ordinary types. If multiple threads read/write the same closed-type static, you still need synchronization. A useful pattern is `Lazy<T>` or `Interlocked` to initialize once safely:

```csharp
public static class Validator<T>
{
    private static readonly Lazy<string[]> _rules =
        new(() => LoadRules(typeof(T)));

    public static string[] Rules => _rules.Value;
}
```

## Code Example

```csharp
using System;
using System.Numerics;

// --- Part 1: Per-closed-type static isolation ---
public class Counter<T>
{
    // Each Counter<X> has its own _count — completely isolated
    private static int _count;

    public static void Increment() => _count++;
    public static int Value => _count;
}

Counter<int>.Increment();
Counter<int>.Increment();
Counter<string>.Increment();

Console.WriteLine(Counter<int>.Value);     // 2
Console.WriteLine(Counter<string>.Value);  // 1  — separate field!

// --- Part 2: Generic math with static abstract members (.NET 7+) ---
static T Sum<T>(T[] values) where T : INumber<T>
{
    T total = T.Zero;             // T.Zero is a static abstract member call
    foreach (T v in values)
        total += v;               // T.operator+ via IAdditionOperators
    return total;
}

Console.WriteLine(Sum(new[] { 1, 2, 3 }));          // 6   (int)
Console.WriteLine(Sum(new[] { 1.5, 2.5, 3.0 }));    // 7.0 (double)

// --- Part 3: IParsable<T> through constraint ---
static T[] ParseAll<T>(string[] inputs) where T : IParsable<T>
    => Array.ConvertAll(inputs, s => T.Parse(s, null));

int[] ints = ParseAll<int>(["1", "2", "3"]);
Console.WriteLine(string.Join(", ", ints));   // 1, 2, 3

// --- Part 4: Custom type implementing INumber-like interface ---
interface IHasZero<TSelf> where TSelf : IHasZero<TSelf>
{
    static abstract TSelf Zero { get; }
    static abstract TSelf operator +(TSelf a, TSelf b);
}

readonly record struct Fraction(int Num, int Den) : IHasZero<Fraction>
{
    public static Fraction Zero => new(0, 1);
    public static Fraction operator +(Fraction a, Fraction b)
        => new(a.Num * b.Den + b.Num * a.Den, a.Den * b.Den);
    public override string ToString() => $"{Num}/{Den}";
}

Fraction total = Sum(new Fraction[] { new(1, 2), new(1, 3) });  // 5/6
Console.WriteLine(total);
```

## Common Follow-up Questions

- How does the JIT handle method table layout for generic types — does it differ between value-type and reference-type arguments?
- Can you use a static abstract member as an extension point for serialization (e.g., `T.FromJson(...)`)? What are the constraints?
- How do you implement `INumber<T>` on a custom type (e.g., a vector or matrix)?
- What is the `TSelf` pattern (`where T : ISomething<T>`) and why is it needed?
- How do static abstract members interact with reflection and `Activator.CreateInstance`?

## Common Mistakes / Pitfalls

- **Expecting static fields to be shared across closed types.** `Registry<int>._cache` and `Registry<string>._cache` are entirely separate dictionaries; writes to one are invisible in the other.
- **Using per-type statics for cross-type coordination** (e.g., a global sequence number). It works accidentally for value types because each is specialized, but fails for reference types sharing code — even though they still have separate storage.
- **Forgetting that open generic types (`List<>`) have no accessible statics at runtime.** You can get `typeof(List<>)` but cannot call `List<>.Empty`; you need a closed type.
- **Confusing `static abstract` with `static virtual`.** `abstract` means implementing types must provide the member; `virtual` provides a default. Using `abstract` in an interface forces every implementor to provide it — a breaking change if added to an existing interface.
- **Ignoring `TypeInitializationException` in generic statics.** If the static constructor for `MyCache<int>` throws (e.g., a file not found), accessing `MyCache<long>` will succeed normally — the error is per-closed-type, which can be deeply confusing to debug.
- **Not using `where T : INumber<T>` when you intend to call numeric operators.** Without the constraint the compiler has no idea `T` supports `+`, `-`, etc.

## References

- [Static abstract and virtual members — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/whats-new/tutorials/static-virtual-interface-members)
- [Generic Math — .NET Blog (Stephen Toub)](https://devblogs.microsoft.com/dotnet/dotnet-7-generic-math/)
- [System.Numerics INumber<T> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.numerics.inumber-1)
- [Generic Classes and Static Members — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/generic-classes)
- [See: generics-basics.md](./generics-basics.md)
- [See: covariance-and-contravariance.md](./covariance-and-contravariance.md)
