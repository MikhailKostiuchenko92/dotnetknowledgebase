# How Do You Profile Memory and Find Leaks in .NET?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🟡 Middle
**Tags:** `memory-leaks`, `dotnet-gcdump`, `dotnet-dump`, `ConditionalWeakTable`, `GC`

## Question

> How do you investigate a memory leak in a .NET application?

Also asked as:
> What tools and runtime APIs would you use to find which objects keep growing on the managed heap?
> What are common leak patterns in .NET, and how do you prove the root cause?

## Short Answer

Most .NET memory leak investigations start by confirming heap growth, then collecting the smallest useful artifact. `dotnet-gcdump` is good for lightweight heap snapshots, while `dotnet-dump analyze` gives deeper commands such as `dumpheap -stat`, `gcroot`, and `clrstack` when you need retention roots. Common causes include static collections, forgotten event subscriptions, and long-lived caches, and fixes often involve shorter object lifetimes, explicit unsubscription, or weak-association patterns such as `ConditionalWeakTable`.

## Detailed Explanation

### What “Memory Leak” Usually Means in Managed Code

In .NET, a memory leak usually does **not** mean the GC is broken. It means objects are still reachable, so the GC is doing exactly what it should: keeping them alive. The real question is why those objects remain rooted.

Typical leak sources are surprisingly ordinary:

| Leak pattern | Why it leaks |
|---|---|
| Static collections | Process-lifetime root retains everything added |
| Event handlers not removed | Publisher keeps subscriber alive |
| Long-lived caches | Entries never expire or are too large |
| Background singletons | Scoped/transient data accidentally captured |
| Native resources | Managed wrapper survives or disposal is inconsistent |

### A Practical Investigation Workflow

Start with symptoms. If private bytes and heap size trend upward after traffic stabilizes, use `GC.GetGCMemoryInfo().HeapSizeBytes` or runtime counters to confirm whether the managed heap is growing. Then choose the artifact:

- `dotnet-gcdump` for lightweight heap snapshots and type-growth comparison.
- `dotnet-dump collect` when you need detailed inspection.
- `dotnet-dump analyze` with `dumpheap -stat` to find large surviving types.
- `gcroot` to answer the crucial question: *what is keeping this object alive?*

A full dump gives better root analysis, but a GC dump is often the safer first production step because it is lighter and easier to compare between two time points.

### Interpreting the Findings

`dumpheap -stat` tells you which types dominate object count or retained bytes. That still is not proof of the leak. The proof comes from `gcroot`, which shows a path from the suspicious object back to a root such as a static field, a singleton service, or an event publisher.

For example, if a view model instance is retained by `OrderProcessor.OrderCompleted += ...`, the root cause is not “too many view models.” It is “subscriber lifetime accidentally tied to publisher lifetime.”

> Warning: do not assume the largest type is the leaking type. Strings and arrays often dominate a dump because another object graph is retaining them.

### Preventing Leaks in Design and Tests

Two patterns are worth naming in interviews. First, unsubscribe event handlers or use a weak-event strategy when publisher lifetimes exceed subscriber lifetimes. Second, use `ConditionalWeakTable<TKey, TValue>` when you need to attach auxiliary state to another object without making that attachment the reason it stays alive.

Disposal also matters. If a component owns timers, streams, or subscriptions, implement `IDisposable` or `IAsyncDisposable` and test the behavior. Throwing `ObjectDisposedException` in tests after disposal is a useful guard that the object really transitions into a dead state instead of silently continuing to accumulate state.

This topic pairs naturally with [gc-notifications-and-monitoring.md](./gc-notifications-and-monitoring.md) and [weak-references.md](./weak-references.md).

## Code Example

```csharp
using System.Runtime.CompilerServices;

namespace DotNetRuntimeSamples.MemoryLeaks;

internal sealed class Publisher
{
    public event EventHandler? Tick;

    public void Raise() => Tick?.Invoke(this, EventArgs.Empty);
}

internal sealed class Subscriber : IDisposable
{
    private readonly Publisher _publisher;
    private bool _disposed;

    public Subscriber(Publisher publisher)
    {
        _publisher = publisher;
        _publisher.Tick += OnTick; // If never removed, the publisher roots this subscriber.
    }

    private void OnTick(object? sender, EventArgs e) => Console.WriteLine("Handled event.");

    public void Dispose()
    {
        if (_disposed)
        {
            throw new ObjectDisposedException(nameof(Subscriber));
        }

        _publisher.Tick -= OnTick; // Important for leak prevention.
        _disposed = true;
    }
}

internal static class Program
{
    private static readonly ConditionalWeakTable<object, Metadata> MetadataTable = new();

    private static void Main()
    {
        var publisher = new Publisher();
        using var subscriber = new Subscriber(publisher);

        var order = new object();
        MetadataTable.Add(order, new Metadata("attached without extending lifetime"));

        Console.WriteLine($"Managed heap bytes: {GC.GetGCMemoryInfo().HeapSizeBytes}");
        publisher.Raise();
    }

    private sealed record Metadata(string Notes);
}
```

## Common Follow-up Questions

- Why is `gcroot` usually more valuable than `dumpheap -stat` alone?
- When is `dotnet-gcdump` enough, and when do you need a full dump?
- Why can event subscriptions leak memory even in a garbage-collected language?
- What problem does `ConditionalWeakTable` solve better than a normal dictionary?
- How would you verify correct disposal behavior in tests?

## Common Mistakes / Pitfalls

- Blaming the GC instead of identifying the root that keeps objects reachable.
- Looking only at total heap size without comparing type growth between snapshots.
- Forgetting that static fields and singleton services are effectively process-lifetime roots.
- Using normal dictionaries for attached metadata and accidentally making them the root of the leak.
- Treating `Dispose` as optional when the object owns subscriptions, timers, or native handles.

## References

- [dotnet-gcdump — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-gcdump)
- [dotnet-dump — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-dump)
- [GC.GetGCMemoryInfo Method — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.gc.getgcmemoryinfo)
- [ConditionalWeakTable<TKey,TValue> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.conditionalweaktable-2)
- [Analyze memory usage — Visual Studio](https://learn.microsoft.com/visualstudio/profiling/memory-usage-without-debugging2)
