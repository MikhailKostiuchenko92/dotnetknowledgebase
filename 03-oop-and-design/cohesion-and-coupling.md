# Cohesion and Coupling

**Category:** OOP & Design / Design Metrics
**Difficulty:** 🔴 Senior
**Tags:** `cohesion`, `coupling`, `architecture`, `design-metrics`

## Question
> How do cohesion and coupling affect software design, and what do afferent and efferent coupling tell you about an architecture?

## Short Answer
Cohesion describes how strongly the responsibilities inside a module belong together, while coupling describes how strongly modules depend on each other. High cohesion and appropriately low coupling usually produce code that is easier to understand, test, and change. At an architectural level, afferent coupling measures how many other modules depend on a module, and efferent coupling measures how many modules it depends on, which helps you reason about stability and change impact.

## Detailed Explanation
### Cohesion: how well the inside fits together
Cohesion is an internal quality. A cohesive class or module groups behavior that serves one clear purpose. Low cohesion means the module is a grab bag of unrelated tasks. Senior-level discussions often go beyond “high is good” and talk about kinds of cohesion.

| Cohesion type | Meaning | Typical quality |
| --- | --- | --- |
| Functional | All parts contribute to one focused task | Highest |
| Sequential | Output of one part becomes input to the next | Good when modeling pipelines |
| Communicational | Parts operate on the same data | Context-dependent |
| Temporal | Things grouped because they happen at the same time | Weaker |
| Coincidental | Unrelated things grouped arbitrarily | Worst |

Functional cohesion is ideal for domain services like pricing, validation, or authorization. Sequential cohesion is normal in workflows and ETL-style pipelines. Temporal cohesion often appears in startup code, where you group initialization tasks simply because they run at application boot. That can be acceptable, but it is weaker because timing, not purpose, is the organizing principle.

### Coupling: how strongly modules pull on each other
Coupling is an external quality. It measures how much one module knows about, depends on, or is affected by another. Not all coupling is bad — software must collaborate — but unnecessary coupling increases ripple effects.

There are many forms: data coupling, control coupling, inheritance coupling, temporal coupling, and runtime coupling through shared infrastructure. In practice, the most useful architectural view is dependency direction.

### Afferent and efferent coupling
Robert Martin popularized two package-level metrics:

| Metric | Meaning | Why it matters |
| --- | --- | --- |
| Afferent coupling (Ca) | Number of modules depending on this module | High Ca suggests responsibility and stability |
| Efferent coupling (Ce) | Number of modules this module depends on | High Ce suggests volatility and change surface |
| Instability (I) | `Ce / (Ca + Ce)` | Closer to 1 means more unstable |

A core domain module often should have higher afferent coupling and lower efferent coupling: many modules depend on it, but it depends on little else. A UI or infrastructure adapter may legitimately have higher efferent coupling because it talks to many surrounding systems and is expected to change more often.

> Warning: these metrics are signals, not verdicts. A high number is not automatically bad if it matches the architectural role of the module.

### Why these concepts matter in real systems
High cohesion lowers cognitive load. When a developer opens a class named `InvoiceTaxCalculator`, they should see tax calculation logic, not tax plus email plus PDF export. Low coupling limits blast radius. If the notification provider changes, you want to update the notification module without breaking order validation.

At the architecture level, coupling metrics help you spot bad dependency direction. If your domain module depends on web controllers, EF Core details, and cloud SDKs, the design is upside down. If a supposedly “shared” utility package has massive efferent coupling, it is not truly foundational.

### Trade-offs and when to be careful
Pursuing perfect metrics can lead to artificial abstractions. Sometimes a little extra coupling is acceptable to keep code simpler or avoid needless indirection. Similarly, temporal cohesion is not always wrong; startup composition roots are naturally time-oriented. What matters is whether the design reflects the true axes of change.

In interviews, strong answers combine the theory with architectural judgment: aim for functional cohesion, keep dependency direction intentional, and use afferent/efferent coupling to understand stability, not as a simplistic scoreboard.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace OopAndDesign.CohesionCouplingSample;

// Functional cohesion: one focused responsibility.
public sealed class InvoiceTaxCalculator
{
    public decimal Calculate(decimal netAmount) => netAmount * 0.20m;
}

// Sequential cohesion: each step feeds the next.
public sealed class ImportPipeline
{
    public string Run(string rawInput)
    {
        var trimmed = rawInput.Trim();           // Step 1
        var normalized = trimmed.ToUpperInvariant(); // Step 2 uses step 1 output
        return $"Imported: {normalized}";       // Step 3 uses step 2 output
    }
}

// Temporal cohesion: grouped because tasks happen at startup.
public sealed class StartupTasks
{
    public void Run()
    {
        Console.WriteLine("Warming cache...");
        Console.WriteLine("Applying migrations...");
        Console.WriteLine("Loading feature flags...");
    }
}

public sealed record Module(string Name, string[] DependsOn);

public static class CouplingMetrics
{
    public static int GetAfferentCoupling(string moduleName, IEnumerable<Module> modules) =>
        modules.Count(module => module.DependsOn.Contains(moduleName, StringComparer.OrdinalIgnoreCase));

    public static int GetEfferentCoupling(string moduleName, IEnumerable<Module> modules) =>
        modules.Single(module => module.Name.Equals(moduleName, StringComparison.OrdinalIgnoreCase)).DependsOn.Length;
}

public static class Program
{
    public static void Main()
    {
        var modules = new List<Module>
        {
            new("Domain", []),
            new("Application", ["Domain"]),
            new("Infrastructure", ["Application", "Domain"]),
            new("WebApi", ["Application"])
        };

        Console.WriteLine($"Domain Ca: {CouplingMetrics.GetAfferentCoupling("Domain", modules)}");
        Console.WriteLine($"Domain Ce: {CouplingMetrics.GetEfferentCoupling("Domain", modules)}");
        Console.WriteLine(new ImportPipeline().Run(" invoice-42 "));
    }
}
```

## Common Follow-up Questions
- What is the difference between afferent and efferent coupling?
- What types of cohesion are strongest and weakest?
- How does instability relate to package design?
- Can high coupling ever be acceptable?
- How would you detect low cohesion in a large C# class?
- How do these metrics connect to Clean Architecture?

## Common Mistakes / Pitfalls
- Saying “low coupling everywhere” without considering necessary collaboration.
- Treating temporal cohesion as always wrong, even in startup or batch orchestration code.
- Using coupling metrics mechanically without understanding module responsibility.
- Confusing afferent coupling with outbound dependencies and efferent coupling with inbound ones.
- Ignoring logical coupling from change history and focusing only on static references.

## References
- [Architectural principles for modern web applications with Azure](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Design principles for Azure applications](https://learn.microsoft.com/en-us/azure/architecture/guide/design-principles/)
- [Object-oriented programming fundamentals in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)
- [Shotgun Surgery code smell](https://refactoring.guru/smells/shotgun-surgery)
