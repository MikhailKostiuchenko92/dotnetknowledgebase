# Composite Pattern

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🟡 Middle
**Tags:** `composite`, `structural`, `tree`, `recursion`

## Question
> What is the Composite pattern, and how would you use it to model tree structures in C#? Can you show the roles of Component, Leaf, and Composite?

## Short Answer
The Composite pattern lets you treat individual objects and groups of objects uniformly through a common interface. It is ideal for tree structures such as file systems, UI hierarchies, menu trees, and organization charts. In C#, a common approach is to expose recursive traversal with `IEnumerable<T>` so clients can walk the tree without caring whether a node is a leaf or a composite.

## Detailed Explanation
### What Composite solves
Composite addresses the problem of working with hierarchical data where some nodes are simple items and others are containers. Without Composite, client code often ends up full of `if` statements checking whether an object is a leaf or a collection.

With Composite, both single objects and groups implement the same contract. That allows the client to call the same operations on a single node or a whole subtree.

### Core roles in the pattern
The classic structure has three roles:

| Role | Responsibility | Example |
| --- | --- | --- |
| Component | Common interface for all nodes | `INode` |
| Leaf | Represents an indivisible item | File, menu item, employee |
| Composite | Contains children and forwards operations recursively | Folder, menu group, department |

The power of the pattern comes from recursion. A composite contains components, which can themselves be leaves or composites.

### How it works internally
A composite usually stores a collection of child components. When the client calls an operation such as `Render`, `CalculateSize`, or `Traverse`, the composite performs work for itself and then delegates recursively to its children.

`IEnumerable<T>` is a natural fit in C#. A component can expose a traversal method using `yield return`, and the composite can recursively flatten the tree. That keeps traversal logic inside the model instead of scattering it across callers.

> Warning: if your structure can contain cycles instead of a strict tree, naive recursive traversal can cause infinite loops or stack overflows. Composite assumes hierarchical relationships, not arbitrary graphs.

### Why it matters
Composite improves consistency and reduces branching in callers. A search function can accept an `INode` and work whether it receives a single file or an entire folder tree. It also makes it easier to add new operations because clients already think in terms of a unified node abstraction.

This pattern is common in UI component trees, expression trees, Roslyn syntax nodes, and domain models with part-whole hierarchies.

### Trade-offs and when not to use it
Composite can make the interface too broad if leaves are forced to implement meaningless child-management methods. A cleaner approach in C# is often to keep the shared interface focused on operations that make sense for all nodes and put child mutation only on composite types.

Another trade-off is performance. Recursive traversal over large trees can be expensive, and deep recursion may risk stack pressure. In very large structures, an iterative traversal or cached aggregate values may be better.

Do not use Composite when the domain is not truly hierarchical. If relationships are graph-like or the distinction between item and container does not matter, a simpler model may be clearer.

## Code Example
```csharp
namespace OopDesignSamples;

public interface INode
{
    string Name { get; }
    IEnumerable<INode> Traverse();
}

public sealed class FileLeaf(string name) : INode
{
    public string Name { get; } = name;

    public IEnumerable<INode> Traverse()
    {
        yield return this; // A leaf only yields itself.
    }
}

public sealed class Folder(string name) : INode
{
    private readonly List<INode> _children = [];

    public string Name { get; } = name;

    public void Add(INode child) => _children.Add(child);

    public IEnumerable<INode> Traverse()
    {
        yield return this;

        foreach (var child in _children)
        {
            foreach (var node in child.Traverse())
            {
                yield return node; // Recursive depth-first traversal.
            }
        }
    }
}

public static class Program
{
    public static void Main()
    {
        var root = new Folder("root");
        var docs = new Folder("docs");
        docs.Add(new FileLeaf("resume.pdf"));
        docs.Add(new FileLeaf("notes.txt"));
        root.Add(docs);
        root.Add(new FileLeaf("todo.md"));

        foreach (var node in root.Traverse())
        {
            Console.WriteLine(node.Name);
        }
    }
}
```

## Common Follow-up Questions
- How is Composite different from a normal collection of children?
- Should child-management methods belong on the Component interface?
- What traversal order would you choose: depth-first or breadth-first?
- How would you avoid recursion issues on very deep trees?
- How is Composite different from graph modeling?

## Common Mistakes / Pitfalls
- Putting `Add` and `Remove` on the common interface even when leaves cannot support them meaningfully.
- Forgetting to guard against cycles when the data source is not a strict tree.
- Doing expensive recursive recalculation on every call instead of caching when appropriate.
- Exposing mutable child collections directly, breaking invariants.
- Mixing tree-navigation logic into client code instead of encapsulating traversal.

## References
- [Composite](https://refactoring.guru/design-patterns/composite)
- [IEnumerable<T> Interface](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.ienumerable-1)
- [yield statement](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/yield)
