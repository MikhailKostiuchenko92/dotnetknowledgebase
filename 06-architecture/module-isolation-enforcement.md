# Module Isolation Enforcement

**Category:** Architecture / Modular Monolith
**Difficulty:** 🔴 Senior
**Tags:** `NetArchTest`, `architectural-tests`, `module-isolation`, `dependency-constraints`, `CI`, `InternalsVisibleTo`

## Question

> How do you enforce module isolation boundaries in a .NET modular monolith? Walk through using C# access modifiers, `InternalsVisibleTo`, and NetArchTest rules as CI gates.

## Short Answer

Three layers of enforcement: (1) **C# `internal` access modifier** — implementation classes are `internal` by default, only contracts are `public`. (2) **`InternalsVisibleTo`** — allows test projects to access internals without making them public. (3) **NetArchTest architectural tests in CI** — assert dependency rules at build time (e.g., "Inventory must not reference Orders.Application namespace"). Fail the build if any rule is violated. This makes incorrect dependencies compile-time or test-time failures rather than review surprises.

## Detailed Explanation

### Layer 1: C# Access Modifiers

```csharp
// Orders module — enforce via visibility
namespace MyApp.Orders;

// PUBLIC: only what other modules or the bootstrapper need
public static class OrdersModule { ... }          // ← DI registration
public interface IOrdersModule { ... }            // ← public contract
public record PlaceOrderRequest(int CustomerId);  // ← public DTO
public record OrderDto(int Id, decimal Total);    // ← public DTO

// INTERNAL: everything else — no other project can reference these
internal class Order : AggregateRoot { ... }                    // ← domain aggregate
internal class PlaceOrderHandler : IRequestHandler<...> { ... } // ← application handler
internal class OrderRepository : IOrderRepository { ... }       // ← infrastructure
internal class OrdersDbContext : DbContext { ... }              // ← data access

// File-scoped namespace + internal: all types in the file are internal
namespace MyApp.Orders.Application;
internal class GetOrderByIdQueryHandler : IRequestHandler<GetOrderByIdQuery, OrderDto?>
{ ... }
```

### Layer 2: InternalsVisibleTo for Tests

```csharp
// MyApp.Orders.csproj — allow test project to access internals
// Without this, unit tests can't access internal aggregate/handler classes

// Option A: AssemblyInfo.cs
[assembly: InternalsVisibleTo("MyApp.Orders.Tests")]
[assembly: InternalsVisibleTo("MyApp.ArchTests")]

// Option B: csproj
<ItemGroup>
  <InternalsVisibleTo Include="MyApp.Orders.Tests" />
  <InternalsVisibleTo Include="MyApp.ArchTests" />
</ItemGroup>

// Important: InternalsVisibleTo does NOT expose internals to other module projects
// MyApp.Inventory cannot reference internal Orders types — only test projects can
```

### Layer 3: NetArchTest Architectural Tests

```csharp
// NuGet: NetArchTest.Rules
// arch-tests/MyApp.ArchTests/ModuleBoundaryTests.cs

public class ModuleBoundaryTests
{
    private static readonly Assembly OrdersAssembly    = typeof(OrdersModule).Assembly;
    private static readonly Assembly InventoryAssembly = typeof(InventoryModule).Assembly;

    // Rule 1: Inventory must not reference Orders internal namespaces
    [Fact]
    public void Inventory_MustNot_Reference_Orders_Internals()
    {
        var result = Types.InAssembly(InventoryAssembly)
            .Should()
            .NotHaveDependencyOn("MyApp.Orders.Application")
            .And()
            .NotHaveDependencyOn("MyApp.Orders.Domain")
            .And()
            .NotHaveDependencyOn("MyApp.Orders.Infrastructure")
            .GetResult();

        Assert.True(result.IsSuccessful,
            $"Inventory references Orders internals:\n" +
            string.Join("\n", result.FailingTypes?.Select(t => t.FullName) ?? []));
    }

    // Rule 2: Domain layer must not reference infrastructure
    [Fact]
    public void Orders_Domain_MustNot_Reference_Infrastructure()
    {
        var result = Types.InAssembly(OrdersAssembly)
            .That().ResideInNamespace("MyApp.Orders.Domain")
            .Should()
            .NotHaveDependencyOn("MyApp.Orders.Infrastructure")
            .And()
            .NotHaveDependencyOn("Microsoft.EntityFrameworkCore")
            .GetResult();

        Assert.True(result.IsSuccessful,
            $"Domain references infrastructure: {string.Join(", ", result.FailingTypes?.Select(t => t.Name) ?? [])}");
    }

    // Rule 3: All application-layer classes should be internal
    [Fact]
    public void Orders_Application_Classes_Should_Be_Internal()
    {
        var result = Types.InAssembly(OrdersAssembly)
            .That().ResideInNamespace("MyApp.Orders.Application")
            .Should()
            .NotBePublic()
            .GetResult();

        Assert.True(result.IsSuccessful,
            $"These application classes should be internal: {string.Join(", ", result.FailingTypes?.Select(t => t.Name) ?? [])}");
    }

    // Rule 4: Only Contracts namespace should be public
    [Fact]
    public void Orders_OnlyContractTypes_Should_BePublic()
    {
        var result = Types.InAssembly(OrdersAssembly)
            .That().ArePublic()
            .Should()
            .ResideInNamespaceStartingWith("MyApp.Orders.Contracts")
            .Or()
            .ResideInNamespace("MyApp.Orders") // ← OrdersModule static class
            .GetResult();

        Assert.True(result.IsSuccessful,
            $"Unexpected public types outside Contracts: {string.Join(", ", result.FailingTypes?.Select(t => t.Name) ?? [])}");
    }
}
```

### CI Gate

```yaml
# .github/workflows/ci.yml — run arch tests on every PR
jobs:
  arch-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.0.x' }
      - run: dotnet test arch-tests/MyApp.ArchTests/ --logger trx
      # ↑ Fails PR if any architectural rule is violated
```

## Code Example

```csharp
// Verify all module rules in a single parameterized test
public class AllModulesIsolationTest
{
    public static IEnumerable<object[]> ModulePairs => new[]
    {
        new object[] { typeof(OrdersModule).Assembly,    "MyApp.Inventory" },
        new object[] { typeof(InventoryModule).Assembly, "MyApp.Orders"    },
        new object[] { typeof(CustomersModule).Assembly, "MyApp.Orders"    },
    };

    [Theory, MemberData(nameof(ModulePairs))]
    public void Module_ShouldNotReference_AnotherModule_Internals(
        Assembly assembly, string forbiddenNamespacePrefix)
    {
        var internalNamespaces = new[] { "Application", "Domain", "Infrastructure" }
            .Select(n => $"{forbiddenNamespacePrefix}.{n}");

        foreach (var ns in internalNamespaces)
        {
            var result = Types.InAssembly(assembly)
                .Should().NotHaveDependencyOn(ns).GetResult();

            Assert.True(result.IsSuccessful,
                $"{assembly.GetName().Name} has illegal dependency on {ns}");
        }
    }
}
```

## Common Follow-up Questions

- How do you enforce module boundaries when modules are in the same project (folder-based separation)?
- Can NetArchTest rules check for circular dependencies between modules?
- How do you balance `internal` visibility with the need for cross-module testing?
- What tools exist beyond NetArchTest for .NET architectural governance?
- How do you handle third-party dependencies that need to be in the domain layer (e.g., NodaTime)?

## Common Mistakes / Pitfalls

- **`InternalsVisibleTo` with wildcards**: `[assembly: InternalsVisibleTo("*")]` defeats the purpose — makes all internal types accessible everywhere. Explicitly list only test projects.
- **Not running arch tests in CI**: writing architectural rules but not running them in CI means violations accumulate silently. Every PR should fail if architectural rules are broken.
- **Testing only direct dependencies (not transitive)**: NetArchTest `NotHaveDependencyOn` by default checks direct references. Add assembly reference restrictions in `.csproj` to prevent even adding the reference.
- **Module tests in the module project**: putting unit tests inside `MyApp.Orders` project (not `MyApp.Orders.Tests`) avoids the need for `InternalsVisibleTo` but couples tests and production code — use a separate test project.

## References

- [NetArchTest — GitHub](https://github.com/BenMorris/NetArchTest)
- [InternalsVisibleTo — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.compilerservices.internalsvisibletoattribute)
- [See: modular-monolith-structure.md](./modular-monolith-structure.md)
- [See: fitness-functions.md](./fitness-functions.md)
