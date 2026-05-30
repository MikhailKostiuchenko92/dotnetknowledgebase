# Weak References in .NET

**Category:** .NET Runtime / GC
**Difficulty:** 🟡 Middle
**Tags:** `WeakReference`, `WeakReference<T>`, `TrackResurrection`, `ConditionalWeakTable`, `cache`, `GC roots`

## Question

> What is a weak reference in .NET, and when would you use `WeakReference<T>` instead of a normal reference?

Also asked as:
> What is the difference between short and long weak references?
> When should you use `ConditionalWeakTable` instead of a dictionary with weak values?

## Short Answer

A weak reference lets you refer to an object without making it a GC root, so the object can still be collected under memory pressure. `WeakReference<T>` is the modern, type-safe API and is commonly used for opportunistic caches where recomputing the value is acceptable. Short weak references die when the object is collected; long weak references (`TrackResurrection`) can survive through finalization, but they are much rarer and harder to reason about.

## Detailed Explanation

### Strong vs Weak Reachability

A normal field, local variable, or collection entry is a **strong reference**. If an object is reachable through strong references from a GC root, it stays alive. A **weak reference** does not extend the object’s lifetime. The GC is free to reclaim the target as soon as no strong references remain.

That makes weak references useful only when the target is optional. If losing the object would break correctness, you need a strong reference instead.

| Reference kind | Keeps target alive? | Typical use |
|---|---|---|
| Strong reference | Yes | Normal application state |
| Weak reference | No | Caches, metadata side tables, observers |
| Pinned handle | Yes, and prevents movement | Interop only |

### `WeakReference<T>` vs `WeakReference`

`WeakReference<T>` is preferred in modern code because it is generic and avoids casts. The older non-generic `WeakReference` still exists mainly for legacy APIs.

The usual pattern is `TryGetTarget`:

```csharp
if (_cache.TryGetTarget(out ExpensiveValue? value))
{
    return value;
}
```

If the call fails, the object was already collected and you recompute or reload it.

### Short vs Long Weak References

By default, weak references are **short weak references**. They stop tracking the object once it is collected. If the type has a finalizer, a short weak reference becomes invalid before finalization completes.

A **long weak reference** is created with `TrackResurrection: true`. It can still refer to the object after finalization, up until the object is truly reclaimed. This is sometimes called a resurrection-tracking weak reference.

> **Warning:** Long weak references are rarely the right choice. They interact with finalization and resurrection, which already make object lifetime tricky.

### Cache Use Case

Weak references are best for **soft caches** where the program benefits from reuse but can cheaply regenerate values. A classic example is a parsed image, compiled regex wrapper, or reflection-derived metadata that can be rebuilt.

They are not a good replacement for capacity-limited caches like `MemoryCache`. If you need eviction policy, expiration, priority, or observability, use a real cache abstraction.

### `ConditionalWeakTable`

`ConditionalWeakTable<TKey, TValue>` solves a slightly different problem: attaching extra managed data to an object **without extending the key’s lifetime**. When the key dies, the associated value goes away automatically.

That is especially useful for frameworks, serializers, proxies, and extension-style metadata where you do not control the key type.

| Need | Better tool |
|---|---|
| Keep optional handle to one object | `WeakReference<T>` |
| Attach side data to a key object | `ConditionalWeakTable<TKey, TValue>` |
| Interop pinning or native handles | `GCHandle` |

### Difference from GC Handles

A `GCHandle` is a lower-level runtime handle API. A `GCHandleType.Normal` is a **strong handle**, not a weak one. `GCHandleType.Weak` and `WeakTrackResurrection` are runtime handle equivalents, but they are more interop-oriented and easier to misuse. For normal managed code, prefer `WeakReference<T>` or `ConditionalWeakTable`.

Related: [GC roots](./gc-roots.md).

## Code Example

```csharp
namespace DotNetRuntimeExamples;

internal sealed class ExpensiveDocument(string text)
{
    public string Text { get; } = text;
}

internal sealed class DocumentCache
{
    private WeakReference<ExpensiveDocument>? _cached;

    public ExpensiveDocument GetOrCreate()
    {
        // Try to reuse the object if the GC has not reclaimed it.
        if (_cached is not null && _cached.TryGetTarget(out ExpensiveDocument? existing))
        {
            return existing;
        }

        ExpensiveDocument created = new("Generated at " + DateTime.UtcNow);
        _cached = new WeakReference<ExpensiveDocument>(created);
        return created;
    }
}

internal static class Program
{
    private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<object, string> Notes = new();

    private static void Main()
    {
        var cache = new DocumentCache();
        ExpensiveDocument doc = cache.GetOrCreate();

        object owner = new();
        Notes.Add(owner, "Attached metadata without extending owner lifetime.");

        Console.WriteLine(doc.Text);
        Console.WriteLine(Notes.TryGetValue(owner, out string? note) ? note : "No note");
    }
}
```

## Common Follow-up Questions

- Why is `WeakReference<T>.TryGetTarget` preferable to reading `Target` directly?
- When would `ConditionalWeakTable` be better than `ConcurrentDictionary`?
- What does `TrackResurrection` actually change?
- How do weak references differ from `GCHandleType.Weak`?
- Why are weak references not a good general-purpose cache policy?
- Can a weak reference prevent a memory leak caused by static events?

## Common Mistakes / Pitfalls

- Treating weak references as if they guarantee object reuse; the target may disappear at any time.
- Building a critical cache on top of weak references instead of using `MemoryCache` or explicit size limits.
- Using `TrackResurrection` without understanding finalization and resurrection semantics.
- Forgetting that a temporary strong reference in local code can keep the target alive longer than expected.
- Using `WeakReference` when `WeakReference<T>` would be clearer and type-safe.

## References

- [WeakReference<T>](https://learn.microsoft.com/dotnet/api/system.weakreference-1)
- [WeakReference](https://learn.microsoft.com/dotnet/api/system.weakreference)
- [ConditionalWeakTable<TKey,TValue>](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.conditionalweaktable-2)
- [Fundamentals of garbage collection](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
