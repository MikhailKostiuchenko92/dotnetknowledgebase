# `Interlocked` Operations

**Category:** C# / Threading / Concurrency
**Difficulty:** Middle
**Tags:** `Interlocked`, `atomic`, `CompareExchange`, `volatile`, `lock-free`

## Question
> What does `Interlocked` do in .NET, which operations are atomic, and when should you use it instead of `lock` or `volatile`?

Also asked as:
- "How do `Interlocked.Increment` and `CompareExchange` help avoid race conditions?"
- "What is the ABA problem, and why does `CompareExchange` not magically solve it?"

## Short Answer
`Interlocked` provides atomic read-modify-write operations such as increment, decrement, exchange, add, and compare-and-swap on supported primitive values and references. It is ideal for simple counters, flags, and lock-free update loops where taking a full monitor would be unnecessary overhead. `volatile` only affects visibility and ordering for reads and writes; it does not make compound operations like `x++` atomic, while `Interlocked` does.

## Detailed Explanation

### What atomic means here
An operation is atomic when other threads cannot observe it half-complete. For example, `x++` looks simple in C#, but it is actually three logical steps:

1. read the current value
2. add one
3. write the new value

If two threads do that at the same time, updates can be lost. `Interlocked.Increment(ref x)` performs the full read-modify-write atomically.

### Common `Interlocked` operations
`Interlocked` is designed for small low-level shared-state transitions.

| Operation | Use case |
|---|---|
| `Increment` / `Decrement` | Thread-safe counters |
| `Add` | Accumulate totals atomically |
| `Exchange` | Swap in a new value or flag |
| `CompareExchange` | Compare-and-swap, optimistic updates |
| `Read` | Atomic read for `long` in older compatibility scenarios |

### `Interlocked` vs `volatile`
This distinction matters a lot in interviews.

- `volatile` means reads and writes must not be freely cached or reordered across that field in certain ways.
- `Interlocked` performs an atomic update and also provides appropriate memory ordering semantics for that operation.

So if you need to publish a boolean stop flag, `volatile` may be enough. If you need to increment a counter, add to a total, or swap references conditionally, use `Interlocked`.

> **Warning:** `volatile` does not make `count++`, `count += value`, or `if (x == null) x = ...` safe.

### `CompareExchange` and lock-free loops
`CompareExchange` is the core compare-and-swap primitive. It says: "replace the target with my new value only if it still equals the expected old value." If another thread changed it first, the operation fails and you retry.

That enables optimistic loops such as atomic maximum updates, single initialization, or lock-free structure manipulation.

### The ABA problem
`CompareExchange` compares values, not history. The ABA problem means a location changes from A to B and back to A between your read and your compare-and-swap. Your CAS sees A and assumes nothing changed, even though something important happened in between.

This is especially relevant in lock-free linked structures and freelists. Typical mitigations include version stamps, sequence numbers, or higher-level concurrent collections rather than hand-rolled lock-free algorithms.

### When `Interlocked` is a good fit
Use it when the shared state transition is tiny and well-defined:

- counters and metrics
- one-time publication flags
- swapping a reference atomically
- optimistic update loops for a single field

Once you need to coordinate several fields together or protect invariants across multiple steps, a `lock` is usually clearer and safer.

### Memory ordering and publication
Another subtle benefit of `Interlocked` is that it is not merely arithmetic. The operation also creates the ordering needed for safe publication around that variable. That is why `Interlocked.Exchange` is often used to publish a reference or flip a state machine value, not just increment numbers.

Still, that guarantee applies to the atomic operation you are performing, not to an entire multi-step protocol. If the correctness of your algorithm depends on several fields moving together, a monitor or another higher-level primitive is usually easier to prove correct.

### Why lock-free is not automatically better
Interview candidates sometimes present `Interlocked` as a faster replacement for locks in all cases. In reality, lock-free code often trades blocking for retries, cache invalidation traffic, and subtle reasoning complexity. Under high contention, a compare-and-swap loop may spin many times before succeeding. For a simple multi-step critical section, the supposedly "more advanced" approach can be slower and definitely harder to maintain.

### Good interview framing
A strong answer usually says: use `Interlocked` for single-variable atomic transitions, use `volatile` for simple visibility-only flags, and use `lock` when you need to preserve a broader invariant. That framing shows you understand both capability and scope.

It also shows that you understand *why* the primitive exists instead of treating concurrency APIs as interchangeable performance toggles.

> **Tip:** choose the simplest correct primitive. Lock-free code is not automatically faster; it is often just harder to reason about.

## Code Example
```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

int counter = 0;
long total = 0;
string? publishedValue = null;

Task[] tasks = new Task[4];
for (int i = 0; i < tasks.Length; i++)
{
    tasks[i] = Task.Run(() =>
    {
        for (int j = 0; j < 10_000; j++)
        {
            Interlocked.Increment(ref counter);    // Atomic increment.
            Interlocked.Add(ref total, 2);         // Atomic add.
        }

        // Publish a value only once. Only one thread wins.
        Interlocked.CompareExchange(ref publishedValue, "initialized", comparand: null);
    });
}

await Task.WhenAll(tasks);
Console.WriteLine($"Counter: {counter}");
Console.WriteLine($"Total: {total}");
Console.WriteLine($"Published value: {publishedValue}");

// Optimistic CompareExchange loop: keep the maximum value seen.
int max = 0;
void UpdateMax(int candidate)
{
    while (true)
    {
        int snapshot = max;
        if (candidate <= snapshot)
        {
            return; // Nothing to update.
        }

        // Replace only if nobody changed max since we read snapshot.
        int original = Interlocked.CompareExchange(ref max, candidate, snapshot);
        if (original == snapshot)
        {
            return; // Success.
        }
    }
}

Parallel.ForEach(new[] { 5, 17, 11, 42, 9 }, UpdateMax);
Console.WriteLine($"Max: {max}");
```

## Common Follow-up Questions
- When should you use `Interlocked` instead of a `lock`?
- Why is `Interlocked.Add` safe while `+=` is not?
- What extra problems appear when building lock-free linked structures with `CompareExchange`?
- How does `Interlocked` relate to [volatile-and-memory-barriers.md](./volatile-and-memory-barriers.md)?
- When is a `ConcurrentDictionary` or other higher-level collection a better choice than manual atomics?

## Common Mistakes / Pitfalls
- Using `volatile` and assuming it makes compound updates atomic.
- Writing a `CompareExchange` loop with side effects inside the retry block, causing duplicate work.
- Choosing `Interlocked` for multi-field invariants that would be clearer with a `lock`.
- Ignoring the ABA problem in custom lock-free data structures.
- Forgetting that lock-free code can still be slower if contention, retries, or cache traffic are high.

## References
- [Interlocked Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.interlocked)
- [Managed threading best practices — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices)
- [Volatile keyword — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/volatile)
- [See: volatile-and-memory-barriers.md](./volatile-and-memory-barriers.md)
- [See: lock-and-monitor.md](./lock-and-monitor.md)
- [See: concurrent-collections.md](./concurrent-collections.md)
