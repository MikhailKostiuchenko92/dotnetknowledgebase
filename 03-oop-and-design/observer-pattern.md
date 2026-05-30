# Observer Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟡 Middle
**Tags:** `observer`, `behavioral`, `IObservable`, `events`, `reactive`

## Question
> Can you explain the Observer pattern in .NET, including `IObservable<T>` / `IObserver<T>`, and how it compares to events or Rx?

## Short Answer
Observer is a one-to-many notification pattern: one publisher pushes updates to many subscribers without knowing their concrete types. In .NET, the built-in observer model uses `IObservable<T>` and `IObserver<T>`, while events are a simpler language-level alternative. Rx builds on the same idea but adds composition operators, scheduling, and a richer reactive model.

## Detailed Explanation
### What it is
Observer models a relationship where one object, often called the subject or publisher, notifies other objects when something changes. The publisher does not call specific concrete classes directly; it only knows that subscribers implement a common contract.

This decouples the source of change from the reactions to change. A stock ticker, order status stream, telemetry feed, or domain event publisher are common examples.

### How it works in .NET
The formal .NET version uses `IObservable<T>` and `IObserver<T>`.

- `IObservable<T>` exposes `Subscribe`.
- `IObserver<T>` receives `OnNext`, `OnError`, and `OnCompleted`.
- `Subscribe` returns `IDisposable`, which represents the subscription and allows unsubscribe.

That contract is more expressive than normal events because it models not only values, but also completion and terminal failure. The provider owns the sequence, and subscribers opt in and opt out.

Events are a lighter alternative. They are great for in-process notifications inside a bounded part of the application, but they do not naturally model completion and are easier to leak if you forget to unsubscribe. Rx (`System.Reactive`) goes further by treating asynchronous event streams as queryable sequences with operators such as `Select`, `Where`, `Throttle`, and `Merge`.

| Option | Strength | Limitation |
| --- | --- | --- |
| Events | Simple and idiomatic | No completion model, limited composition |
| `IObservable<T>` | Standard push contract | More ceremony to implement |
| Rx | Powerful stream composition | Extra dependency and learning curve |

### Why it matters
Observer reduces coupling. The publisher only emits facts; subscribers decide what to do with them. That helps with extensibility because you can add new reactions without changing the publisher.

It also makes pub-sub flows explicit inside a process. That said, interviewers often expect you to distinguish **Observer** from a distributed message broker. Observer is an in-memory design pattern; Kafka, RabbitMQ, or Azure Service Bus are infrastructure-level pub-sub systems.

> The biggest real-world risk with Observer is memory leaks from long-lived publishers holding references to short-lived subscribers.

### Weak events and trade-offs
Because subscriptions are references, forgetting to unsubscribe can keep objects alive. WPF introduced the weak event pattern to reduce this problem for UI scenarios. In general .NET code, you still need a subscription lifetime strategy.

Use Observer when:
- many parts of the system react to one change;
- the publisher should stay decoupled from subscribers;
- push-based notifications fit better than polling.

Avoid or limit it when:
- event ordering and failure handling are business-critical but implicit;
- debugging hidden side effects becomes difficult;
- a simple direct method call is clearer.

A strong interview answer usually says: events are the lightweight language feature, `IObservable<T>` is the formal pattern contract, and Rx is the richer ecosystem built on top of that reactive idea.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.ObserverPattern;

public sealed class TemperatureSensor : IObservable<int>
{
    private readonly List<IObserver<int>> _observers = [];

    public IDisposable Subscribe(IObserver<int> observer)
    {
        if (!_observers.Contains(observer))
        {
            _observers.Add(observer);
        }

        return new Unsubscriber(_observers, observer);
    }

    public void Publish(int value)
    {
        foreach (var observer in _observers)
        {
            observer.OnNext(value);
        }
    }

    public void Complete()
    {
        foreach (var observer in _observers)
        {
            observer.OnCompleted();
        }

        _observers.Clear();
    }

    private sealed class Unsubscriber(List<IObserver<int>> observers, IObserver<int> observer) : IDisposable
    {
        public void Dispose() => observers.Remove(observer);
    }
}

public sealed class ConsoleObserver(string name) : IObserver<int>
{
    public void OnCompleted() => Console.WriteLine($"{name}: stream completed");

    public void OnError(Exception error) => Console.WriteLine($"{name}: error = {error.Message}");

    public void OnNext(int value) => Console.WriteLine($"{name}: temperature = {value}°C");
}

public static class Program
{
    public static void Main()
    {
        var sensor = new TemperatureSensor();
        var dashboard = new ConsoleObserver("Dashboard");
        var alerts = new ConsoleObserver("Alerts");

        using var dashboardSubscription = sensor.Subscribe(dashboard);
        using var alertSubscription = sensor.Subscribe(alerts);

        sensor.Publish(21);
        sensor.Publish(29);
        sensor.Complete();
    }
}
```

## Common Follow-up Questions
- How is Observer different from pub-sub with a message broker?
- When would you choose events instead of `IObservable<T>`?
- What extra value does Rx provide on top of `IObservable<T>`?
- How do memory leaks happen with observers and events?
- What is the weak event pattern?
- How would you test observer-based code?

## Common Mistakes / Pitfalls
- Forgetting to unsubscribe from a long-lived publisher and leaking memory.
- Treating in-process Observer as if it provided the reliability guarantees of a message broker.
- Using events for complex stream transformations that would be clearer with Rx.
- Ignoring `OnError` and `OnCompleted` semantics when implementing `IObservable<T>`.

## References
- [Observer pattern - Refactoring.Guru](https://refactoring.guru/design-patterns/observer)
- [Observer design pattern - .NET](https://learn.microsoft.com/dotnet/standard/events/observer-design-pattern)
- [Events - C# Programming Guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/events/)
- [IObservable<T> Interface](https://learn.microsoft.com/dotnet/api/system.iobservable-1)
