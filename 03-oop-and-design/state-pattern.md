# State Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🔴 Senior
**Tags:** `state`, `behavioral`, `state-machine`, `Stateless`

## Question
> What is the State pattern, how does it compare with an enum plus `switch`, and when would you use a state-machine library like Stateless?

## Short Answer
State models behavior by moving state-specific logic into separate state objects, so the context delegates work to the current state instead of branching everywhere. Compared with an enum plus `switch`, it scales better when transitions and behavior rules grow, because each state owns its valid actions and next transitions. A library like Stateless is useful when the workflow becomes complex enough that you want explicit transition configuration, guards, and visualization rather than hand-rolled branching.

## Detailed Explanation
### What the pattern is solving
The State pattern addresses code that starts with a simple status enum and gradually turns into a web of `if`/`switch` statements. That is fine for two or three cases, but once transitions, side effects, and rules multiply, one method can become hard to reason about.

State replaces that branching with polymorphism. The context holds a current state object, and operations delegate to it. Each concrete state decides what behavior is allowed and which transition should happen next.

### Why it is more than “an enum with classes”
The pattern is not just about naming states. It is about moving **behavior and transition rules** beside the state they belong to.

| Approach | Works well when | Becomes painful when |
| --- | --- | --- |
| Enum + `switch` | Few states, simple rules | Many transitions and side effects |
| State objects | Rich behavior per state | Overkill for tiny workflows |

For example, a document in Draft can edit and submit, but a Published document may reject edits and allow archive only. With state objects, that logic is localized instead of scattered across service methods.

### How transitions are modeled
A context usually exposes operations like `Submit`, `Approve`, or `Archive`. The current state object handles the call and may replace the context’s state with another concrete state. That means both current behavior and next-step logic are encapsulated.

This also improves testability. You can test one state class in isolation instead of setting up large switch-heavy orchestrators.

> If your state transitions are business-critical, make them explicit and test them directly. Hidden transitions inside unrelated service methods are a common source of bugs.

### State vs enum plus switch
An enum plus switch is not wrong. In fact, it is often the right starting point. The State pattern becomes valuable when you see these signals:

- multiple methods branch on the same enum;
- transitions are conditional and numerous;
- each state has different valid behavior;
- new states keep forcing edits in many places.

For very small flows, an enum is simpler. For larger workflows, the State pattern reduces duplication and “invalid combination” bugs.

### When Stateless helps
Libraries like **Stateless** formalize the same idea with configuration APIs. They let you define states, triggers, guard clauses, entry/exit actions, and even export graphs. That is helpful when workflows become too involved for handwritten state objects.

The trade-off is another abstraction layer. If your workflow is tiny, using a full state machine library can be heavier than necessary.

## Code Example
```csharp
using System;

namespace OopAndDesign.StatePattern;

public interface IDocumentState
{
    void Submit(DocumentContext context);
    void Publish(DocumentContext context);
    string Name { get; }
}

public sealed class DocumentContext
{
    public IDocumentState State { get; private set; } = new DraftState();

    public void TransitionTo(IDocumentState nextState) => State = nextState;
    public void Submit() => State.Submit(this); // Delegates to current state object.
    public void Publish() => State.Publish(this);
}

public sealed class DraftState : IDocumentState
{
    public string Name => "Draft";

    public void Submit(DocumentContext context)
    {
        Console.WriteLine("Draft -> Review");
        context.TransitionTo(new ReviewState());
    }

    public void Publish(DocumentContext context) => Console.WriteLine("Cannot publish directly from Draft");
}

public sealed class ReviewState : IDocumentState
{
    public string Name => "Review";

    public void Submit(DocumentContext context) => Console.WriteLine("Already in Review");

    public void Publish(DocumentContext context)
    {
        Console.WriteLine("Review -> Published");
        context.TransitionTo(new PublishedState());
    }
}

public sealed class PublishedState : IDocumentState
{
    public string Name => "Published";

    public void Submit(DocumentContext context) => Console.WriteLine("Published content cannot be resubmitted");
    public void Publish(DocumentContext context) => Console.WriteLine("Already Published");
}

public static class Program
{
    public static void Main()
    {
        var document = new DocumentContext();
        Console.WriteLine(document.State.Name);

        document.Submit();
        Console.WriteLine(document.State.Name);

        document.Publish();
        Console.WriteLine(document.State.Name);
    }
}
```

## Common Follow-up Questions
- When is an enum plus `switch` still the better solution?
- What signs tell you a workflow should become a state machine?
- How do you model invalid transitions in a State-pattern design?
- What value does a library like Stateless add over hand-written state objects?
- Should states be singleton objects or created per transition?
- How would you test transitions and guards effectively?

## Common Mistakes / Pitfalls
- Introducing the State pattern too early for a tiny workflow.
- Leaving transition logic spread across services instead of centralizing it.
- Forgetting to define behavior for invalid transitions explicitly.
- Recreating complex state objects unnecessarily when stateless singletons would do.
- Using a state machine library for a workflow that only has two simple branches.

## References
- [State](https://refactoring.guru/design-patterns/state)
- [Stateless repository](https://github.com/dotnet-state-machine/stateless)
- [switch expression (C# reference)](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/switch-expression)
