# Covariance and Contravariance

**Category:** C# / Generics
**Difficulty:** 🔴 Senior
**Tags:** `covariance`, `contravariance`, `in`, `out`, `generic-interfaces`, `generic-delegates`, `array-covariance`, `variance`

## Question

> What are covariance and contravariance in C# generics? What do the `in` and `out` keywords do on generic interfaces?

Additional phrasings:
- *"Why can you assign `IEnumerable<string>` to `IEnumerable<object>`, but not `List<string>` to `List<object>`?"*
- *"What is array covariance, why is it a design mistake, and what runtime exception can it cause?"*

## Short Answer

**Covariance** (`out T`) allows a generic interface to be used with a more derived type than originally specified — `IEnumerable<string>` can be assigned to `IEnumerable<object>` because `string` is a subtype of `object`. **Contravariance** (`in T`) is the reverse — a generic interface using a less derived type can be substituted — `Action<object>` can be assigned to `Action<string>` because a method accepting `object` can handle any `string`. These apply only to interfaces and delegates, not to classes. **Array covariance** is a legacy language "feature" that allows `string[]` to be assigned to `object[]` but can throw `ArrayTypeMismatchException` at runtime when writing to the array.

## Detailed Explanation

### The Motivation

Without variance, generics are **invariant**: `List<string>` is not a subtype of `List<object>`, even though `string` is a subtype of `object`. This is correct from a type safety standpoint — if `List<string>` were assignable to `List<object>`, you could do:

```csharp
List<string> strings = new List<string>();
List<object> objects = strings; // hypothetically allowed
objects.Add(42); // 42 is an object but not a string — corrupts strings!
string s = strings[0]; // runtime ClassCastException
```

However, for **read-only** uses (output only), covariance is safe. And for **write-only** uses (input only), contravariance is safe.

### Covariance: `out T`

`out T` marks a type parameter as covariant — it only appears in **output positions** (return types, read-only properties). This guarantees you only read `T` values, never write them.

```csharp
interface IProducer<out T>
{
    T Produce();       // T in output position ✅
    // void Consume(T t); ❌ T in input position — would violate covariance
}
```

With `out T`, if `B : A`, then `IProducer<B>` is assignable to `IProducer<A>`:

```csharp
IProducer<string> stringProducer = ...;
IProducer<object> objectProducer = stringProducer; // ✅ safe — covariant
```

**Standard library examples:**
- `IEnumerable<out T>` — read-only iteration; `IEnumerable<string>` → `IEnumerable<object>` ✅
- `IReadOnlyList<out T>` — read-only indexed access
- `IReadOnlyCollection<out T>`
- `Func<out TResult>` — return type only
- `Task<out TResult>` (C# 5+)

### Contravariance: `in T`

`in T` marks a type parameter as contravariant — it only appears in **input positions** (method parameters). This guarantees you only write `T` values, never read them back.

```csharp
interface IConsumer<in T>
{
    void Consume(T item); // T in input position ✅
    // T Produce();       ❌ T in output position — violates contravariance
}
```

With `in T`, if `B : A`, then `IConsumer<A>` is assignable to `IConsumer<B>` (reversed!):

```csharp
IConsumer<object> objectConsumer = ...; // can consume any object
IConsumer<string> stringConsumer = objectConsumer; // ✅ safe — contravariant
// A consumer of object can certainly consume a string
```

**Standard library examples:**
- `IComparer<in T>` — comparing T values
- `IEqualityComparer<in T>` — equality check
- `Action<in T>` — parameter only; `Action<object>` → `Action<string>` ✅

### Invariance: No `in`/`out`

`IList<T>` and `List<T>` are **invariant** because `T` appears in both input and output positions (`Add(T)` = input; `this[int] get` = output). Neither covariance nor contravariance can be applied safely.

### The Rule of Thumb

- **Covariant (`out`):** producer — the generic type **returns** / **gives you** T values. "If I can produce cats, I can produce animals."
- **Contravariant (`in`):** consumer — the generic type **accepts** / **takes** T values. "If I can handle animals, I can handle cats."

### `Func<TIn, TOut>` and Combined Variance

`Func<T, TResult>` has both: `in T` (parameter — contravariant) and `out TResult` (return — covariant):

```csharp
Func<object, string> func = o => o.ToString()!;

// Covariant in TResult: Func<X, string> → Func<X, object>
Func<object, object> func2 = func; // ✅

// Contravariant in T: Func<object, X> → Func<string, X>
Func<string, string> func3 = func; // ✅
```

### Array Covariance — The Legacy Mistake

C# arrays (like Java arrays) are covariant: `string[]` can be assigned to `object[]`. This was a design decision for pre-generics compatibility. **It is unsound:**

```csharp
string[] strings = ["hello", "world"];
object[] objects = strings;      // ✅ compiles — array covariance
objects[0] = 42;                  // ❌ ArrayTypeMismatchException at RUNTIME
```

The CLR performs a runtime type check on every array write to detect this. It's a performance overhead paid for every array element assignment. This is one reason to prefer generic collections.

> **Never rely on array covariance.** Use `IEnumerable<T>` or `IReadOnlyList<T>` (which have proper, safe variance via `out T`) instead.

## Code Example

```csharp
// === Covariance: IEnumerable<out T> ===
IEnumerable<string> strings = ["hello", "world"];
IEnumerable<object> objects = strings; // ✅ covariant assignment

foreach (object o in objects)
    Console.WriteLine(o.GetType().Name); // String, String

// === Contravariance: IComparer<in T> ===
IComparer<object> objectComparer = Comparer<object>.Default;
IComparer<string> stringComparer = objectComparer; // ✅ contravariant

Console.WriteLine(stringComparer.Compare("a", "b")); // -1

// === Func variance ===
Func<object, string> toStr = o => o?.ToString() ?? "null";

Func<object, object>  covariantResult = toStr;  // ✅ string is-a object (covariant TResult)
Func<string, string>  contravariantIn = toStr;  // ✅ object can handle string (contravariant T)

Console.WriteLine(covariantResult(42));  // "42"
Console.WriteLine(contravariantIn("hi")); // "hi"

// === Custom covariant interface ===
interface IReader<out T>
{
    T Read();
}

class StringReader(string value) : IReader<string>
{
    public string Read() => value;
}

IReader<string> strReader = new StringReader("test");
IReader<object> objReader = strReader; // ✅ covariant
Console.WriteLine(objReader.Read()); // "test"

// === Custom contravariant interface ===
interface IWriter<in T>
{
    void Write(T value);
}

class ConsoleWriter<T> : IWriter<T>
{
    public void Write(T value) => Console.WriteLine(value);
}

IWriter<object> objWriter = new ConsoleWriter<object>();
IWriter<string> strWriter = objWriter; // ✅ contravariant
strWriter.Write("hello"); // "hello"

// === Array covariance: dangerous legacy ===
string[] arr = ["a", "b"];
object[] asObjects = arr; // compiles (array covariance)
try
{
    asObjects[0] = 123; // ❌ ArrayTypeMismatchException at runtime
}
catch (ArrayTypeMismatchException ex)
{
    Console.WriteLine($"Caught: {ex.GetType().Name}");
}

// Safe alternative: use IReadOnlyList<T> (covariant, no write)
IReadOnlyList<string> safeStrings = arr;
IReadOnlyList<object> safeObjects = safeStrings; // ✅ safe — read-only
```

## Common Follow-up Questions

- Why are `List<T>` and `IList<T>` invariant while `IEnumerable<T>` is covariant?
- What is **definition-site variance** (C#) vs **use-site variance** (Java wildcards)?
- How does variance interact with `null` and nullable reference types?
- Can a generic class (not just an interface/delegate) be declared covariant or contravariant?
- What is the runtime cost of array covariance type checks?
- How do `in` and `out` on generic type parameters differ from `in` and `out` parameter modifiers?

## Common Mistakes / Pitfalls

- **Confusing `out T` (covariance) with `out` parameter modifier.** These are completely unrelated — `out T` on a generic interface declaration is variance; `out` on a method parameter is a ref-category modifier.
- **Trying to declare variance on a generic class.** Only interfaces and delegates support `in`/`out` variance. `class Foo<out T>` is a compile error.
- **Using array covariance for "convenience."** Storing a derived array as a base-type array and then assigning to it will crash at runtime with `ArrayTypeMismatchException`. Use covariant interfaces (`IReadOnlyList<T>`) or generics instead.
- **Expecting `IList<string>` to be assignable to `IList<object>`.** `IList<T>` is invariant because `T` appears in both input (`Add(T)`) and output (`this[int]`). Use `IReadOnlyList<T>` (covariant) when you only need to read.
- **Misapplying the direction.** Covariance follows the inheritance direction (sub → base): `IEnumerable<Derived>` → `IEnumerable<Base>`. Contravariance is reversed: `Action<Base>` → `Action<Derived>`. The mnemonic: producers are covariant (output), consumers are contravariant (input).

## References

- [Covariance and contravariance in generics — .NET docs](https://learn.microsoft.com/dotnet/standard/generics/covariance-and-contravariance)
- [out (generic modifier) — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/out-generic-modifier)
- [in (generic modifier) — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/in-generic-modifier)
- [Creating variant generic interfaces — C# guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/concepts/covariance-contravariance/creating-variant-generic-interfaces)
- [Eric Lippert — "Covariance and Contravariance" series](https://ericlippert.com/2007/10/16/covariance-and-contravariance-in-c-part-one/) (verify URL)
