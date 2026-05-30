# What Does `async`/`await` Actually Do in .NET?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Junior  
**Tags:** `async`, `await`, `tap`, `state-machine`, `task`

## Question
> What does `async`/`await` actually do under the hood in C#?

> Does `await` create a new thread, or is something else happening?

> How is the Task-based Asynchronous Pattern different from the older APM and EAP models?

## Short Answer
`async`/`await` is compiler-generated orchestration over the Task-based Asynchronous Pattern (TAP), not a threading primitive by itself. The compiler rewrites an `async` method into a state machine that can pause at each `await` and resume later when the awaited operation completes. No new thread is automatically created; continuations usually run wherever the awaited operation completes, optionally flowing back through a captured context. In practice, `async Task` is the default return type, `async void` is mostly for event handlers, and `async ValueTask` is a specialized optimization.

## Detailed Explanation
### `async`/`await` is syntax over TAP
Modern .NET asynchronous APIs are built around TAP: methods return `Task` or `Task<T>` to represent work that may finish later. `async` and `await` were added so developers could write that logic in a sequential style instead of hand-writing continuations with `ContinueWith`, callbacks, or completion events.

Before TAP, .NET had two older mainstream patterns:

| Pattern | Shape | Typical era | Main drawback |
| --- | --- | --- | --- |
| APM | `BeginXxx` / `EndXxx` | .NET Framework early years | Hard to compose, callback-heavy |
| EAP | events like `DownloadCompleted` | UI-centric APIs | Awkward error handling and cancellation |
| TAP | `Task` / `Task<T>` | Modern .NET | Preferred model for composition and `await` |

TAP became the standard because tasks compose well: `Task.WhenAll`, `Task.WhenAny`, cancellation tokens, and structured exception propagation all work naturally with it.

### The compiler builds a state machine
When you mark a method `async`, the compiler does not make it “magically asynchronous.” Instead, it transforms the method into a generated type that implements `IAsyncStateMachine`. That generated state machine keeps track of:

- the current state (`-1`, `0`, `1`, and so on)
- locals that must survive across suspension points
- the method builder that owns the returned task
- the `MoveNext()` method that contains the real control flow
- `SetStateMachine()` for runtime plumbing

Every `await` becomes a potential suspension point. If the awaited task is already complete, execution continues synchronously. If not, the state machine stores its current state, registers a continuation, returns control to the caller, and later re-enters `MoveNext()` when the operation completes. For a deeper low-level view, see [async-state-machine.md](./async-state-machine.md).

### `await` does not mean “start a new thread” 
A very common interview myth is that `await` creates a background thread. It does not. `await` only says, “if this operation is incomplete, pause here and resume later.” Whether extra threads are involved depends on the operation being awaited.

- `Task.Delay` uses timers, not a dedicated sleeping thread.
- Socket and file I/O often use OS async I/O and completion callbacks.
- `Task.Run` is what explicitly queues CPU-bound work to the ThreadPool.

> Warning: `async` helps with non-blocking waits, not with making CPU-bound work faster. For CPU-bound work, you usually need different parallelism tools such as `Task.Run`, `Parallel.ForEach`, or dedicated background services.

In UI apps or ASP.NET Classic, the continuation may try to resume on a captured `SynchronizationContext`. In ASP.NET Core or a console app there usually is no special context, so continuation thread choice is more flexible.

### Return types matter
The return type changes behavior and caller expectations:

| Return type | Typical use | Caller can await? | Exception path |
| --- | --- | --- | --- |
| `async Task` | Async work with no result | Yes | Stored on returned task |
| `async Task<T>` | Async work with result | Yes | Stored on returned task |
| `async ValueTask<T>` | Hot-path optimization when sync completion is common | Yes | Stored in returned value/task source |
| `async void` | Event handlers only | No | Raised to context, not caller |

`Task` is the default because it is simple and safe. `ValueTask` is an optimization topic covered in [task-and-valuetask.md](./task-and-valuetask.md). `async void` should be treated as a special-case escape hatch, not a general API design choice.

## Code Example
```csharp
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace RuntimeSamples.AsyncAwaitOverview;

internal static class Program
{
    private static async Task Main()
    {
        Console.WriteLine($"Main started on thread {Environment.CurrentManagedThreadId}");

        int value = await GetValueAsync();
        Console.WriteLine($"Result: {value}");

        // `Task.Run` is what explicitly uses a ThreadPool thread for CPU work.
        int cpuBound = await Task.Run(() => Enumerable.Range(1, 1_000).Sum());
        Console.WriteLine($"CPU-bound result: {cpuBound}");
    }

    private static async Task<int> GetValueAsync()
    {
        Console.WriteLine($"Before await: {Environment.CurrentManagedThreadId}");

        // This is a non-blocking wait. No dedicated thread sleeps here.
        await Task.Delay(100);

        Console.WriteLine($"After await: {Environment.CurrentManagedThreadId}");
        return 42;
    }
}
```

## Common Follow-up Questions
- What exactly is stored inside the compiler-generated async state machine?
- Why can an `async` method complete synchronously even though it contains `await`?
- What is the difference between `Task`, `ValueTask`, and `async void`?
- How does `SynchronizationContext` affect where continuations resume?
- When should I use `Task.Run` together with `async`/`await`?

## Common Mistakes / Pitfalls
- Saying that `await` always creates a new thread.
- Assuming `async` automatically improves CPU-bound performance.
- Exposing `async void` methods in library or application service APIs.
- Forgetting that older APM/EAP APIs often need adapters before they fit naturally into TAP.
- Ignoring the fact that captured context can affect continuation behavior and deadlock risk.

## References
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-return-types
- https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap
- https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/asynchronous-programming-model-apm
- https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.iasyncstatemachine