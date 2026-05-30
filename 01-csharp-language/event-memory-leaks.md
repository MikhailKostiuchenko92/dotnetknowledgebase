# Event Memory Leaks

**Category:** C# / Delegates, Events, Lambdas
**Difficulty:** Senior
**Tags:** `event`, `memory-leak`, `weak-event`, `unsubscribe`, `GC`

## Question

> How can event subscriptions cause memory leaks in .NET, and what patterns exist to prevent or detect them?

Also asked as:
- "Why does subscribing to an event on a long-lived object prevent GC of the subscriber?"
- "What is the Weak Event pattern and when should you use it?"

## Short Answer

When object **B** subscribes to an event on long-lived object **A**, **A**'s delegate field holds a reference to **B** (directly or via a captured closure). As long as **A** is alive, **B** cannot be garbage-collected, even if no other code holds a reference to **B**. The fix is always to unsubscribe when **B** is done, or to use a weak-event pattern that holds only a `WeakReference` to the subscriber.

## Detailed Explanation

### How the Leak Forms

```
LongLivedPublisher._handler → Delegate → subscriber.Method → subscriber object
```

The delegate object stores:
1. A reference to the target object (the subscriber's `this`), or
2. A closure object (which may in turn reference the subscriber or other locals).

Because the publisher is rooted (alive for the app's lifetime, e.g., a singleton, static, or service), the entire chain is GC-reachable and will **never be collected** until the subscription is removed.

### Common Scenarios

| Scenario | Why it leaks |
|---|---|
| ViewModel subscribes to a model event | Model (long-lived) holds ViewModel; ViewModel holds View |
| Static event (`AppDomain.UnhandledException`, `Application.Current.Navigating`) | Static root → delegate → subscriber |
| UI control subscribes to a service | Service (singleton) → delegate → Control → entire visual subtree |
| Anonymous lambda capturing `this` | Closure object references `this` of the subscribing class |

### Detection

Tools that reveal event leaks:
- **dotMemory / ANTS Memory Profiler** — show object retention paths.
- **Visual Studio Diagnostic Tools** — heap snapshots can show unexpected live instances.
- **`GC.Collect()` + `WeakReference` in unit tests** — forcibly collect and verify the subscriber was released.

### Solution 1: Explicit Unsubscription

The simplest and most reliable approach. Unsubscribe when the subscriber is no longer needed:

```csharp
// On initialization
publisher.DataChanged += OnDataChanged;

// On disposal / page navigation / window closed
publisher.DataChanged -= OnDataChanged;
```

In MVVM this usually goes in `IDisposable.Dispose()` or the `Deactivate` lifecycle method. **Lambda subscribers cannot be unsubscribed** unless stored in a field:

```csharp
// ❌ Cannot unsubscribe this:
publisher.DataChanged += (s, e) => Update();

// ✅ Store the lambda to unsubscribe later:
private EventHandler _handler;

_handler = (s, e) => Update();
publisher.DataChanged += _handler;
// later:
publisher.DataChanged -= _handler;
```

### Solution 2: Weak Event Pattern (Manual)

Store a `WeakReference<T>` to the subscriber inside a custom adapter:

```csharp
public sealed class WeakEventAdapter<TSubscriber> where TSubscriber : class
{
    private readonly WeakReference<TSubscriber> _weak;
    private readonly Action<TSubscriber> _handler;

    public WeakEventAdapter(TSubscriber subscriber, Action<TSubscriber> handler,
        Action<EventHandler> subscribe, Action<EventHandler> unsubscribe)
    {
        _weak = new WeakReference<TSubscriber>(subscriber);
        _handler = handler;

        EventHandler wrapper = null!;
        wrapper = (_, _) =>
        {
            if (_weak.TryGetTarget(out var target))
                _handler(target);
            else
                unsubscribe(wrapper);   // auto-unsubscribe when target is dead
        };
        subscribe(wrapper);
    }
}
```

### Solution 3: `WeakEventManager` (WPF / .NET MAUI)

WPF ships `WeakEventManager<TSource, TEventArgs>` which manages weak subscriptions automatically:

```csharp
// Subscribe weakly
WeakEventManager<Publisher, DataEventArgs>.AddHandler(
    publisher, nameof(Publisher.DataChanged), OnDataChanged);

// Unsubscribe (optional — subscriber can be collected without it)
WeakEventManager<Publisher, DataEventArgs>.RemoveHandler(
    publisher, nameof(Publisher.DataChanged), OnDataChanged);
```

The manager holds only a `WeakReference` to the subscriber. When the subscriber is collected, the manager silently removes the dead entry on the next raise.

> **Caveat:** Weak event patterns have overhead (weak reference lookups, housekeeping) and complexity. Prefer explicit unsubscription; use weak events only when the subscriber's lifetime is genuinely unpredictable relative to the publisher.

### Solution 4: Reactive Extensions (Rx) / `IObservable<T>`

Rx subscriptions return an `IDisposable`; disposing it unsubscribes cleanly:

```csharp
IDisposable sub = publisher.DataChangedStream
    .Subscribe(data => Update(data));

// Later:
sub.Dispose();   // cleanly unsubscribed, no leak
```

### Closures and Anonymous Lambdas

Lambdas that capture local variables or `this` create closure objects:

```csharp
public class ReportView
{
    public ReportView(ReportService svc)
    {
        // 'this' (ReportView) is captured — svc holds a reference to this view forever
        svc.ReportReady += (s, e) => Render(e.Data);
    }
}
```

Even if `ReportView` is "abandoned" by the UI, it stays alive because `svc` (likely a singleton) holds the closure which holds `this`.

### Summary

| Pattern | Pros | Cons |
|---|---|---|
| Explicit unsubscription | Simple, zero overhead | Must remember to do it |
| `IDisposable` + Dispose | Structured lifetime | Requires disposable pattern |
| Weak event (manual) | Subscriber collectable | Complex, overhead |
| `WeakEventManager` | Managed for you | WPF/MAUI only |
| Rx `IDisposable` subscription | Composable, explicit | Requires Rx dependency |

## Code Example

```csharp
using System;

public class DataService
{
    public event EventHandler<string>? DataArrived;
    public void Simulate(string data) => DataArrived?.Invoke(this, data);
}

// BAD: subscriber never unsubscribes — leak if DataService outlives Processor
public class LeakyProcessor
{
    public LeakyProcessor(DataService svc)
    {
        svc.DataArrived += (_, data) => Console.WriteLine(data);  // closure, no handle
    }
}

// GOOD: implements IDisposable and unsubscribes explicitly
public class SafeProcessor : IDisposable
{
    private readonly DataService _svc;
    private bool _disposed;

    public SafeProcessor(DataService svc)
    {
        _svc = svc;
        _svc.DataArrived += OnDataArrived;
    }

    private void OnDataArrived(object? sender, string data)
        => Console.WriteLine($"Processed: {data}");

    public void Dispose()
    {
        if (_disposed) return;
        _svc.DataArrived -= OnDataArrived;   // ← critical
        _disposed = true;
    }
}

// DEMO: verify GC reclaims SafeProcessor after Dispose
var svc = new DataService();

var weakRef = new WeakReference(new SafeProcessor(svc));  // keep weak ref for test

// Use Dispose to unsubscribe, then null out strong ref
((SafeProcessor)weakRef.Target!).Dispose();

GC.Collect();
GC.WaitForPendingFinalizers();
GC.Collect();

Console.WriteLine($"Still alive? {weakRef.IsAlive}");   // False — collected ✅
```

## Common Follow-up Questions

- How do you detect event memory leaks in production without a profiler?
- What is the `ConditionalWeakTable<T>` and how does it differ from a plain `WeakReference`?
- How does `IObservable<T>` from Rx model event lifetime better than `event`?
- Can static events leak even in non-static classes? Give an example.
- How does the .NET garbage collector's finalization queue interact with event-held references?

## Common Mistakes / Pitfalls

- **Subscribing with a lambda and expecting to unsubscribe it later.** Each lambda literal creates a new delegate instance; `event -= (s,e) => ...` does nothing because it's a different object. Always store the lambda if you need to unsubscribe.
- **Forgetting `static` events are the most dangerous.** A single subscription to `AppDomain.CurrentDomain.UnhandledException` from a short-lived object keeps that object (and everything it references) alive for the entire process lifetime.
- **Assuming `IDisposable` prevents the leak automatically.** `Dispose()` only runs if called explicitly or via `using`. Objects that are abandoned (dropped without `Dispose`) will still leak if they subscribed to events on longer-lived publishers.
- **Using a weak event pattern without understanding its overhead.** Weak references and periodic cleanup lists add CPU and memory overhead; for high-frequency events the overhead can exceed the benefit.
- **Not unsubscribing in MVVM `Deactivate`/`OnNavigatedFrom` lifecycle methods.** In navigation-heavy apps, ViewModels are re-created per page but services are singletons — every navigation creates a new subscription without removing the old one.

## References

- [Weak Event Patterns — Microsoft Learn](https://learn.microsoft.com/dotnet/desktop/wpf/events/weak-event-patterns)
- [WeakEventManager — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.windows.weakeventmanager)
- [Memory Leaks and How to Avoid Them — Stephen Cleary (blog)](https://blog.stephencleary.com/2013/04/implicit-async-context-asynclocal.html) (verify URL — search "Stephen Cleary event memory leak")
- [Events — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/events/)
- [See: events-vs-delegates.md](./events-vs-delegates.md)
- [See: idisposable-and-using.md](./idisposable-and-using.md)
