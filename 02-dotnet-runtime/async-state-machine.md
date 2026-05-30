# What Async State Machine Does C# Generate?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Senior  
**Tags:** `iasyncstatemachine`, `movenext`, `asynctaskmethodbuilder`, `boxing`, `compiler`

## Question
> What state machine does the C# compiler generate for an `async` method?

> What do `MoveNext()` and the state field do inside an async method implementation?

> When does an async method allocate on the heap, and what role does `AsyncTaskMethodBuilder<T>` play?

## Short Answer
The C# compiler rewrites an `async` method into a generated struct that implements `IAsyncStateMachine`. That struct contains a state field, lifted locals, awaiters, and a `MoveNext()` method holding the real control flow; the method builder (`AsyncTaskMethodBuilder` or a related builder) owns the returned task and records completion or failure. If every await completes synchronously, the method may finish with minimal allocation, but once the state machine has to survive beyond the current stack frame it is boxed or otherwise heap-backed so execution can resume later. Advanced `ValueTask` scenarios can use custom builders such as `PoolingAsyncValueTaskMethodBuilder<>` to reduce allocations further.

## Detailed Explanation
### The compiler rewrites the method
An `async` method in source code is convenient syntax, not the real execution form. During compilation, Roslyn generates a hidden state machine type and decorates the original method with `AsyncStateMachineAttribute`. The generated type usually starts life as a struct because that is cheap for the fast path where no suspension actually occurs.

Inside that generated type, the compiler stores:

- an integer state field
- the method builder
- lifted locals that must survive across awaits
- one or more awaiter fields
- the `MoveNext()` method
- `SetStateMachine()` for runtime integration

### State values and `MoveNext()`
`MoveNext()` is the real heart of the method. It contains the transformed logic that used to look like straightforward source code.

| State value | Meaning |
| --- | --- |
| `-1` | Method started / currently running before first suspension |
| `0..N` | Resume point for a specific `await` |
| `-2` | Method completed |

Each `await` becomes a branch in `MoveNext()`. If the awaited operation is already complete, execution continues inline. If not, the state is updated to the resume point, the builder arranges a continuation, and control returns to the caller. Later, when the awaiter completes, the continuation invokes `MoveNext()` again and execution resumes from the correct state.

### The method builder owns completion
The builder type depends on the async return type. For `Task`/`Task<T>` methods the compiler uses `AsyncTaskMethodBuilder` or `AsyncTaskMethodBuilder<T>`. The builder is responsible for:

- creating or exposing the task seen by the caller
- scheduling continuations
- calling `SetResult(...)` on success
- calling `SetException(...)` on failure

This is why a normal `async Task<T>` method can look so simple in source while still producing a first-class task with correct exception and continuation behavior.

### When allocations happen
A useful interview nuance is that `async` does not always allocate the same way. If every awaited operation completes synchronously, the state machine may finish on the fast path with very little overhead. But once an await is incomplete, the state machine must outlive the current call stack so it can resume later.

At that point, the runtime needs heap-backed state. Conceptually, the generated struct is boxed so the continuation can hold onto it. That is why the “heap allocation per await” rule is directionally useful, even if the exact implementation is optimized across runtime versions.

> Warning: decompiled async internals are implementation details. The exact generated shape can change across compiler/runtime versions, but the mental model of state + builder + `MoveNext()` is stable and interview-relevant.

### Pooling builders and observation tools
For advanced `ValueTask` scenarios, .NET supports custom async method builders. One example is `[AsyncMethodBuilder(typeof(PoolingAsyncValueTaskMethodBuilder<>))]`, which can reduce allocations in specialized high-performance code. This is powerful but uncommon in day-to-day app code.

To observe generated machinery, decompile with ILSpy or inspect Roslyn-generated output. This topic connects directly to [task-and-valuetask.md](./task-and-valuetask.md) and [async-await-overview.md](./async-await-overview.md).

## Code Example
```csharp
using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;

namespace RuntimeSamples.AsyncStateMachine;

internal static class Program
{
    private static async Task Main()
    {
        MethodInfo method = typeof(Sample).GetMethod(nameof(Sample.ComputeAsync))!;
        var attribute = method.GetCustomAttribute<AsyncStateMachineAttribute>();

        Console.WriteLine($"Generated state machine: {attribute?.StateMachineType.FullName}");
        Console.WriteLine(await new Sample().ComputeAsync(21));
    }
}

internal sealed class Sample
{
    public async Task<int> ComputeAsync(int value)
    {
        // If this await does not complete synchronously, the state machine must survive for later resumption.
        await Task.Delay(50);
        return value * 2;
    }
}
```

## Common Follow-up Questions
- Why does the compiler generate a struct for the async state machine initially?
- What lives inside `MoveNext()` after compilation?
- When does an async method need heap-backed state instead of staying on the stack?
- What is the role of `AsyncTaskMethodBuilder<T>`?
- How can you inspect generated async code in practice?

## Common Mistakes / Pitfalls
- Saying `async` methods are interpreted specially by the CLR without a compiler transformation.
- Forgetting that every `await` is a potential suspension point captured in state.
- Oversimplifying allocations as “always one allocation per method call” regardless of synchronous completion.
- Confusing `SynchronizationContext` capture with the compiler-generated state machine itself.
- Treating custom async method builders as common application-level practice.

## References
- https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.iasyncstatemachine
- https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.asynctaskmethodbuilder-1
- https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.asyncstatemachineattribute
- https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.asyncmethodbuilderattribute
- https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.poolingasyncvaluetaskmethodbuilder-1