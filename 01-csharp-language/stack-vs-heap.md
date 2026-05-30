# Stack vs Heap

**Category:** C# / Type System / Memory
**Difficulty:** 🟢 Junior
**Tags:** `stack`, `heap`, `memory`, `allocation`, `value-types`, `reference-types`, `GC`

## Question

> What is the difference between the stack and the heap in .NET, and what kinds of data live in each?

Additional phrasings:
- *"Are value types always stored on the stack?"*
- *"What are the performance implications of stack vs heap allocation?"*

## Short Answer

The **stack** is a per-thread, contiguous memory region used for method call frames: local variables, return addresses, and parameters. The **heap** is a shared, GC-managed region where objects with longer lifetimes live. The common shorthand "value types → stack, reference types → heap" is an oversimplification: what really matters is *where the variable is declared*, not its type. A `struct` field inside a `class` lives on the heap with the class, and a boxed value type is always on the heap.

## Detailed Explanation

### The Stack

Each thread in a .NET process gets its own call stack (default 1 MB on .NET, 4 MB on some platforms). When a method is called:

- A **stack frame** is pushed containing the method's local variables, parameters, and the return address.
- Allocation is a single pointer decrement — extremely fast (O(1), no GC involved).
- When the method returns, the frame is popped instantly.

**Stack allocations are deterministic and fast** but constrained: deeply recursive code or very large stack-allocated arrays (`stackalloc`) can cause a `StackOverflowException`.

### The Heap (Managed Heap)

The managed heap is maintained by the .NET Garbage Collector (GC). It handles:

- Objects created with `new` for `class`, `object`, arrays, delegates, `string`.
- Boxed value types.
- Closures (the compiler-generated class that captures variables).

Allocation on the heap uses a **bump pointer** — fast in the best case, but the GC periodically needs to collect unreachable objects, compact memory, and suspend threads, which can cause pauses.

### The Oversimplification: "Value Types → Stack"

This rule holds only for **local variables of value types inside a method that are not captured**. The following situations put value types on the heap:

| Situation | Why on the heap |
|---|---|
| `struct` field inside a `class` | Lives with the containing object |
| Boxed value type (`object o = 42`) | Boxing wraps it in a heap object |
| Value type captured by a lambda/LINQ | Compiler generates a closure class on the heap |
| Value type in an array (`int[]`) | Arrays are reference types; their elements are on the heap |
| Value type as a `class` constructor argument stored in a field | Stored in the `class` instance on the heap |

### Visual: Call Stack vs Heap

```
Thread Call Stack                     Managed Heap
──────────────────────                ─────────────────────────────────
│ Main()                │             │ [string "Alice"]               │
│   name (ref) ─────────────────────▶ │                                │
│   age  (int) = 30    │             │ [Person object]                 │
│   p    (ref) ─────────────────────▶ │   Name ──▶ "Alice"             │
│                       │             │   Age  = 30                    │
│ Greet()               │             │                                │
│   local (int) = 42   │             └────────────────────────────────┘
└───────────────────────┘
```

### Span<T> and stackalloc

`stackalloc` lets you allocate an array on the stack in a `Span<T>`, avoiding heap allocation entirely for temporary buffers:

```csharp
Span<int> buffer = stackalloc int[16]; // stack allocation, no GC
```

Because `Span<T>` is a `ref struct`, the compiler ensures it cannot escape to the heap, keeping the safety guarantee.

[See: ref-struct-and-ref-fields.md](./ref-struct-and-ref-fields.md) for more on `ref struct` constraints.

### Performance Summary

| Property | Stack | Heap |
|---|---|---|
| Allocation speed | O(1), pointer move | Fast (bump pointer) but GC overhead |
| Deallocation | Automatic at method return | GC-driven |
| Size limit | ~1 MB per thread | Limited by process memory |
| Thread safety | Per-thread — no sharing | Shared — needs synchronization for mutable objects |
| Cache friendliness | Very high (sequential) | Lower (fragmentation possible) |

## Code Example

```csharp
// --- Local value types → stack ---
void Method()
{
    int x = 10;           // x lives on the stack frame of Method()
    double y = 3.14;      // same
}   // x and y vanish when Method() returns

// --- Struct field in a class → heap ---
class Container
{
    public int Value;     // int is a value type but lives on the heap
}                         // inside the Container object

// --- Captured variable → heap (compiler closure) ---
int counter = 0;          // counter is captured → moved to a compiler-generated class on the heap
Action increment = () => counter++;

// --- stackalloc: temporary buffer on the stack ---
void ProcessBytes(ReadOnlySpan<byte> input)
{
    Span<byte> buffer = stackalloc byte[64]; // no heap allocation
    input.CopyTo(buffer);
    // use buffer...
}   // buffer freed automatically at end of method

// --- Boxing: value type → heap ---
int v = 42;
object boxed = v;   // allocates a box object on the heap
```

## Common Follow-up Questions

- How does the GC decide when to collect objects from the heap?
- What is `stackalloc` and when should you use it instead of heap allocation?
- Why does capturing a local variable in a lambda cause it to move to the heap?
- What is the cost of a Gen0 garbage collection compared to just using the stack?
- How does the CLR's escape analysis relate to stack allocation of objects? (JVM comparison is common in interviews)

## Common Mistakes / Pitfalls

- **"Value types are always on the stack"** — false, as shown above. When explaining this in an interview, immediately clarify the exceptions.
- **Thinking stack allocation is always better.** For large or long-lived data, stack allocation is impractical. The default 1 MB stack limit means recursive algorithms with large local variables can overflow.
- **Ignoring the closure allocation.** Lambdas that capture variables generate a hidden heap allocation (the closure class), even if all captured variables are value types.
- **Confusing "lifetime" with "location."** An object's lifetime (how long it's reachable) is independent of whether it starts on the stack. Escape analysis in the JIT could, in theory, stack-allocate short-lived class instances (the JIT does this in limited cases, called **stack allocation of small objects**, but it's not guaranteed).
- **Thinking `struct` in a collection is "free."** An `int[]` stores ints directly (good cache locality), but an `ArrayList` (which stores `object[]`) boxes each int onto the heap.

## References

- [Managed Execution Process — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/managed-execution-process)
- [Stack and Heap — C# in Depth (Jon Skeet's notes)](https://jonskeet.uk/csharp/memory.html)
- [stackalloc expression — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc)
- [Garbage Collection Fundamentals — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
