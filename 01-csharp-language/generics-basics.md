# Generics Basics

**Category:** C# / Generics
**Difficulty:** 🟢 Junior
**Tags:** `generics`, `type-parameters`, `type-safety`, `reusability`, `JIT`, `boxing`

## Question

> What are generics in C#? Why do they exist, and how do they differ from using `object`?

Additional phrasings:
- *"How does the C# compiler and runtime handle generic types?"*
- *"What is the difference between a generic class and a generic method?"*

## Short Answer

Generics allow you to write type-safe, reusable code by parameterizing types and methods with one or more type parameters. Rather than working with `object` (which requires casting and causes boxing for value types), a generic `List<T>` works with any type while the compiler enforces type safety at compile time. At runtime, the JIT generates specialized code for each value-type instantiation (e.g., `List<int>` gets native int code), and shares a single implementation for all reference-type instantiations — giving both type safety and performance.

## Detailed Explanation

### The Problem Generics Solve

Before generics (.NET 1.x), reusable collections used `object`:

```csharp
// Pre-generics
ArrayList list = new ArrayList();
list.Add(42);        // boxes int → heap allocation
list.Add("hello");   // no compile-time type check!
int n = (int)list[0]; // cast required, can throw at runtime
```

Problems:
- **No type safety.** You could add any type and discover errors at runtime.
- **Boxing/unboxing overhead.** Value types box to `object` on insertion and unbox on retrieval.
- **Casting everywhere.** Every read requires an explicit cast.

Generics solve all three:

```csharp
List<int> list = new List<int>();
list.Add(42);     // no boxing
// list.Add("hello"); ❌ compile error — type-safe
int n = list[0];  // no cast needed
```

### Generic Type Parameters

A **type parameter** is a placeholder substituted at compile time (or JIT time for value types):

```csharp
class Stack<T>           // T is the type parameter
{
    private T[] _items = new T[4];
    private int _top = 0;

    public void Push(T item) => _items[_top++] = item;
    public T Pop() => _items[--_top];
}

var intStack = new Stack<int>();    // T = int
var strStack = new Stack<string>(); // T = string
```

Naming conventions:
- Single type parameter: `T` (type), `K` (key), `V` (value), `TResult`, `TSource`.
- Multiple parameters: `TKey`, `TValue`, `TIn`, `TOut`.

### Generic Methods

Type parameters can also be scoped to a single method:

```csharp
static T Max<T>(T a, T b) where T : IComparable<T>
    => a.CompareTo(b) >= 0 ? a : b;

int maxInt  = Max(3, 7);          // T inferred as int
string maxStr = Max("apple", "banana"); // T inferred as string
```

The compiler infers `T` from the argument types — you rarely need `Max<int>(3, 7)` explicitly.

### How the Runtime Handles Generics

**Reference types:** all reference-type instantiations (`List<string>`, `List<Customer>`, `List<object>`) share one JIT-compiled code body. The JIT replaces `T` with a pointer-sized slot (all references are the same size).

**Value types:** each value-type instantiation gets its **own** JIT-compiled code body. `List<int>` and `List<double>` have separate native code because `int` and `double` have different sizes and operations.

This is why:
- Generic collections like `List<int>` avoid boxing entirely.
- Reflection on generic types distinguishes `List<int>` from `List<string>` as distinct `Type` objects.

### Open vs Closed Generic Types

- **Open generic type:** `List<T>` — the type parameter is not specified. Cannot be instantiated.
- **Closed generic type:** `List<int>` — the type parameter is filled in. Can be instantiated.

At runtime: `typeof(List<>)` is the open generic type definition; `typeof(List<int>)` is a closed constructed type.

### Generic Classes vs Generic Methods vs Generic Interfaces

| Feature | Example | Use case |
|---|---|---|
| Generic class | `class Repo<T>` | Type-parameterized containers, services |
| Generic struct | `struct Pair<T1, T2>` | Value-type pairs, ranges |
| Generic interface | `interface IRepository<T>` | Abstraction over entity type |
| Generic method | `T Parse<T>(string s)` | Type-specific utility methods |
| Generic delegate | `Func<T, TResult>` | Type-safe callbacks |

[See: generic-constraints.md](./generic-constraints.md) for constraining `T` with `where` clauses.
[See: covariance-and-contravariance.md](./covariance-and-contravariance.md) for `in`/`out` variance on generic interfaces.

## Code Example

```csharp
// === Generic class: type-safe stack ===
class Stack<T>
{
    private readonly List<T> _items = [];

    public void Push(T item) => _items.Add(item);
    public T Pop()
    {
        if (_items.Count == 0) throw new InvalidOperationException("Stack is empty");
        T top = _items[^1];
        _items.RemoveAt(_items.Count - 1);
        return top;
    }
    public T Peek() => _items.Count > 0 ? _items[^1] : throw new InvalidOperationException();
    public int Count => _items.Count;
}

var intStack = new Stack<int>();
intStack.Push(1); intStack.Push(2); intStack.Push(3);
Console.WriteLine(intStack.Pop()); // 3 — no boxing, no casting

var strStack = new Stack<string>();
strStack.Push("hello");
Console.WriteLine(strStack.Peek()); // "hello"

// === Generic method: inferred type parameter ===
static (T Min, T Max) MinMax<T>(IEnumerable<T> source) where T : IComparable<T>
{
    T? min = default, max = default;
    bool first = true;
    foreach (T item in source)
    {
        if (first || item.CompareTo(min!) < 0) min = item;
        if (first || item.CompareTo(max!) > 0) max = item;
        first = false;
    }
    return (min!, max!);
}

var (lo, hi) = MinMax(new[] { 3, 1, 4, 1, 5, 9, 2, 6 });
Console.WriteLine($"Min: {lo}, Max: {hi}"); // Min: 1, Max: 9

// ✅ Works for strings too — same code, different T
var (first, last) = MinMax(new[] { "banana", "apple", "cherry" });
Console.WriteLine($"First: {first}, Last: {last}"); // apple, cherry

// === Generic interface ===
interface IRepository<T> where T : class
{
    T? GetById(int id);
    void Save(T entity);
}

class InMemoryUserRepo : IRepository<User>
{
    private readonly Dictionary<int, User> _store = [];
    public User? GetById(int id) => _store.TryGetValue(id, out var u) ? u : null;
    public void Save(User user) => _store[user.Id] = user;
}

record User(int Id, string Name);

var repo = new InMemoryUserRepo();
repo.Save(new User(1, "Alice"));
Console.WriteLine(repo.GetById(1)?.Name); // Alice

// === Generic delegate (Func / Action) ===
Func<int, int, int> add = (a, b) => a + b;
Console.WriteLine(add(3, 4)); // 7

// Predicate<T> is shorthand for Func<T, bool>
Predicate<string> isLong = s => s.Length > 5;
Console.WriteLine(isLong("hi"));       // false
Console.WriteLine(isLong("hello world")); // true
```

## Common Follow-up Questions

- How does the JIT handle value-type specialization for generic types — is there a separate native code body for each?
- What are generic constraints and when do you need them?
- How does `default(T)` work in generic methods?
- Can you use `typeof(T)` inside a generic method, and what does it return?
- What is the difference between `List<T>` and `ArrayList` in terms of boxing?
- How do you implement a generic method that returns `null` for reference types and `default(T)` for value types?

## Common Mistakes / Pitfalls

- **Using `object` when a generic type parameter is more appropriate.** Writing `void Process(object item)` loses type safety; `void Process<T>(T item)` preserves it and avoids boxing for value types.
- **Forgetting to add constraints when the type parameter must support certain operations.** `T a + b` doesn't compile without `where T : INumber<T>` (C# 11+) or without constraints permitting `+`. The compiler rejects operations on unconstrained `T`.
- **Assuming one JIT body for value types.** Each unique value-type instantiation (`List<int>`, `List<double>`, `List<MyStruct>`) produces separate JIT code. For extremely generic code, this can cause JIT code size bloat — a concern mainly for ahead-of-time scenarios.
- **Confusing the open generic type `typeof(List<>)` with a closed type.** Using reflection on generic types requires distinguishing between open and closed forms.
- **Naming type parameters poorly.** Single-letter `T`, `K`, `V` are fine for simple generic containers, but `TEntity`, `TResult`, `TSource` make code more readable for multi-parameter or complex generics.

## References

- [Generics — C# programming guide](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/generics)
- [Generic type parameters — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/generic-type-parameters)
- [Generics in the runtime — .NET documentation](https://learn.microsoft.com/dotnet/standard/generics/covariance-and-contravariance)
- [Generic classes — C# guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/generic-classes)
