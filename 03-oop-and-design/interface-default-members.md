# Interface Default Members

**Category:** OOP & Design / OOP Fundamentals
**Difficulty:** 🔴 Senior
**Tags:** `interface`, `default-interface-members`, `C#8`, `traits`

## Question
> What are default interface members in C#, how do they help with versioning, how is the diamond problem handled, and what are their limitations compared to traits or abstract base classes?

## Short Answer
Default interface members let an interface provide a method body, which was introduced in C# 8 mainly to evolve interfaces without immediately breaking every implementation. They act a bit like traits or mixins because shared behavior can live in the interface, but they are more limited: interfaces still do not have instance state like base classes. Diamond conflicts are not resolved by “multiple inheritance magic”; if ambiguity matters, a more specific interface or the implementing type must provide the final implementation.

## Detailed Explanation
### What they are and why they were added
Before C# 8, adding a new member to a public interface was a breaking change because every implementer had to add that member. Default interface members (DIM) let the interface itself provide an implementation, so existing implementations can keep compiling while newer callers gain new behavior.

That makes DIM primarily a **versioning tool**. If you own a library and want to add a convenience method, logging hook, or composed operation, a default implementation can preserve compatibility better than forcing all consumers to update at once.

### How dispatch works and why this is not class inheritance
A default member lives on the interface contract, not on the class as an inherited instance method in the same way a base class member does. In practice, callers typically access the behavior through an interface-typed reference.

If the class provides its own implementation, that implementation wins. If not, the runtime can dispatch to the interface’s default body. This is different from classic OO inheritance where a base implementation becomes part of the class member set.

| Capability | Default interface member | Abstract base class |
| --- | --- | --- |
| Provide method body | Yes | Yes |
| Hold instance fields | No | Yes |
| Multiple inheritance of behavior | Limited | No |
| Primary purpose | Versioning/shared contract behavior | Reuse with state/template hooks |

### Diamond problem handling
C# avoids a lot of ambiguity by not treating default members as unrestricted multiple inheritance of implementation. If two interfaces provide the same member shape, there is no magical merge. The resolution strategy is explicit:

- a more specific derived interface can provide the chosen implementation;
- the implementing class can provide its own implementation;
- callers can invoke through a specific interface reference when appropriate.

That is why DIM feels “trait-like,” but not like full-blown mixins from some other languages.

> A common misconception is that default interface members make interfaces a replacement for abstract base classes. They do not: there is still no per-instance shared state, no constructor flow, and a much narrower reuse story.

### Good use cases and trade-offs
Good use cases include:

- evolving public library interfaces safely;
- small convenience methods built from existing required members;
- cross-cutting default behavior such as retries, formatting, or validation helpers.

Poor use cases include:

- large reusable behavior with shared state;
- complex lifecycle coordination;
- domains where explicit composition is clearer than hidden interface logic.

DIM can also make code harder to discover. A developer may inspect a class, not see a method, and forget that an interface provides it. Some mocking, reflection, and tooling scenarios can also be less obvious than normal class members.

### When not to use them
If behavior needs state, invariants, or protected hooks, prefer an abstract base class or composition. If you only want a helper function with no polymorphic value, an extension method is often simpler. Default interface members are best when the behavior is genuinely part of the contract and versioning matters.

## Code Example
```csharp
using System;

namespace OopAndDesign.InterfaceDefaultMembers;

public interface IRetryableCommand
{
    string Name { get; }
    void ExecuteCore();

    void Execute()
    {
        Console.WriteLine($"Starting {Name}");
        ExecuteCore();
        Console.WriteLine($"Finished {Name}");
    }
}

public interface ILeft
{
    void Reset() => Console.WriteLine("Left reset");
}

public interface IRight
{
    void Reset() => Console.WriteLine("Right reset");
}

public sealed class ImportCommand : IRetryableCommand, ILeft, IRight
{
    public string Name => "Import";

    public void ExecuteCore() => Console.WriteLine("Importing records...");

    public void Reset() => Console.WriteLine("Class resolved the diamond explicitly"); // Resolves ambiguity.
}

public static class Program
{
    public static void Main()
    {
        IRetryableCommand command = new ImportCommand();
        command.Execute(); // Uses default interface implementation.

        var import = new ImportCommand();
        import.Reset();
    }
}
```

## Common Follow-up Questions
- Why were default interface members added to C# in the first place?
- How are they different from extension methods?
- When would an abstract base class still be the better design?
- How is ambiguity handled if two interfaces define the same default member?
- Can default interface members access instance state directly?
- How do default interface members affect public API versioning?

## Common Mistakes / Pitfalls
- Treating DIM as a general replacement for inheritance or composition.
- Putting too much business logic into interfaces and hiding behavior from class readers.
- Forgetting that interfaces still cannot own normal instance fields.
- Assuming callers can always invoke the default member through the concrete class type.
- Using DIM when an extension method would be simpler and more discoverable.

## References
- [Safely update interfaces using default interface methods](https://learn.microsoft.com/dotnet/csharp/advanced-topics/interface-implementation/default-interface-methods-versions)
- [interface (C# reference)](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/interface)
- [Explicit Interface Implementation (C# Programming Guide)](https://learn.microsoft.com/dotnet/csharp/programming-guide/interfaces/explicit-interface-implementation)
