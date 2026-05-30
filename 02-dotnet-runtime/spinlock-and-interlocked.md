# When Should You Use SpinLock, SpinWait, and Interlocked?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Senior  
**Tags:** `spinlock`, `spinwait`, `interlocked`, `cas`, `lock-free`

## Question
> What are `SpinLock`, `SpinWait`, and `Interlocked`, and when are they better than a normal `lock`?
>
> How does `Interlocked.CompareExchange` enable lock-free algorithms?
>
> What is the ABA problem, and why does it matter for compare-and-swap loops?

## Short Answer
`Interlocked` provides atomic CPU-level read-modify-write operations such as `Increment`, `Exchange`, and `CompareExchange`, and it is the foundation of most lock-free data structures in .NET. `SpinLock` and `SpinWait` avoid an immediate kernel-backed block by repeatedly checking for progress in user mode, which only makes sense when the critical section is extremely short. Spinning can beat blocking when the expected wait is shorter than a context switch, but used carelessly it burns CPU and can make contention much worse.

## Detailed Explanation
### `Interlocked`: the primitive everything else builds on
If an interviewer asks for the most fundamental synchronization API in managed code, `Interlocked` is a strong answer. It exposes atomic operations directly backed by CPU instructions or equivalent runtime support:

- `Increment`, `Decrement`, `Add`
- `Exchange`
- `CompareExchange`

`CompareExchange` is the most important one. It means “replace the current value with a new value, but only if the current value still equals the expected old value.” That is compare-and-swap (CAS). A lock-free loop typically reads a shared value, computes a candidate replacement, then retries with `CompareExchange` until it wins.

### `SpinLock`: no kernel transition, but only for tiny critical sections
`SpinLock` is a value type that busy-waits in a tight loop until it acquires the lock instead of immediately blocking the thread. That avoids the overhead of putting the thread to sleep and waking it later. The trade-off is obvious: while spinning, the CPU is doing nothing useful except waiting.

That can still be a win when the lock hold time is smaller than the cost of a context switch, often on the order of roughly 1–5 microseconds depending on platform and load. If the critical section might perform I/O, allocate heavily, block, or call arbitrary code, `SpinLock` is the wrong tool.

> `SpinLock` is a mutable `struct`. Accidentally copying it creates a second independent lock state, which is a serious correctness bug.

### `SpinWait`: adaptive backoff helper
`SpinWait` is not itself a lock. It is a helper that implements an adaptive waiting strategy: first it spins, then it yields, and eventually it sleeps. That gives you a better retry loop than `while (...) { }` because it reduces wasted CPU while still responding quickly when the condition is likely to flip soon.

This is useful in custom coordination code or CAS loops where a little backoff is healthier than hammering memory as fast as possible.

### ABA problem
CAS algorithms can fail in ways a simple value comparison does not reveal. Suppose thread A reads pointer value `A`, gets interrupted, thread B changes the value from `A` to `B` and back to `A`, and then thread A resumes. A CAS sees the same old value and succeeds, even though the logical state changed in between. That is the ABA problem.

The standard mitigation is to pair the value with a version stamp, sequence number, or hazard-pointer-like scheme so that “same value, changed history” is still detectable.

### When spinning is appropriate
Spinning is appropriate only when:

| Good fit | Bad fit |
| --- | --- |
| Critical section is extremely short | Critical section may block or run arbitrary code |
| Contention is low and transient | Contention is sustained |
| You are on hot low-level runtime or library code | Typical business application code |
| Measurements justify it | It only “sounds faster” |

In most application code, a normal `lock`, `SemaphoreSlim`, or higher-level collection is the safer default.

### Practical mental model
Use `Interlocked` for counters, publication, one-word state transitions, and CAS loops. Use `SpinWait` for adaptive retry logic. Use `SpinLock` only when you have measured a very short critical section and cannot afford blocking overhead.

For visibility and ordering guarantees, see [Volatile and Memory Barriers](./volatile-and-memory-barriers.md).

## Code Example
```csharp
namespace RuntimeSamples.SpinAndInterlocked;

internal static class Program
{
    private static SpinLock _spinLock = new(enableThreadOwnerTracking: false);
    private static int _sharedCounter;
    private static int _maxObserved;

    public static void Main()
    {
        Parallel.For(0, 10_000, i =>
        {
            // Fast atomic increment without taking a monitor lock.
            var newValue = Interlocked.Increment(ref _sharedCounter);

            // CAS loop: publish the maximum value seen so far.
            var spinner = new SpinWait();
            while (true)
            {
                var currentMax = Volatile.Read(ref _maxObserved);
                if (newValue <= currentMax)
                {
                    break;
                }

                if (Interlocked.CompareExchange(ref _maxObserved, newValue, currentMax) == currentMax)
                {
                    break; // CAS succeeded.
                }

                spinner.SpinOnce(); // Back off adaptively before retrying.
            }

            var lockTaken = false;
            try
            {
                _spinLock.Enter(ref lockTaken); // Only safe because the critical section is tiny.
                _sharedCounter += 0; // Placeholder for a few CPU instructions, not blocking work.
            }
            finally
            {
                if (lockTaken)
                {
                    _spinLock.Exit();
                }
            }
        });

        Console.WriteLine($"Counter: {_sharedCounter}, Max observed: {_maxObserved}");
    }
}
```

## Common Follow-up Questions
- Why is `CompareExchange` more powerful than `Increment` or `Exchange`?
- What kinds of bugs can the ABA problem cause?
- Why is `SpinLock` a `struct`, and why is copying it dangerous?
- When does a blocking `lock` usually beat spinning?
- What role does `SpinWait` play in a lock-free retry loop?

## Common Mistakes / Pitfalls
- Using `SpinLock` around long or blocking operations.
- Copying a `SpinLock` struct and accidentally protecting nothing.
- Assuming `Interlocked` alone solves multi-step invariants across several variables.
- Writing a hot CAS loop with no backoff, causing excessive cache traffic.
- Ignoring ABA in custom lock-free data structures.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.spinlock
- https://learn.microsoft.com/dotnet/api/system.threading.spinwait
- https://learn.microsoft.com/dotnet/api/system.threading.interlocked
- https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices
