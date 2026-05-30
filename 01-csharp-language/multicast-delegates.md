# Multicast Delegates

**Category:** C# / Delegates, Events, Lambdas
**Difficulty:** Middle
**Tags:** `delegate`, `multicast`, `invocation-list`, `event`, `+=`

## Question

> What is a multicast delegate and how does its invocation list work? What happens to return values and exceptions when multiple methods are subscribed?

Also asked as:
- "If I combine two delegates with `+`, what happens when the combined delegate is invoked?"
- "How do you iterate the invocation list of a delegate manually, and why would you?"

## Short Answer

Every C# delegate is multicast: it internally maintains an ordered list of method references called the *invocation list*. When invoked, all methods are called in order. If the delegate has a non-void return type, only the return value of the **last** method is returned; all others are silently discarded. If any subscriber throws, invocation stops at that point unless you iterate the invocation list manually and handle exceptions per subscriber.

## Detailed Explanation

### The Invocation List

`System.MulticastDelegate` stores an `object[] _invocationList` (for two or more targets) or a direct method pointer (for a single target) as an optimization. The `+`/`+=` operator creates a **new** delegate object whose list is the concatenation of both lists — delegates themselves are immutable.

```
del += Method1;   // new delegate: [Method1]
del += Method2;   // new delegate: [Method1, Method2]
del += Method1;   // new delegate: [Method1, Method2, Method1]  — duplicates allowed!
del -= Method1;   // new delegate: [Method2, Method1]  — removes LAST occurrence
```

Removal with `-=` removes the last (rightmost) matching entry in the invocation list using `Equals` comparison. Removing a method that was never added is silently ignored.

### Return Values Are Discarded for All But the Last

```csharp
Func<int> combined = () => 1;
combined += () => 2;
combined += () => 3;

int result = combined();  // returns 3 — values 1 and 2 are gone
```

This is rarely what you want for non-void delegates. If every return value matters, iterate `GetInvocationList()` manually.

### Exceptions Break the Chain

By default, if a subscriber throws, the exception propagates immediately and remaining subscribers **never run**:

```csharp
Action chain = () => Console.WriteLine("A");
chain += () => throw new InvalidOperationException("boom");
chain += () => Console.WriteLine("C");

chain();   // prints "A", throws — "C" never executes
```

To guarantee all subscribers run regardless of errors, iterate the invocation list:

```csharp
foreach (Delegate subscriber in chain.GetInvocationList())
{
    try { subscriber.DynamicInvoke(); }
    catch (Exception ex) { Console.WriteLine($"Subscriber failed: {ex.Message}"); }
}
```

### Immutability and Thread Safety

Because `+=`/`-=` produce new objects (they don't mutate), a standard pattern for thread-safe invocation is:

```csharp
private Action? _handler;

public void Subscribe(Action h)   => Interlocked.CompareExchange(ref _handler, _handler + h, _handler);
public void Unsubscribe(Action h) => Interlocked.CompareExchange(ref _handler, _handler - h, _handler);

public void Raise()
{
    // Read once into a local — safe even if _handler is modified concurrently
    _handler?.Invoke();
}
```

The `event` keyword bakes in this pattern (plus access restriction). See [events-vs-delegates.md](./events-vs-delegates.md).

### `GetInvocationList()` — When to Use It

| Scenario | Use `GetInvocationList()` |
|---|---|
| Need **all** return values | ✅ iterate and collect each result |
| Need **isolated** exception handling per subscriber | ✅ wrap each call in try/catch |
| Need to **count** subscribers | ✅ `.Length` on the returned array |
| Need to invoke with **custom scheduling** per subscriber | ✅ |
| Normal event fan-out with void subscribers | ❌ direct `.Invoke()` is fine |

### Duplicate Subscriptions

The same method reference can be added multiple times:

```csharp
Action del = SomeMethod;
del += SomeMethod;   // invocation list: [SomeMethod, SomeMethod]
del();               // SomeMethod runs twice
```

The `event` wrapper does not prevent duplicates. If idempotency matters, check `Array.IndexOf(del.GetInvocationList(), (Action)SomeMethod)` before subscribing, or use a `HashSet<Action>` to track subscribers.

## Code Example

```csharp
using System;

// --- Basic multicast ---
Action greet = () => Console.WriteLine("Hello from A");
greet += () => Console.WriteLine("Hello from B");
greet += () => Console.WriteLine("Hello from C");

greet();
// Hello from A
// Hello from B
// Hello from C

// --- Return value — only last survives ---
Func<int> counter = () => 1;
counter += () => 2;
counter += () => 3;

int result = counter();          // 3 (not 1 or 2)
Console.WriteLine(result);

// --- Collecting all return values via invocation list ---
int[] all = Array.ConvertAll(
    counter.GetInvocationList(),
    d => ((Func<int>)d)());      // [1, 2, 3]
Console.WriteLine(string.Join(", ", all));

// --- Exception isolation ---
Action chain = () => Console.Write("A ");
chain += () => throw new Exception("boom");
chain += () => Console.Write("C ");

foreach (Delegate sub in chain.GetInvocationList())
{
    try { ((Action)sub)(); }
    catch (Exception ex) { Console.Write($"[err:{ex.Message}] "); }
}
// A  [err:boom]  C

// --- Duplicate detection ---
Action method = () => Console.WriteLine("once");
bool alreadySubscribed = Array.Exists(
    (method + method)?.GetInvocationList() ?? [],
    d => ReferenceEquals(d, (Action)method));
Console.WriteLine(alreadySubscribed);   // True
```

## Common Follow-up Questions

- How does the `event` keyword restrict access to the invocation list versus a plain delegate field?
- What is the `EventHandlerList` class and when is it useful on types with many events?
- How does unsubscribing a lambda work — why does `del -= (x => x)` often silently fail?
- What is `Delegate.Combine`/`Delegate.Remove` — when would you call them directly?
- How does async `await` interact with multicast delegates?

## Common Mistakes / Pitfalls

- **Expecting the return value of every subscriber to be visible.** Only the last subscriber's return value is returned; intermediate values are silently lost. This is a common source of bugs in observer or chain-of-responsibility patterns.
- **Not guarding against exceptions from one subscriber breaking others.** A throwing subscriber aborts the entire chain. Always isolate exceptions when subscriber reliability matters (e.g., plugin architectures).
- **Assuming `-=` prevents double-subscription.** `-=` removes one occurrence, so if a method was added twice, one instance remains after one `-=`.
- **Capturing a multicast delegate in a closure without snapshotting it.** If the delegate field is modified after the closure captures it, the closure sees the old value — or the new one, depending on whether it captured the variable or the value.
- **Calling `GetInvocationList()` in a tight loop.** It allocates a new array each call. Cache the snapshot array if you iterate frequently.
- **Using non-void return delegates as events.** This is a design smell; events should almost always be `void`. If aggregation is needed, redesign with a collection or result object.

## References

- [MulticastDelegate.GetInvocationList — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.multicastdelegate.getinvocationlist)
- [Delegates — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/delegates/)
- [How to combine delegates (multicast delegates) — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/delegates/how-to-combine-delegates-multicast-delegates)
- [See: delegates-explained.md](./delegates-explained.md)
- [See: events-vs-delegates.md](./events-vs-delegates.md)
