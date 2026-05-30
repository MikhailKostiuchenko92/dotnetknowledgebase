# Static Constructor Timing

**Category:** C# / Misc Language Mechanics
**Difficulty:** Middle
**Tags:** `static-constructor`, `beforefieldinit`, `type-initialization`, `thread-safety`, `clr`

## Question

> When does a static constructor run in C#, and what does `beforefieldinit` change?

Also asked as:
- "Why does adding an explicit static constructor remove `beforefieldinit` behavior?"
- "Is static type initialization thread-safe in .NET?"
- "Can I rely on a static field initializer running at the exact first field access?"

## Short Answer

A static constructor runs automatically once per type, before the type is first used in a way that requires initialization. If a type has no explicit static constructor, the CLR may mark it with `beforefieldinit`, which allows earlier initialization than you might expect. In .NET 8/9, the runtime still guarantees that type initialization is thread-safe, but you should not write code that depends on overly precise timing.

## Detailed Explanation

### What actually triggers type initialization

Type initialization happens when the runtime decides a type must be initialized before use. Typical triggers are reading a static field, calling a static member, or creating an instance when the type requires initialization.

| Type shape | Timing model | What to remember |
|---|---|---|
| Static field initializers only | Often `beforefieldinit` | Runtime may initialize earlier than the exact first read |
| Explicit static constructor (`static MyType()`) | Stricter initialization point | Runtime must run it immediately before first required use |
| Already initialized type | No repeat execution | Static constructor runs only once per AppDomain / process context |

This is the same family of behavior introduced in [constructors-chaining-and-static.md](./constructors-chaining-and-static.md), but here the focus is the timing contract rather than constructor chaining.

### What `beforefieldinit` changes

If you do **not** declare an explicit static constructor, the CLR can mark the type as `beforefieldinit`. That does **not** mean initialization is random; it means the runtime has flexibility to run the type initializer any time before the type is first used in a way that needs initialized static state.

Once you add an explicit static constructor, that flexibility goes away. The runtime must delay execution until just before first required use.

> **Warning:** Do not depend on a `beforefieldinit` type initializing at the exact first static field access. If the timing matters, use an explicit static constructor or a `Lazy<T>` wrapper.

### Thread-safety and failure behavior

The CLR guarantees that static constructor execution is thread-safe. If several threads touch the type at the same time, one thread runs initialization and the others wait.

That guarantee is about **one-time execution**, not about what you do inside the constructor. If the constructor performs blocking I/O, takes locks, or throws, you can still create startup delays or a `TypeInitializationException` that poisons the type for future use.

| Concern | Behavior |
|---|---|
| Multiple concurrent callers | One thread initializes; others wait |
| Normal completion | Type becomes usable for all threads |
| Exception in static constructor | Future uses usually fail with `TypeInitializationException` |
| Heavy work inside static constructor | Increases first-use latency and debugging complexity |

### Practical guidance for .NET 8/9 code

Keep static constructors small, deterministic, and side-effect free when possible. Prefer simple `static readonly` initialization for fixed values, as discussed in [readonly-vs-const.md](./readonly-vs-const.md). If you need deferred expensive work, `Lazy<T>` is often easier to reason about than a heavy static constructor.

## Code Example

```csharp
using System;
using System.Threading.Tasks;

Console.WriteLine($"Start: {DateTime.UtcNow:HH:mm:ss.fff}");

Console.WriteLine(StrictCache.Value);  // Explicit static constructor runs immediately before first required use.
Console.WriteLine(RelaxedCache.Value); // No explicit static constructor; timing is less precise.

Parallel.For(0, 3, _ =>
{
    Console.WriteLine(StrictCache.Value); // All threads observe the same initialized value.
});

public static class StrictCache
{
    static StrictCache()
    {
        Console.WriteLine("StrictCache .cctor running once.");
        Value = $"Strict cache initialized at {DateTime.UtcNow:HH:mm:ss.fff}";
    }

    public static string Value { get; }
}

public static class RelaxedCache
{
    public static readonly string Value = CreateValue();

    private static string CreateValue()
    {
        Console.WriteLine("RelaxedCache field initializer running.");
        return $"Relaxed cache initialized at {DateTime.UtcNow:HH:mm:ss.fff}";
    }
}
```

## Common Follow-up Questions

- What kinds of type usage trigger static initialization?
- Why does an explicit static constructor remove `beforefieldinit` freedom?
- What happens if a static constructor throws an exception?
- Why is static constructor execution considered thread-safe?
- When should you prefer `Lazy<T>` over a static constructor?

## Common Mistakes / Pitfalls

- Assuming a type without an explicit static constructor initializes at one exact, observable moment.
- Doing network calls, file I/O, or long-running work inside a static constructor.
- Taking locks in a static constructor and creating deadlock risk during startup.
- Forgetting that a thrown static constructor can make the type unusable for the rest of the process.
- Using a static constructor when a simple `static readonly` field would be clearer.

## References

- [Static Constructors - C# Programming Guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/static-constructors)
- [Instance constructors - C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/constructors)
- [See: constructors-chaining-and-static.md](./constructors-chaining-and-static.md)
- [See: readonly-vs-const.md](./readonly-vs-const.md)
- [See: static-classes-and-members.md](./static-classes-and-members.md)
