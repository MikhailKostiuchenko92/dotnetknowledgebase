# Generic Method vs Generic Class

**Category:** C# / Generics
**Difficulty:** Middle
**Tags:** `generics`, `generic-method`, `generic-class`, `type-parameters`, `design`

## Question

> When should you make a **method** generic instead of its containing **class**? What's the difference in flexibility, constraints, and lifetime of type parameters?

Also asked as:
- "What are the trade-offs between a generic class and a generic method?"
- "Can a non-generic class contain a generic method? When would you prefer that?"

## Short Answer

A generic class binds its type parameter(s) once at instantiation; every method on it shares those types. A generic method binds its type parameter(s) independently per call, giving callers more flexibility and avoiding the need to instantiate a typed class just to call one method. Prefer a generic method when only that operation needs to vary by type; prefer a generic class when state is type-parameterized or many members share the same type parameter.

## Detailed Explanation

### Generic Class — Type Parameter Bound at Construction

```
GenericRepository<Product>   // T = Product for the lifetime of this instance
```

Once you write `new GenericRepository<Product>()`, **every** method on that instance operates on `Product`. The class can hold typed fields (`T _cached;`), implement typed interfaces (`IRepository<T>`), and enforce constraints once for all members. The downside: to work with a different type you need a different instance.

### Generic Method — Type Parameter Bound per Call

```csharp
T Deserialize<T>(string json);   // T resolved independently each call
```

The method resolves `T` fresh at each call site. It can live on a completely non-generic class (`JsonHelper.Deserialize<User>(json)`) and is perfect when only the algorithm varies by type, not the object's identity.

### Decision Matrix

| Consideration | Generic Class | Generic Method |
|---|---|---|
| Type-parameterized **state** (fields) | ✅ natural | ❌ not possible |
| Shared type across **many members** | ✅ declare once | ❌ repeat on each method |
| Single operation that varies by type | 🔶 forces typed instance | ✅ cleaner |
| Type inference at call site | ❌ must specify in `new T<X>()` | ✅ often inferred |
| Registering in DI as open generic | ✅ `services.AddScoped(typeof(IRepo<>), typeof(Repo<>))` | ❌ not applicable |
| Multiple independent type axes per call | ❌ need multiple class TParams | ✅ `M<T1, T2>(T1 a, T2 b)` |

### Static Utility Classes — Natural Home for Generic Methods

Non-generic static helper classes frequently contain generic methods. The BCL is full of examples: `Enumerable.ToList<T>()`, `Activator.CreateInstance<T>()`, `Array.Empty<T>()`. Each call gets fresh type binding with zero instance overhead.

### Mixed: Non-Generic Class with Generic Methods

```csharp
public class Serializer          // no T at class level
{
    public T Deserialize<T>(string json) => /* ... */;
    public string Serialize<T>(T value) => /* ... */;
}
```

This pattern is ideal when the service itself has no type identity but exposes type-varying operations.

### Constraints Live Where the Type Parameter Is Declared

A constraint on a generic method only covers that method:

```csharp
public class Box<T>              // T is unconstrained here
{
    public void Print<U>(U value) where U : IFormattable { /* ... */ }
    // T is still unconstrained — no conflict
}
```

A constraint on the class applies to all methods sharing `T`. Adding `where T : new()` to the class prevents callers who have a type without a parameterless constructor.

### Interaction: Class + Method Type Parameters

A generic method on a generic class can introduce **additional** type parameters:

```csharp
public class Repository<TEntity>   // T bound at construction
{
    public TDto MapTo<TDto>() where TDto : new() { /* ... */ }  // U bound per call
}
```

The method type parameter is independent of the class type parameter.

> **Tip:** Avoid making a class generic purely to "future-proof" it. Over-generifying forces callers to specify types unnecessarily and makes the API harder to discover.

## Code Example

```csharp
// Non-generic class with generic methods — preferred for stateless helpers
public static class CollectionHelper
{
    // Type inferred from argument: CollectionHelper.First(myList)
    public static T? First<T>(IEnumerable<T> source)
        => source.FirstOrDefault();

    // Two independent type parameters on one method
    public static Dictionary<TKey, TValue> ToDictionary<TKey, TValue>(
        IEnumerable<(TKey, TValue)> pairs) where TKey : notnull
        => pairs.ToDictionary(p => p.Item1, p => p.Item2);
}

// Generic class — state is typed, all members share the same T
public class TypedCache<T> where T : class
{
    private readonly Dictionary<string, T> _store = new();

    public void Set(string key, T value) => _store[key] = value;
    public T? Get(string key) => _store.GetValueOrDefault(key);

    // Extra type param on a method of a generic class
    public TDerived? GetAs<TDerived>(string key) where TDerived : class, T
        => _store.GetValueOrDefault(key) as TDerived;
}

// Usage
var cache = new TypedCache<Animal>();     // T fixed as Animal at construction
cache.Set("dog", new Dog());
Dog? d = cache.GetAs<Dog>("dog");         // TDerived resolved per call

string? first = CollectionHelper.First(new[] { "a", "b" });  // T inferred as string
```

## Common Follow-up Questions

- How does the JIT generate code differently for `List<int>` (generic class) vs `Enumerable.ToList<int>()` (generic method)?
- Can you add a constraint on a generic method that contradicts the class-level constraint?
- When would you choose a generic interface over a generic class?
- How does covariance/contravariance affect generic method return types vs class-level type parameters?
- What happens when you call a generic method via reflection — how do you get the closed method?

## Common Mistakes / Pitfalls

- **Making the whole class generic when only one method needs T.** Forces all callers to specify the type at instantiation even if they only ever call that one method.
- **Duplicating constraints** across every method instead of promoting them to the class. If all methods need `where T : IComparable<T>`, it belongs on the class.
- **Adding extra class-level type parameters for method-local purposes.** `Converter<TSource, TDest>` forces both types at construction even if `TDest` only matters per call.
- **Forgetting that generic method type parameters are invisible in DI.** You cannot register `Func<T>` factory methods in the DI container as open generics — you must use a non-generic factory or a generic class.
- **Assuming generic method inference always works.** Return-type-only type parameters (`T Method<T>()`) cannot be inferred and must always be specified explicitly.

## References

- [Generic Methods — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/generic-methods)
- [Generic Classes — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/generic-classes)
- [Constraints on Type Parameters — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters)
- [See: generics-basics.md](./generics-basics.md)
- [See: generic-constraints.md](./generic-constraints.md)
