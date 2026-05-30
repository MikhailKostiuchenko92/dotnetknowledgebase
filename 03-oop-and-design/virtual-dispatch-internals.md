# Virtual Dispatch Internals

**Category:** OOP & Design / OOP Fundamentals
**Difficulty:** 🔴 Senior
**Tags:** `vtable`, `CLR`, `virtual-dispatch`, `JIT`, `performance`

## Question
> How does virtual and interface dispatch work under the CLR, what role do method tables play, and when can the JIT devirtualise a call?

## Short Answer
Virtual dispatch means the runtime selects the target method based on the object’s actual runtime type, not just the variable’s static type. Under the CLR, each type has metadata and method-table data that map virtual slots to concrete implementations, while interface calls typically require extra lookup work. The JIT can sometimes remove that indirection through devirtualisation when it proves the exact target, for example with sealed types, final methods, or strong type information at the call site.

## Detailed Explanation
### What virtual dispatch is
When you call a non-virtual instance method, the target is usually known from the static type. With a virtual method, the runtime must honor polymorphism: if a `Base` reference actually points to a `Derived` object, the `Derived` override must run.

The CLR solves this by giving each runtime type a **method table**. Conceptually, a method table contains type identity information plus slots for virtual members. Overrides replace inherited slots with new function pointers, so the runtime can jump to the correct implementation.

| Call kind | Dispatch decision | Typical cost |
| --- | --- | --- |
| Non-virtual | Known from static type | Lowest |
| Virtual | Lookup by runtime type slot | Extra indirection |
| Interface | Lookup by interface contract mapping | Usually more work |

### How method tables and interface dispatch work
For a virtual call, the object reference points to an instance whose header leads the CLR to its type information. From there, the runtime can find the method-table slot for the virtual member and invoke the right override.

Interface dispatch is slightly trickier because the object may implement many interfaces, and the interface method is not tied to one inheritance slot in the same simple way. The CLR uses interface maps and runtime support to resolve which concrete implementation satisfies the requested interface method. Modern runtimes also cache and optimize these lookups aggressively.

An interview-friendly nuance is that IL often uses `callvirt` even for non-virtual instance methods because it gives a null check. The presence of `callvirt` in IL does **not** automatically mean “full polymorphic dispatch.”

> Do not reduce the answer to “C# has a vtable like C++.” The high-level idea is similar, but the CLR has richer metadata, interface maps, and JIT-driven optimizations layered on top.

### Why the JIT can sometimes remove the cost
The JIT is not forced to keep every virtual call indirect. If it can prove the concrete target, it may **devirtualise** the call and turn it into a direct call, which then opens the door to inlining and other optimizations.

Common devirtualisation cases include:

- the receiver type is known exactly at the call site;
- the type or override is `sealed` and cannot be further overridden;
- generic specialization or profile-guided information narrows the target;
- tiered compilation re-JITs hot code with better knowledge.

This matters because the biggest performance win is often not the saved lookup itself, but the fact that a direct call can be inlined and optimized across method boundaries.

### Why it matters in design
Virtual dispatch is what makes classic OO polymorphism work, but it also introduces indirection. In most business code, that cost is tiny compared with I/O, allocation, database access, or serialization. Still, it matters in very hot loops, numeric code, serializers, and framework internals.

The design trade-off is straightforward:

| Choice | Benefit | Cost |
| --- | --- | --- |
| Virtual/interface-based design | Extensibility and substitution | Indirection, harder static reasoning |
| Sealed/direct calls | Simpler optimization story | Less extensibility |

Use polymorphism when the design benefit is real. Use sealing and simpler dispatch when behavior is stable and performance-sensitive. The mature answer is not “virtual is slow,” but “virtual enables polymorphism, and the runtime often optimizes more than people assume.”

## Code Example
```csharp
using System;

namespace OopAndDesign.VirtualDispatchInternals;

public interface IGreeter
{
    string Greet();
}

public class GreeterBase : IGreeter
{
    public virtual string Greet() => "Base";
}

public sealed class FriendlyGreeter : GreeterBase
{
    public override string Greet() => "Friendly"; // Sealed runtime type helps optimization.
}

public static class Program
{
    public static void Main()
    {
        GreeterBase throughBase = new FriendlyGreeter();
        IGreeter throughInterface = throughBase;

        Console.WriteLine($"Virtual dispatch: {throughBase.Greet()}");
        Console.WriteLine($"Interface dispatch: {throughInterface.Greet()}");

        var exact = new FriendlyGreeter();
        Console.WriteLine($"Exact type known: {exact.Greet()}"); // JIT may devirtualise/inline in hot code.
    }
}
```

## Common Follow-up Questions
- What is the difference between `call`, `callvirt`, and interface dispatch in IL?
- Why can `sealed` improve the JIT’s optimization opportunities?
- Why are interface calls often harder to optimize than virtual calls?
- What does devirtualisation enable besides removing one lookup?
- In which kinds of code does virtual dispatch overhead actually matter?
- How does tiered compilation affect dispatch optimization?

## Common Mistakes / Pitfalls
- Saying virtual dispatch is always expensive without considering JIT devirtualisation and inlining.
- Assuming `callvirt` in IL always means a virtual override lookup will happen.
- Overusing inheritance-based polymorphism in hot paths where composition or generics would be simpler.
- Sealing everything purely for performance without first measuring a real bottleneck.
- Forgetting that interface-heavy designs can hide control flow and complicate profiling.

## References
- [virtual (C# reference)](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/virtual)
- [interface (C# reference)](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/interface)
- [Compilation config settings (.NET)](https://learn.microsoft.com/dotnet/core/runtime-config/compilation)
- [Performance Improvements in .NET 6](https://devblogs.microsoft.com/dotnet/performance-improvements-in-net-6/)
