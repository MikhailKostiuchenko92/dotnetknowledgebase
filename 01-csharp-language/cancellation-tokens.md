# Cancellation Tokens

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `CancellationToken`, `CancellationTokenSource`, `cooperative-cancellation`, `OperationCanceledException`

## Question

> How does cooperative cancellation work in .NET? What is `CancellationToken`, `CancellationTokenSource`, and `OperationCanceledException`, and how do you propagate cancellation through an async call chain?

Also asked as:
- "Why does .NET use a cooperative model for cancellation rather than aborting threads?"
- "How do you implement a cancellable operation in your own async method?"

## Short Answer

.NET uses cooperative cancellation: the code that requests cancellation signals a `CancellationTokenSource`, which sets a shared `CancellationToken` to cancelled. The code performing the work must periodically check the token (via `ThrowIfCancellationRequested()` or `IsCancellationRequested`) and stop voluntarily. `OperationCanceledException` (and its subclass `TaskCanceledException`) is the standard exception for signalling that work stopped due to cancellation rather than failure. The token flows through the call chain by being passed as a parameter to every cancellable method.

## Detailed Explanation

### Why Cooperative (Not Preemptive) Cancellation?

Thread.Abort (preemptive cancellation) was deprecated and removed in .NET 5+ because it left shared state corrupt — it could interrupt any instruction, including a half-written data structure. Cooperative cancellation guarantees that the work reaches a safe checkpoint before stopping, preserving invariants.

### The Three Pieces

| Type | Role |
|---|---|
| `CancellationTokenSource` | Owned by the requester; has `.Cancel()` and `.CancelAfter(TimeSpan)` |
| `CancellationToken` | Read-only view of the cancel signal; passed to the worker |
| `OperationCanceledException` | Thrown by a worker to signal it stopped due to cancellation |

```
CancellationTokenSource ─(creates)→ CancellationToken ─(passed to)→ async work
                       ─(.Cancel())────────────────────────────────────────────→ worker reacts
```

### Creating and Signalling

```csharp
using var cts = new CancellationTokenSource();
cts.CancelAfter(TimeSpan.FromSeconds(5));   // timeout
cts.Cancel();                               // manual cancellation
```

`CancellationTokenSource` implements `IDisposable`; always dispose it (or use `using`).

### Checking in Worker Code

**Method 1 — `ThrowIfCancellationRequested()`** — throws `OperationCanceledException` at a safe checkpoint:

```csharp
for (int i = 0; i < items.Length; i++)
{
    ct.ThrowIfCancellationRequested();   // ← checkpoint
    Process(items[i]);
}
```

**Method 2 — `IsCancellationRequested`** — manual check without throwing (use when you need to clean up before throwing):

```csharp
while (!ct.IsCancellationRequested)
{
    ProcessNext();
}
ct.ThrowIfCancellationRequested();   // throw at end to signal caller
```

**Method 3 — `Register` callback** — for bridging non-cooperative APIs:

```csharp
ct.Register(() => socket.Close());   // cancellation triggers close, unblocking the read
```

### Propagating Through Async Chain

Every async method in the call chain must accept and forward the token:

```csharp
// Chain: Controller → Service → Repository → DB driver
public async Task<Order> GetOrderAsync(int id, CancellationToken ct = default)
{
    var order = await _repo.FindAsync(id, ct);      // forward token
    var items = await _repo.GetItemsAsync(id, ct);  // forward token
    return Merge(order, items);
}
```

`default` as the parameter default value allows callers without cancellation support to omit the argument.

### `OperationCanceledException` Handling

```csharp
try
{
    await DoWorkAsync(ct);
}
catch (OperationCanceledException) when (ct.IsCancellationRequested)
{
    // Normal cancellation — not an error
    _logger.LogInformation("Operation cancelled by user");
}
catch (OperationCanceledException)
{
    // Timeout or cancellation from a different token — may be an error
    throw;
}
```

`TaskCanceledException` (thrown by `Task.Delay`, `HttpClient`, etc.) inherits from `OperationCanceledException`, so catching the base type covers all cases.

### Linked Tokens — Combining Cancellation Sources

Combine a user-cancellation token with a timeout:

```csharp
public async Task<string> FetchWithTimeoutAsync(string url, CancellationToken userCt)
{
    using var cts = CancellationTokenSource.CreateLinkedTokenSource(userCt);
    cts.CancelAfter(TimeSpan.FromSeconds(10));

    return await _http.GetStringAsync(url, cts.Token);
}
```

`CreateLinkedTokenSource` creates a new token that cancels when **either** source cancels.

### `CancellationToken.None` and `CancellationToken.default`

`CancellationToken.None` and `default(CancellationToken)` are identical: a token that can never be cancelled. Pass them as stubs when a method requires a token but you don't want cancellation.

### ASP.NET Core — `HttpContext.RequestAborted`

ASP.NET Core injects `HttpContext.RequestAborted` — a token that fires when the HTTP client disconnects. Always pass it to database queries and downstream HTTP calls:

```csharp
public async Task<IActionResult> GetAsync(CancellationToken ct)
{
    // ASP.NET Core binds HttpContext.RequestAborted to the 'ct' parameter automatically
    var result = await _service.GetAsync(ct);
    return Ok(result);
}
```

## Code Example

```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

// --- Worker that respects cancellation ---
static async Task<int[]> ProcessBatchAsync(int[] items, CancellationToken ct)
{
    var results = new int[items.Length];
    for (int i = 0; i < items.Length; i++)
    {
        ct.ThrowIfCancellationRequested();   // checkpoint before each item

        await Task.Delay(20, ct);            // pass token to built-in APIs too
        results[i] = items[i] * 2;
    }
    return results;
}

// --- Timeout with CancelAfter ---
using var cts = new CancellationTokenSource();
cts.CancelAfter(TimeSpan.FromMilliseconds(150));

try
{
    int[] result = await ProcessBatchAsync([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], cts.Token);
    Console.WriteLine($"Done: {string.Join(", ", result)}");
}
catch (OperationCanceledException)
{
    Console.WriteLine("Cancelled after timeout");   // prints after ~150ms
}

// --- Linked token: combine user cancel + timeout ---
static async Task<string> FetchSafeAsync(string url, CancellationToken userCt)
{
    using var linked = CancellationTokenSource.CreateLinkedTokenSource(userCt);
    linked.CancelAfter(TimeSpan.FromSeconds(5));

    using var http = new System.Net.Http.HttpClient();
    return await http.GetStringAsync(url, linked.Token);
}

// --- Register callback for non-cooperative cancellation ---
static async Task WithSocketAsync(CancellationToken ct)
{
    var tcs = new TaskCompletionSource<string>();

    using var reg = ct.Register(() => tcs.TrySetCanceled(ct));   // cancel completes the TCS

    // Simulate external async event completing the TCS:
    _ = Task.Delay(50).ContinueWith(_ => tcs.TrySetResult("data"));

    string result = await tcs.Task;
    Console.WriteLine(result);
}

await WithSocketAsync(CancellationToken.None);
```

## Common Follow-up Questions

- How does `CancellationToken` flow across thread pool threads and `Task.Run` — is it automatically propagated?
- What is `CancellationTokenSource.CreateLinkedTokenSource` and when would you use more than two sources?
- How should you handle `OperationCanceledException` differently from other exceptions in a REST API?
- What is the cost of `ThrowIfCancellationRequested()` in a tight loop — should it be throttled?
- How does `IHostApplicationLifetime.ApplicationStopping` provide a cancellation token in ASP.NET Core hosted services?

## Common Mistakes / Pitfalls

- **Not passing the token down the call chain.** Cancellation only works if every method in the chain accepts and forwards the token. A single method that ignores the token creates a gap where cancellation has no effect.
- **Catching `OperationCanceledException` and swallowing it silently.** Log it (at Information level) and re-throw or handle it explicitly. Silent swallowing makes cancellation invisible in diagnostics.
- **Checking `IsCancellationRequested` but not throwing.** If the loop condition just exits without throwing, the caller receives a partial result with no indication of cancellation — which can be worse than an exception.
- **Not disposing `CancellationTokenSource`.** CTS registers callbacks on linked tokens; not disposing leaks those registrations. Always use `using` or explicitly dispose.
- **Using `Token.Register` without storing the returned `CancellationTokenRegistration` and disposing it.** Registration callbacks hold references to delegates — they can be a source of memory leaks in long-lived sources.

## References

- [Cancellation in Managed Threads — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads)
- [CancellationToken Struct — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.cancellationtoken)
- [CancellationTokenSource — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.cancellationtokensource)
- [Cooperative cancellation and cancellation tokens — Stephen Cleary (blog)](https://blog.stephencleary.com/2014/02/cancel-all-async-methods-upon-cancellation.html) (verify URL)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: task-whenall-vs-whenany.md](./task-whenall-vs-whenany.md)
