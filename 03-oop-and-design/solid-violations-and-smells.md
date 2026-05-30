# SOLID Violations and Code Smells

**Category:** OOP & Design / SOLID
**Difficulty:** 🔴 Senior
**Tags:** `SOLID`, `code-smells`, `refactoring`

## Question
> How do you recognize SOLID violations in a real codebase, and what smells usually point to them?

## Short Answer
In real codebases, SOLID violations rarely announce themselves as “SRP broken here.” They usually show up as recurring change patterns and smells: shotgun surgery, fragile base classes, interface bloat, God classes, and fake implementations that throw at runtime. The key is to connect those symptoms to the broken design principle and refactor the smallest boundary that reduces change risk.

## Detailed Explanation
### Smells are operational signals
Senior engineers often spot design problems through maintenance pain before they talk about principles. If one feature request requires edits in eight files across different layers, that is a smell. If adding a subclass unexpectedly breaks existing behavior, that is a smell. If a service injects a five-method interface but uses only one method, that is a smell.

Those observations matter because SOLID is easier to apply when grounded in symptoms rather than slogans.

### Mapping common smells to likely SOLID problems
| Smell | Typical SOLID issue | What it usually means |
| --- | --- | --- |
| God class / divergent change | SRP | Multiple responsibilities are mixed together |
| Shotgun surgery | SRP / OCP | One change axis is scattered across many modules |
| Fragile base class | OCP / LSP | Inheritance hierarchy is too coupled and unsafe to extend |
| Interface bloat | ISP | Clients depend on behavior they do not need |
| Concrete infrastructure in business code | DIP | High-level policy depends on details |
| `NotSupportedException` in implementations | LSP / ISP | The abstraction is dishonest |

Shotgun surgery is especially useful in interviews because it is a practical smell. If adding a notification channel forces edits in controllers, services, repositories, and renderers, your extension model is weak. A better design usually introduces an explicit seam such as a strategy or plug-in abstraction.

### Fragile base class and behavioural risk
A fragile base class appears when many subclasses depend on subtle base behavior. A small base-class change — new virtual call order, new default implementation, new invariant — unexpectedly breaks subclasses. That is an OCP problem because extension is unsafe, and often an LSP problem because subclasses are tightly coupled to internal assumptions rather than a stable contract.

In C#, deep inheritance trees with many protected hooks are common sources of this smell. Composition is often the safer alternative.

### Interface bloat and fake implementations
Interface bloat is a direct ISP signal. A large interface often forces dummy implementations, empty methods, or `NotSupportedException`. That is more than ugliness; it weakens contracts, complicates tests, and increases ripple effects for unrelated consumers.

> Warning: a smell is evidence to investigate, not automatic proof. Some wide interfaces are legitimate façades, and some scattered edits are caused by cross-cutting concerns rather than bad design.

### How to investigate a codebase
Look at both the code and the change history. Useful questions include:
- Which files always change together?
- Which classes have many unrelated dependencies?
- Which interfaces are mocked heavily but only partially used?
- Which subclasses override lots of protected methods or depend on call order?
- Where do runtime exceptions reveal unsupported behavior?

Static review plus Git history is often more revealing than staring at one class in isolation.

### Refactoring strategy
Do not “apply SOLID everywhere” in one sweep. Start where pain is highest. Extract a responsibility from a God class. Replace one fragile inheritance branch with composition. Split one bloated interface around real client roles. Invert one infrastructure dependency at the application boundary. Small, local improvements usually create the most value.

In interviews, the best answers connect smell detection to maintainability outcomes: fewer regressions, smaller change sets, clearer tests, and safer extension.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.SolidSmellsSample;

/*
Before:
- Fragile base class: BaseExporter with many virtual hooks and hidden ordering rules
- Interface bloat: INotificationOperations with Email, Sms, Push, Report, Archive
- Shotgun surgery: every new channel edits many switch statements

After:
- Extension via small notification strategies
- Focused contracts per role
*/

public interface INotificationChannel
{
    string Name { get; }
    void Send(string recipient, string message);
}

public sealed class EmailChannel : INotificationChannel
{
    public string Name => "Email";

    public void Send(string recipient, string message)
    {
        Console.WriteLine($"Email to {recipient}: {message}");
    }
}

public sealed class SmsChannel : INotificationChannel
{
    public string Name => "SMS";

    public void Send(string recipient, string message)
    {
        Console.WriteLine($"SMS to {recipient}: {message}");
    }
}

public sealed class NotificationDispatcher
{
    private readonly Dictionary<string, INotificationChannel> _channels = new(StringComparer.OrdinalIgnoreCase);

    public NotificationDispatcher(IEnumerable<INotificationChannel> channels)
    {
        foreach (var channel in channels)
        {
            _channels[channel.Name] = channel; // Add channels without modifying dispatcher behavior.
        }
    }

    public void Dispatch(string channelName, string recipient, string message)
    {
        if (!_channels.TryGetValue(channelName, out var channel))
        {
            throw new InvalidOperationException($"Unknown channel '{channelName}'.");
        }

        channel.Send(recipient, message);
    }
}

public static class Program
{
    public static void Main()
    {
        var dispatcher = new NotificationDispatcher([new EmailChannel(), new SmsChannel()]);
        dispatcher.Dispatch("Email", "user@example.com", "Interview scheduled.");
        dispatcher.Dispatch("SMS", "+123456789", "Interview starts in 30 minutes.");
    }
}
```

## Common Follow-up Questions
- How do you distinguish a real smell from a harmless design compromise?
- Why does shotgun surgery often indicate an OCP problem?
- What makes a base class fragile in C#?
- How would you use Git history to detect SRP violations?
- When is interface bloat worse than using a concrete class?
- What is the safest order to refactor these smells in production code?

## Common Mistakes / Pitfalls
- Treating every large class as automatically wrong without checking cohesion.
- Refactoring by pattern name instead of targeting the actual maintenance pain.
- Keeping inheritance hierarchies because “reuse” feels cheaper than redesign.
- Splitting interfaces without understanding who the real clients are.
- Ignoring change history and only evaluating static code structure.

## References
- [Architectural principles for modern web applications with Azure](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Shotgun Surgery code smell](https://refactoring.guru/smells/shotgun-surgery)
- [Large Class code smell](https://refactoring.guru/smells/large-class)
- [Refused Bequest code smell](https://refactoring.guru/smells/refused-bequest)
- [Inheritance in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance)
