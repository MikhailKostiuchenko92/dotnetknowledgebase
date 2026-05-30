# How Does Async Context Propagate in .NET?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Senior  
**Tags:** `asynclocal`, `executioncontext`, `activity`, `context-flow`, `logical-call-context`

## Question
> How do values flow through async calls in .NET without being passed explicitly?

> What is the difference between `AsyncLocal<T>` and `ExecutionContext`?

> Why do tracing and correlation IDs survive across `await`, and when would you suppress that flow?

## Short Answer
`AsyncLocal<T>` stores logical call-context data that flows across `await` boundaries, and `ExecutionContext` is the runtime container that captures and restores those values as async work continues. The flow is downward into child async operations, but changes made in a child do not automatically mutate the parent's logical context because the data behaves copy-on-write. That is why tracing primitives such as `Activity.Current` can follow an async request naturally. In rare performance-sensitive fire-and-forget scenarios, `ExecutionContext.SuppressFlow()` prevents that capture and propagation.

## Detailed Explanation
### `ExecutionContext` versus `SynchronizationContext`
These two concepts are often confused in interviews. `SynchronizationContext` decides **where** a continuation should run. `ExecutionContext` carries logical ambient data that should flow with the operation regardless of which physical thread runs it.

Examples of data that ride inside `ExecutionContext` include:

- `AsyncLocal<T>` values
- security and impersonation-related context
- tracing correlation like `Activity.Current`
- legacy logical call-context payloads

| Concept | Main purpose | Flows across `await`? | Typical examples |
| --- | --- | --- | --- |
| `SynchronizationContext` | Scheduling target for continuations | Captured optionally | UI thread, ASP.NET Classic request context |
| `ExecutionContext` | Logical ambient data | Yes, by default | `AsyncLocal<T>`, tracing, security context |
| `ThreadLocal<T>` | Physical-thread local storage | No logical flow | Per-thread caches |

### `AsyncLocal<T>` gives ambient async-scoped data
`AsyncLocal<T>` is the modern way to store data that should automatically follow an async operation. Logging scopes, correlation IDs, tenant identifiers, and trace activities often depend on it.

A crucial nuance: values flow down to child operations, but child mutations do not simply “write back” into the parent's logical context. Each async branch gets its own logical view, and changes behave more like copy-on-write than shared mutable state. That prevents unrelated branches from trampling each other's ambient values.

> Warning: `AsyncLocal<T>` is not the same as thread-local storage. In async code, the continuation may resume on another thread and still see the same logical value.

### Why tracing works so naturally
`Activity.Current` in distributed tracing is backed by `AsyncLocal<T>`, which is why OpenTelemetry correlation can survive multiple awaits and thread switches without explicit parameter passing. The value is restored whenever the runtime restores the matching `ExecutionContext`.

This is powerful but not free. Every async hop may need to capture and restore context. Most application code should happily accept that overhead because it buys correct tracing and observability. Very hot infrastructure paths sometimes measure it carefully.

### Suppressing flow
`ExecutionContext.SuppressFlow()` tells the runtime not to capture the current execution context for future work items. That can be useful for detached fire-and-forget operations that should not inherit request-scoped ambient data.

It is a niche tool. If you suppress flow casually, logs and traces may lose correlation unexpectedly. Use it when you deliberately want isolation, not as a default micro-optimization.

### Legacy logical call context
Older .NET code sometimes used `CallContext.LogicalSetData`. In modern .NET, `AsyncLocal<T>` is the preferred replacement because it integrates naturally with async/await and is clearer to reason about. The big design shift is that ambient data is now expected to survive asynchronous boundaries by default, which is exactly what modern logging, tracing, and per-request context propagation need. For related scheduling behavior, see [synchronization-context.md](./synchronization-context.md) and [async-await-overview.md](./async-await-overview.md).

## Code Example
```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

namespace RuntimeSamples.AsyncContextPropagation;

internal static class Program
{
    private static readonly AsyncLocal<string?> CorrelationId = new();

    private static async Task Main()
    {
        CorrelationId.Value = "root-request";
        Console.WriteLine($"Parent before child: {CorrelationId.Value}");

        await ChildAsync();
        Console.WriteLine($"Parent after child: {CorrelationId.Value}"); // Still root-request.

        Task detached;
        using (ExecutionContext.SuppressFlow())
        {
            // This work item does not inherit the current AsyncLocal values.
            detached = Task.Run(() => Console.WriteLine($"Suppressed flow: {CorrelationId.Value ?? "<null>"}"));
        }

        await detached;
    }

    private static async Task ChildAsync()
    {
        Console.WriteLine($"Child inherited: {CorrelationId.Value}");
        CorrelationId.Value = "child-request"; // Does not overwrite the parent's logical context.

        await Task.Delay(50);
        Console.WriteLine($"Child after await: {CorrelationId.Value}");
    }
}
```

## Common Follow-up Questions
- How is `ExecutionContext` different from `SynchronizationContext`?
- Why does `AsyncLocal<T>` work across thread switches?
- Why doesn't changing an `AsyncLocal<T>` in a child mutate the parent's value?
- When is `ExecutionContext.SuppressFlow()` appropriate?
- How do OpenTelemetry and `Activity.Current` rely on this mechanism?

## Common Mistakes / Pitfalls
- Treating `AsyncLocal<T>` like normal shared mutable state between parent and child operations.
- Confusing logical context flow with UI-thread affinity.
- Using `ThreadLocal<T>` for request correlation in async code.
- Suppressing `ExecutionContext` flow and then wondering why logs or traces lost correlation.
- Forgetting that ambient data still has runtime cost on very hot paths.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.asynclocal-1
- https://learn.microsoft.com/dotnet/api/system.threading.executioncontext
- https://learn.microsoft.com/dotnet/api/system.threading.executioncontext.suppressflow
- https://learn.microsoft.com/dotnet/api/system.diagnostics.activity
- https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing-concepts