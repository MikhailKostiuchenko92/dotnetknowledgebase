# Interface Default Implementations

**Category:** C# / OOP in C#
**Difficulty:** Senior
**Tags:** `interfaces`, `default-interface-methods`, `versioning`, `diamond-problem`, `C# 8+`

## Question

> What are default interface implementations in C#, what members are allowed, and what problems do they solve?

Also asked as:
- "How do default interface methods help with interface versioning?"
- "What happens when multiple interfaces provide competing default implementations?"

## Short Answer

Default interface implementations let an interface provide method bodies and certain other members, introduced in C# 8 and available in modern .NET. Their main value is versioning: you can add a member to an interface without instantly breaking every existing implementation. They are useful, but they come with trade-offs around dispatch rules, discoverability, diamond-style conflicts, and the fact that interfaces still do not own normal instance state.

## Detailed Explanation

### What the Feature Is For

Historically, adding a new member to an interface was a breaking change because every implementation had to add it immediately. Default interface implementations were added mainly to improve **versioning** of libraries and frameworks.

An interface can now provide a body for some members, allowing existing implementers to continue working while newer consumers can call the new member.

This narrows the gap with abstract classes, but it does not eliminate it. The feature is about compatibility and shared contract evolution more than rich inheritance.

### What Members Are Allowed

Modern interfaces can contain:
- Abstract member declarations.
- Default implementations for instance methods.
- Static members.
- Private helper members used by default implementations.
- Static abstract members in newer C# scenarios (for generic math and similar patterns).

Interfaces still do **not** have normal instance fields the way classes do, so they cannot keep per-instance mutable state.

| Member kind | Interface support |
|---|---|
| Abstract method/property/event/indexer | Yes |
| Default method body | Yes |
| Private helper method | Yes |
| Static member | Yes |
| Instance field | No |
| Constructor-enforced instance state | No |

### Dispatch Rules Matter

One subtle point is dispatch. A default implementation lives on the interface contract, not as a normal inherited method copied into the class. In practice, this means calls often matter most when made through an interface reference.

If the implementing class provides its own public implementation, that implementation wins. If it does not, the interface default can be used through interface dispatch.

This is one reason the feature can feel less obvious than abstract-class inheritance. The behavior is correct, but sometimes less discoverable for developers reading only the concrete class.

### Versioning Benefit

Suppose library v1 exposes:

```csharp
public interface IRetryPolicy
{
    bool ShouldRetry(int attempt);
}
```

In v2, the author wants to add logging or delay calculation. Without default implementations, every implementer would break. With them, the author can add:

```csharp
TimeSpan GetDelay(int attempt) => TimeSpan.FromMilliseconds(attempt * 100);
```

That is the main benefit: interface evolution without immediate source breaks for all consumers.

> **Tip:** Think of default interface implementations primarily as a compatibility/versioning tool. If you start using them as your main stateful inheritance mechanism, you are probably pushing the feature beyond its sweet spot.

### Diamond-Style Conflicts

A common interview topic is the diamond problem. In C#, if multiple interfaces provide competing default implementations for the same member shape, the implementing type may need to disambiguate explicitly.

General guidance:
- A class member implementation beats interface defaults.
- More specific interface implementations can beat less specific ones in inheritance chains.
- If the compiler cannot resolve the conflict cleanly, the implementing class must provide its own implementation or explicit interface implementations.

So C# does not "magically" merge two defaults. You must make the intent explicit.

### Pitfalls and Design Trade-Offs

Default interface implementations can be useful, but there are real downsides:
- They can hide behavior inside interfaces, reducing discoverability.
- They can blur the boundary between contract and implementation.
- They do not solve shared instance-state needs.
- They can complicate mental models for dispatch and multiple-interface conflicts.
- Overuse can make public APIs harder to reason about.

For many business applications, plain interfaces plus extension methods or abstract helper classes are still simpler. Use default implementations where versioning pressure justifies the extra complexity.

See also [abstract-class-vs-interface.md](./abstract-class-vs-interface.md).

## Code Example

```csharp
using System;
using System.Collections.Generic;

ICache cache = new MemoryCache();
cache.Set("user:42", "Alice");
Console.WriteLine(cache.GetOrDefault("user:42", "Unknown"));
Console.WriteLine(cache.GetOrDefault("missing", "Unknown"));

IPrimary primary = new Combined();
ISecondary secondary = new Combined();

Console.WriteLine(primary.Describe());
Console.WriteLine(secondary.Describe());

interface ICache
{
    string? Get(string key);
    void Set(string key, string value);

    // Versioning-friendly addition: existing implementers do not break.
    string GetOrDefault(string key, string defaultValue)
        => Get(key) ?? defaultValue;
}

sealed class MemoryCache : ICache
{
    private readonly Dictionary<string, string> _values = new();

    public string? Get(string key) => _values.GetValueOrDefault(key);

    public void Set(string key, string value) => _values[key] = value;
}

interface IPrimary
{
    string Describe() => "Primary default";
}

interface ISecondary
{
    string Describe() => "Secondary default";
}

sealed class Combined : IPrimary, ISecondary
{
    // Explicit implementations resolve the conflict intentionally.
    string IPrimary.Describe() => "Resolved to primary";
    string ISecondary.Describe() => "Resolved to secondary";
}
```

## Common Follow-up Questions

- Why were default interface implementations added to C# in the first place?
- What members are allowed inside an interface in modern C#?
- Why do default interface methods not replace abstract classes for shared state?
- How does C# resolve competing defaults from multiple interfaces?
- When are extension methods simpler than default interface implementations?

## Common Mistakes / Pitfalls

- Using default interface implementations as a substitute for proper shared state or base-class invariants.
- Forgetting that dispatch often matters most through the interface type.
- Adding too much logic to interfaces and making APIs harder to discover.
- Assuming multiple competing defaults will be merged automatically without ambiguity.
- Using the feature everywhere, even when simple interface contracts or composition would be clearer.

## References

- [Default interface methods tutorial — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/advanced-topics/interface-implementation/default-interface-methods-versions)
- [Interfaces — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/interfaces/)
- [Proposal/spec notes for default interface methods (verify URL)](https://learn.microsoft.com/dotnet/csharp/language-reference/proposals/csharp-8.0/default-interface-methods)
- [See: abstract-class-vs-interface.md](./abstract-class-vs-interface.md)
- [See: virtual-override-new-keywords.md](./virtual-override-new-keywords.md)
