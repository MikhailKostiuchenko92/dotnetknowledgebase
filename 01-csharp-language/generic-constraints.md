# Generic Constraints

**Category:** C# / Generics
**Difficulty:** 🟡 Middle
**Tags:** `generics`, `where`, `constraints`, `IComparable`, `new()`, `struct`, `class`, `notnull`

## Question

> What are generic constraints in C#, and when do you need them?

Additional phrasings:
- *"What is the difference between `where T : class` and `where T : struct`?"*
- *"How do you constrain a type parameter to types that have a parameterless constructor?"*

## Short Answer

Generic constraints (`where T : ...`) restrict which types can be used as type arguments. Without a constraint, `T` is treated as `object` — you can only call `object` members on it. Constraints give the compiler more information, enabling you to call interface methods, create instances, check nullability, and so on. Common constraints include `class` (reference type), `struct` (value type), `new()` (has parameterless constructor), interface/base-class constraints, `notnull`, and in C# 11 `allows ref struct`.

## Detailed Explanation

### Why Constraints Are Needed

Without a constraint, the compiler only knows `T` is "some type" — it cannot allow calling any methods beyond those on `object`:

```csharp
// ❌ Won't compile: the compiler doesn't know T has CompareTo
static T Max<T>(T a, T b) => a.CompareTo(b) >= 0 ? a : b;

// ✅ Constrained: compiler knows T implements IComparable<T>
static T Max<T>(T a, T b) where T : IComparable<T>
    => a.CompareTo(b) >= 0 ? a : b;
```

### Constraint Reference

| Constraint | Meaning |
|---|---|
| `where T : struct` | `T` must be a non-nullable value type |
| `where T : class` | `T` must be a reference type |
| `where T : class?` | `T` must be a reference type (nullable allowed) |
| `where T : notnull` | `T` must be non-nullable (value or reference) |
| `where T : unmanaged` | `T` must be an unmanaged type (no managed refs; allows `Span<T>` tricks) |
| `where T : new()` | `T` must have a public parameterless constructor |
| `where T : SomeBaseClass` | `T` must inherit from `SomeBaseClass` |
| `where T : ISomeInterface` | `T` must implement `ISomeInterface` |
| `where T : U` | `T` must be or derive from another type parameter `U` |
| `where T : allows ref struct` | `T` may be a `ref struct` (C# 13) |

Multiple constraints for one parameter are ANDed:
```csharp
where T : class, ISomeInterface, new()
// T must: be a ref type AND implement ISomeInterface AND have parameterless ctor
```

### `struct` vs `class`

`where T : struct` enables:
- `T` is guaranteed non-nullable.
- `default(T)` is always the zero value (never null).
- Used for `Nullable<T>`: `public struct Nullable<T> where T : struct`.

`where T : class` enables:
- `T` can be compared to `null`.
- `T` can be used with `as` pattern matching.
- Useful for repository patterns: `IRepository<T> where T : class`.

```csharp
// Only meaningful with struct constraint:
static T GetValueOrDefault<T>(T? nullable) where T : struct
    => nullable ?? default(T);

// Only meaningful with class constraint:
static T? FirstOrNull<T>(IEnumerable<T> source) where T : class
    => source.FirstOrDefault(); // returns null, not default(T)
```

### `new()` Constraint

Allows calling `new T()` inside the method. The constraint ensures a public parameterless constructor exists:

```csharp
static T CreateAndInit<T>() where T : new()
{
    T instance = new T(); // valid because of constraint
    return instance;
}
```

> `new()` must be the last constraint in a list. It cannot be combined with `struct` (structs implicitly have a parameterless constructor, but the constraint isn't needed).

### Interface and Base-Class Constraints

The most common use: requiring specific capabilities:

```csharp
// Repository pattern: T must be an entity class
public class Repository<T> where T : EntityBase, new() { ... }

// Sortable: T must be comparable to itself
public static IEnumerable<T> Sorted<T>(IEnumerable<T> source)
    where T : IComparable<T>
    => source.OrderBy(x => x);

// Generic math (C# 11 / .NET 7): T must support +, -, *, /
public static T Sum<T>(IEnumerable<T> source)
    where T : INumber<T>
    => source.Aggregate(T.Zero, (acc, x) => acc + x);
```

### `unmanaged` Constraint

Used for unsafe/interop scenarios — `T` must consist solely of primitive types or structs of unmanaged types (no managed references):

```csharp
static unsafe void WriteToMemory<T>(T* ptr, T value) where T : unmanaged
{
    *ptr = value;
}
```

This is used extensively in `Span<T>`, `MemoryMarshal`, and interop code.

### `notnull` Constraint

With nullable reference types enabled (`#nullable enable`), `notnull` ensures `T` can never be null:

```csharp
static void Process<T>(T value) where T : notnull
{
    // value is guaranteed non-null — compiler won't warn about null dereference
}
```

### Multiple Type Parameters with Constraints

```csharp
// K must be comparable; V can be any type
class SortedMap<TKey, TValue>
    where TKey : IComparable<TKey>
    where TValue : class
{ ... }
```

## Code Example

```csharp
using System.Numerics;

// === struct constraint: Nullable<T> reimplemented ===
struct Option<T> where T : struct
{
    private readonly T _value;
    public bool HasValue { get; }
    public T Value => HasValue ? _value : throw new InvalidOperationException();

    public Option(T value) { _value = value; HasValue = true; }
    public T GetValueOrDefault(T fallback = default) => HasValue ? _value : fallback;
}

var opt = new Option<int>(42);
Console.WriteLine(opt.GetValueOrDefault(-1)); // 42

// === class constraint: null-safe first ===
static T? FirstOrNull<T>(IEnumerable<T> items) where T : class
    => items.FirstOrDefault(); // returns null (not default) — class guaranteed

var first = FirstOrNull(new[] { "a", "b" });
Console.WriteLine(first ?? "none"); // "a"

// === new() constraint: factory ===
static T CreateDefault<T>() where T : new() => new T();
var sb = CreateDefault<System.Text.StringBuilder>(); // StringBuilder has ctor
Console.WriteLine(sb.GetType().Name); // StringBuilder

// === Interface constraint: generic sort ===
static List<T> Sorted<T>(IEnumerable<T> source) where T : IComparable<T>
    => [.. source.OrderBy(x => x)];

Console.WriteLine(string.Join(", ", Sorted(new[] { 3, 1, 4, 1, 5 }))); // 1,1,3,4,5
Console.WriteLine(string.Join(", ", Sorted(new[] { "b", "a", "c" }))); // a,b,c

// === Generic math (C# 11 / .NET 7) ===
static T Sum<T>(IEnumerable<T> source) where T : INumber<T>
    => source.Aggregate(T.Zero, (acc, x) => acc + x);

Console.WriteLine(Sum(new[] { 1, 2, 3, 4 }));          // 10 (int)
Console.WriteLine(Sum(new[] { 1.5, 2.5, 3.0 }));        // 7.0 (double)

// === Multiple constraints ===
interface IEntity { int Id { get; } }
class EntityBase : IEntity { public int Id { get; init; } }
class UserEntity : EntityBase { public string Name { get; init; } = ""; }

class Repository<T> where T : EntityBase, new()
{
    private readonly Dictionary<int, T> _store = [];
    public void Add(T entity) => _store[entity.Id] = entity;
    public T? Get(int id) => _store.TryGetValue(id, out var e) ? e : null;
    public T CreateEmpty() => new T(); // new() enables this
}

var repo = new Repository<UserEntity>();
repo.Add(new UserEntity { Id = 1, Name = "Alice" });
Console.WriteLine(repo.Get(1)?.Name); // Alice
```

## Common Follow-up Questions

- What is the `unmanaged` constraint and when is it used?
- How do generic constraints interact with nullable reference types (NRT)?
- Can you use `where T : Enum` as a constraint?
- What is `INumber<T>` and how does generic math work in C# 11?
- What is `allows ref struct` (C# 13) and what does it enable?
- Can a type parameter be constrained to another type parameter (`where T : U`)?

## Common Mistakes / Pitfalls

- **Combining `struct` and `new()`.** Structs always have a parameterless constructor; adding `new()` is redundant and actually disallowed — `struct` implies it. Use one or the other.
- **Forgetting `new()` when calling `new T()`.** Without the constraint, `new T()` is a compile error — the compiler can't verify `T` has a parameterless constructor.
- **Using a base class as a constraint when an interface is more appropriate.** Constraining to `EntityBase` instead of `IEntity` prevents using the method with classes that implement `IEntity` but don't inherit from `EntityBase`. Prefer interface constraints for flexibility.
- **Not constraining when using interface members.** Calling `T.CompareTo(...)` without `where T : IComparable<T>` is a compile error. A common beginner mistake is expecting that "obviously comparable types" work without the constraint.
- **Constraining to `class` and then comparing to `null` with `==`.** The `==` operator on an unconstrained `class` type uses reference equality. If `T` overrides `==` (like `string`), that override is only used if you call `Equals` explicitly or use pattern matching. Use `EqualityComparer<T>.Default` for safe equality.

## References

- [Constraints on type parameters — C# reference](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters)
- [Generic constraints — C# language reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/where-generic-type-constraint)
- [Generic math — .NET 7 feature overview](https://learn.microsoft.com/dotnet/standard/generics/math)
- [INumber<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.numerics.inumber-1)
