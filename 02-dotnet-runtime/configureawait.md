# What Does `ConfigureAwait(false)` Do?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Middle  
**Tags:** `configureawait`, `synchronizationcontext`, `continuations`, `library-code`, `dotnet-8`

## Question
> What does `ConfigureAwait(false)` actually change in an async method?

> Why do people say library code should use `ConfigureAwait(false)`?

> Does `ConfigureAwait(false)` matter in ASP.NET Core, WinForms, or WPF?

## Short Answer
`ConfigureAwait(false)` tells an `await` not to capture the current `SynchronizationContext` for the continuation. In UI frameworks and ASP.NET Classic, that often avoids resuming on the original context thread and can prevent deadlocks caused by blocking waits. In ASP.NET Core there is no request `SynchronizationContext`, so it usually has no visible behavioral effect, but general-purpose libraries still commonly use it so they do not accidentally depend on caller context. In .NET 8, `ConfigureAwait(ConfigureAwaitOptions)` adds advanced flags such as `ForceYielding` and `SuppressThrowing` for specialized scenarios.

## Detailed Explanation
### What “capturing context” means
When an `await` sees an incomplete task, it has to decide where the continuation should run later. By default, .NET tries to capture the current context so the post-`await` code can resume in the same environment.

That matters in application models where work is thread-affine:

- WinForms and WPF want UI updates on the UI thread.
- ASP.NET Classic had a request context with thread-affinity assumptions.
- Console apps and ASP.NET Core usually do not have a special `SynchronizationContext` to resume on.

`ConfigureAwait(false)` says: do not capture that context for this await. It does **not** mean “run on a random background thread,” and it does **not** suppress `ExecutionContext` or `AsyncLocal<T>` flow.

### Why library code often uses it
A reusable library generally should not assume anything about the caller's environment. If it captures context by default, then a caller running under WinForms, WPF, or ASP.NET Classic may pay unnecessary marshaling overhead or even hit the classic deadlock caused by mixing `.Result`/`.Wait()` with async code.

| Environment | Default await behavior | Effect of `ConfigureAwait(false)` |
| --- | --- | --- |
| WinForms / WPF | Resume on UI context | Continuation can resume off the UI thread |
| ASP.NET Classic | Resume on request context | Helps avoid deadlock and extra marshaling |
| ASP.NET Core | No special request context | Usually no observable thread-affinity change |
| Console app | Usually no special context | Usually little to no observable effect |

Because libraries should be environment-agnostic, a common rule of thumb is: use `ConfigureAwait(false)` in lower-level library code unless you explicitly need the captured context.

> Warning: `ConfigureAwait(false)` is not a magic performance switch and not a security boundary. It only changes continuation scheduling behavior for that await.

### UI code and application code are different
Application code is allowed to care about context. In a button-click handler, you usually **want** the continuation on the UI thread because the next line updates controls. That is why blanket “add `ConfigureAwait(false)` everywhere” advice is incomplete. It is good library guidance, not universal application guidance.

In ASP.NET Core, there is no per-request `SynchronizationContext`, so developers often say `ConfigureAwait(false)` “does nothing.” More precisely, it usually does not change thread-affinity behavior there. Still, many teams keep it in library code for consistency and portability.

### .NET 8 `ConfigureAwaitOptions`
.NET 8 added overloads that accept `ConfigureAwaitOptions`. Two notable flags are:

- `ForceYielding`: even if the task is already complete, behave as if the continuation should yield asynchronously
- `SuppressThrowing`: suppress exception rethrow from the awaiter so infrastructure code can inspect task state manually

These are advanced tools, not everyday application code features. Most code still needs either plain `await` or `ConfigureAwait(false)`. For related topics, see [synchronization-context.md](./synchronization-context.md) and [deadlock-in-async.md](./deadlock-in-async.md).

## Code Example
```csharp
using System;
using System.Threading.Tasks;

namespace RuntimeSamples.ConfigureAwaitDemo;

internal static class Program
{
    private static async Task Main()
    {
        string value = await LibraryComponent.GetValueAsync();
        Console.WriteLine(value);

        // Advanced .NET 8 option: always yield even if the task is already complete.
        await Task.CompletedTask.ConfigureAwait(ConfigureAwaitOptions.ForceYielding);
        Console.WriteLine("ForceYielding continuation ran asynchronously.");
    }
}

internal static class LibraryComponent
{
    public static async Task<string> GetValueAsync()
    {
        await Task.Delay(50).ConfigureAwait(false); // Library code should not require a caller context.
        return "library-result";
    }
}
```

## Common Follow-up Questions
- Why can `ConfigureAwait(false)` help prevent deadlocks in UI apps and ASP.NET Classic?
- Why does it usually make little difference in ASP.NET Core?
- Does `ConfigureAwait(false)` suppress `ExecutionContext` and `AsyncLocal<T>` flow?
- When is it correct to omit `ConfigureAwait(false)` intentionally?
- What are `ForceYielding` and `SuppressThrowing` used for in .NET 8?

## Common Mistakes / Pitfalls
- Claiming that `ConfigureAwait(false)` creates a new thread.
- Using it in UI code and then trying to update controls immediately after the await.
- Assuming it is unnecessary in all libraries just because the current app uses ASP.NET Core.
- Confusing `SynchronizationContext` flow with `ExecutionContext` flow.
- Applying advanced `ConfigureAwaitOptions` flags without a concrete infrastructure need.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.configureawait
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.configureawaitoptions
- https://devblogs.microsoft.com/dotnet/configureawait-faq/
- https://learn.microsoft.com/dotnet/api/system.threading.synchronizationcontext
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios