# Type-Safe Builder Pattern in C#

**Category:** OOP & Design / Generics & Type-Level Patterns
**Difficulty:** 🔴 Senior
**Tags:** `builder`, `phantom-types`, `type-state`, `compile-time-safety`

## Question
> What is a type-safe builder pattern in C#, and how can phantom types or type-state generics enforce mandatory build steps at compile time?

## Short Answer
A type-safe builder encodes build progress in the type system so invalid construction paths do not compile. Instead of checking at runtime whether required properties were set, each builder step returns a new generic state, and only the fully configured state exposes `Build()`. This reduces a whole class of runtime bugs, and it is especially useful when required members alone cannot model ordered mandatory steps. The trade-off is that the API becomes more complex than a classic builder.

## Detailed Explanation
### What type-state and phantom types mean here
A classic builder collects values and validates them inside `Build()`. That is flexible, but it means missing required fields are often discovered only at runtime. A type-safe builder uses extra generic type parameters to represent construction state, such as `TitleMissing` or `TitleSet`.

These marker types are often called phantom types because they exist to influence the type system, not the runtime domain model. The builder carries them as generic arguments, and each method returns a new builder type representing the next valid state.

| Approach | Validation moment | Strength | Weakness |
|---|---|---|---|
| Classic builder | Runtime `Build()` | Simple API | Invalid flows compile |
| `required` members / init-only | Object initialization time | Great for simple DTO construction | Does not model multi-step workflows well |
| Type-state builder | Compile time | Prevents invalid sequences entirely | More generic complexity and more types |

### How compile-time enforcement works
The common shape is `Builder<TState1, TState2>`. Suppose one generic argument tracks whether a title was provided and another tracks whether a destination was chosen. `WithTitle` returns `Builder<TitleSet, TDestinationState>`. `ToDestination` returns `Builder<TTitleState, DestinationSet>`. Then `Build()` is only available for `Builder<TitleSet, DestinationSet>`.

That means the compiler rejects `Build()` before all required steps are complete. In other words, the API does not merely document the valid sequence—it enforces it.

This is especially valuable when object construction has a required order, when one step unlocks another, or when multiple incomplete states are dangerous in production. Examples include workflow definitions, command builders, HTTP client request builders, and infrastructure configuration objects.

> Warning: Type-state builders improve correctness, but they also increase API surface area and cognitive load. If the object only has two required properties, `required` members or a normal constructor may be the simpler choice.

### Why teams use it and where it fits
The main benefit is moving failures earlier. Missing a required step becomes a compile error instead of a late exception, test failure, or half-configured runtime object.

It also communicates intent well in public APIs. The allowed sequence becomes visible in method return types instead of being buried in documentation comments.

### Trade-offs and when not to use it
The cost is complexity. You introduce marker types, generic state parameters, and more advanced signatures that not every team member finds intuitive. Tooling and call-site readability are usually fine once the API is designed well, but implementation is undeniably more complex.

Use this pattern when invalid states are costly, the sequence matters, and the API is reused enough to justify the complexity. Do not use it for ordinary CRUD DTOs or simple objects where constructors, `required` members, or runtime validation are perfectly adequate.

## Code Example
```csharp
using System;

namespace InterviewExamples;

public interface ITitleState;
public sealed class TitleMissing : ITitleState;
public sealed class TitleSet : ITitleState;

public interface IDestinationState;
public sealed class DestinationMissing : IDestinationState;
public sealed class DestinationSet : IDestinationState;

public sealed record Report(string Title, string Destination);

public sealed class ReportBuilder<TTitleState, TDestinationState>
    where TTitleState : ITitleState
    where TDestinationState : IDestinationState
{
    private readonly string? _title;
    private readonly string? _destination;

    internal ReportBuilder(string? title = null, string? destination = null)
    {
        _title = title;
        _destination = destination;
    }

    public ReportBuilder<TitleSet, TDestinationState> WithTitle(string title) =>
        new(title, _destination); // Move to the "title set" state.

    public ReportBuilder<TTitleState, DestinationSet> ToDestination(string destination) =>
        new(_title, destination); // Move to the "destination set" state.

    internal Report BuildCore() => new(_title!, _destination!);
}

public static class ReportBuilder
{
    public static ReportBuilder<TitleMissing, DestinationMissing> Create() => new();
}

public static class ReportBuilderExtensions
{
    public static Report Build(this ReportBuilder<TitleSet, DestinationSet> builder) => builder.BuildCore();
}

internal static class Program
{
    private static void Main()
    {
        var report = ReportBuilder.Create()
            .WithTitle("Quarterly Results")
            .ToDestination("finance@company.test")
            .Build(); // Only available when both mandatory steps are completed.

        Console.WriteLine($"{report.Title} -> {report.Destination}");
    }
}
```

## Common Follow-up Questions
- How does a type-state builder compare to `required` properties or constructors?
- What are phantom types, and do they have any runtime cost?
- How would you model optional steps alongside mandatory ones?
- When does this pattern become overengineering?
- Can this approach enforce ordering, not just presence, of steps?

## Common Mistakes / Pitfalls
- Using a type-state builder for simple objects that would be clearer with a constructor.
- Exposing too many marker types publicly and making the API intimidating.
- Forgetting immutability and accidentally mutating shared builder state between steps.
- Encoding every tiny rule in the type system until the API becomes unreadable.
- Assuming compile-time enforcement removes the need for all runtime validation.

## References
- [Generic types and methods - C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/generics)
- [required modifier - C# reference | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/required)
- [Fluent Interface - Martin Fowler](https://martinfowler.com/bliki/FluentInterface.html)
- [Constructing Immutable Objects with a Builder - Damir's Corner](https://www.damirscorner.com/blog/posts/20200612-ConstructingImmutableClassesWithABuilder.html)
