# Flyweight Pattern

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🔴 Senior
**Tags:** `flyweight`, `structural`, `memory`, `performance`, `string-interning`

## Question
> What is the Flyweight pattern, how do intrinsic and extrinsic state work, and when would you use it for memory optimization in .NET?

## Short Answer
The Flyweight pattern reduces memory usage by sharing immutable state that many objects have in common. Shared data is called intrinsic state, while per-instance data supplied from the outside is extrinsic state. In .NET, Flyweight is useful when you have huge numbers of similar objects and memory pressure matters more than having each object fully self-contained.

## Detailed Explanation
### What Flyweight solves
Flyweight is a structural optimization pattern for cases where you have many logically separate objects that repeat the same data over and over. Instead of storing all fields on every instance, you extract the shared portion into reusable flyweight objects and pass the unique portion separately.

A common example is rendering many trees in a game. The species name, texture, and color are shared; position, height, and age are unique per tree. If you duplicate the shared fields thousands of times, memory usage grows unnecessarily.

### Intrinsic vs extrinsic state
The distinction is the heart of the pattern:

| State type | Where it lives | Characteristics | Example |
| --- | --- | --- | --- |
| Intrinsic | Inside the flyweight | Shared, reusable, usually immutable | Tree texture, species, icon glyph |
| Extrinsic | Supplied by the caller or context | Unique per use, often small | Coordinates, quantity, selection state |

Intrinsic state must be safe to share. In practice, that usually means immutable objects. Extrinsic state is provided on each operation or stored in a lightweight companion structure.

### How it works internally
A factory or cache usually manages flyweights. When the client asks for a flyweight representing a specific intrinsic state, the factory returns an existing instance if one already exists. Many logical objects can therefore point at the same shared instance.

The .NET analogy most people know is string interning. Identical interned strings can share one underlying instance. Flyweight is similar in spirit, though you apply it intentionally in your own model.

Another useful detail in .NET is that extrinsic state can sometimes be modeled as a compact `readonly record struct` to reduce allocation overhead. That does not automatically make things faster, but it can help when the state is small and copied intentionally.

> Warning: do not put mutable shared state inside a flyweight unless you are very sure about synchronization and semantics. Shared mutability easily turns memory optimization into a correctness bug.

### Why it matters
Flyweight matters when scale changes the economics of the design. With a few dozen objects, clarity is usually more important than micro-optimization. With hundreds of thousands or millions of similar entries, duplicated state becomes expensive in memory, GC pressure, cache locality, and startup time.

This pattern is especially relevant in UI rendering, game entities, parsers, large in-memory catalogs, and any workload that creates many repetitive objects.

### Trade-offs and when not to use it
The pattern improves memory efficiency, but it increases conceptual complexity because state is now split. Callers must remember to provide extrinsic state correctly. That can make APIs less intuitive.

Flyweight is also not a free win. Dictionary lookups, factory management, and additional indirection can offset the gains if the object count is low or the shared state is tiny. Measure before optimizing.

Do not use Flyweight if your main problem is database round-trips or algorithmic complexity. It solves memory duplication, not everything performance-related.

## Code Example
```csharp
namespace OopDesignSamples;

public sealed record TreeType(string Species, string TexturePath, ConsoleColor Color);

public readonly record struct TreePlacement(int X, int Y, int Height);

public sealed class TreeTypeFactory
{
    private readonly Dictionary<string, TreeType> _cache = [];

    public TreeType GetOrCreate(string species, string texturePath, ConsoleColor color)
    {
        var key = $"{species}|{texturePath}|{color}";

        if (_cache.TryGetValue(key, out var existing))
        {
            return existing; // Reuse shared intrinsic state.
        }

        var created = new TreeType(species, texturePath, color);
        _cache[key] = created;
        return created;
    }
}

public sealed class Forest(TreeTypeFactory factory)
{
    private readonly List<(TreeType Type, TreePlacement Placement)> _trees = [];
    private readonly TreeTypeFactory _factory = factory;

    public void Plant(string species, string texturePath, ConsoleColor color, TreePlacement placement)
    {
        var type = _factory.GetOrCreate(species, texturePath, color);
        _trees.Add((type, placement)); // Store only shared type + small extrinsic state.
    }

    public void Render()
    {
        foreach (var (type, placement) in _trees)
        {
            Console.ForegroundColor = type.Color;
            Console.WriteLine($"{type.Species} at ({placement.X}, {placement.Y}), height {placement.Height}");
        }

        Console.ResetColor();
    }
}

public static class Program
{
    public static void Main()
    {
        var forest = new Forest(new TreeTypeFactory());
        forest.Plant("Oak", "oak.png", ConsoleColor.Green, new TreePlacement(10, 20, 5));
        forest.Plant("Oak", "oak.png", ConsoleColor.Green, new TreePlacement(15, 25, 6));
        forest.Plant("Pine", "pine.png", ConsoleColor.DarkGreen, new TreePlacement(30, 40, 9));

        forest.Render();
    }
}
```

## Common Follow-up Questions
- How is Flyweight different from caching or object pooling?
- What kinds of state should be intrinsic versus extrinsic?
- How does string interning relate to Flyweight in .NET?
- When would a `readonly struct` help in a flyweight design?
- What measurements would justify introducing Flyweight?

## Common Mistakes / Pitfalls
- Sharing mutable state and accidentally coupling unrelated objects.
- Introducing Flyweight before proving that memory usage is actually a bottleneck.
- Moving too much state out of the object, making the API awkward and error-prone.
- Confusing Flyweight with object pooling; pooled objects are reused over time, while flyweights are shared concurrently.
- Assuming structs are always faster than classes regardless of size or copying cost.

## References
- [Flyweight](https://refactoring.guru/design-patterns/flyweight)
- [String.Intern Method](https://learn.microsoft.com/en-us/dotnet/api/system.string.intern)
- [Structure types](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/struct)
