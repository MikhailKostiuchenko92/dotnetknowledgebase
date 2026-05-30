# Architectural Fitness Functions

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🔴 Senior
**Tags:** `fitness-functions`, `NetArchTest`, `ArchUnit`, `architectural-testing`, `dependency-enforcement`, `CI`

## Question

> What is an architectural fitness function? How do you enforce architectural constraints (e.g., Clean Architecture layer rules, naming conventions, forbidden dependencies) in .NET using tools like NetArchTest or custom Roslyn analyzers?

## Short Answer

An **architectural fitness function** (from "Building Evolutionary Architectures" by Ford/Parsons/Kua) is any automated mechanism that checks a specific architectural characteristic — dependency direction, naming conventions, coupling metrics, or banned APIs. In .NET, **NetArchTest** lets you write executable architecture tests in xUnit/NUnit that fail the CI build when code violates structural rules (e.g., "Application layer must not reference Infrastructure"). These tests turn architecture decisions into living, enforced constraints rather than README paragraphs that rot.

## Detailed Explanation

### Why Fitness Functions Matter

Architecture decisions decay under pressure. After six months, someone adds an EF Core reference to the Domain project "just this once." Without automated enforcement, that violation compounds — each subsequent developer sees the pattern and follows it. A fitness function test fails the CI build immediately, catching the violation in the PR that introduced it.

### NetArchTest Basics

```bash
dotnet add package NetArchTest.Rules
```

NetArchTest works by loading assemblies and applying predicate rules:

```csharp
using NetArchTest.Rules;

public class ArchitectureTests
{
    private const string DomainNamespace = "YourApp.Domain";
    private const string ApplicationNamespace = "YourApp.Application";
    private const string InfrastructureNamespace = "YourApp.Infrastructure";

    [Fact]
    public void Domain_Should_Not_Depend_On_Application_Or_Infrastructure()
    {
        var result = Types.InAssembly(typeof(Order).Assembly)
            .ShouldNot()
            .HaveDependencyOnAny(ApplicationNamespace, InfrastructureNamespace)
            .GetResult();

        Assert.True(result.IsSuccessful,
            $"Domain violations: {string.Join(", ", result.FailingTypeNames ?? [])}");
    }

    [Fact]
    public void Application_Should_Not_Depend_On_Infrastructure()
    {
        var result = Types.InAssembly(typeof(PlaceOrderCommand).Assembly)
            .ShouldNot()
            .HaveDependencyOn(InfrastructureNamespace)
            .GetResult();

        Assert.True(result.IsSuccessful,
            $"Application violations: {string.Join(", ", result.FailingTypeNames ?? [])}");
    }

    [Fact]
    public void Handlers_Should_Be_Sealed()
    {
        // Sealed handlers prevent accidental inheritance and proxy-based interception bypasses
        var result = Types.InAssembly(typeof(PlaceOrderCommand).Assembly)
            .That()
            .HaveNameEndingWith("Handler")
            .Should()
            .BeSealed()
            .GetResult();

        Assert.True(result.IsSuccessful,
            $"Non-sealed handlers: {string.Join(", ", result.FailingTypeNames ?? [])}");
    }

    [Fact]
    public void Repositories_Should_Implement_IRepository_Interface()
    {
        var result = Types.InAssembly(typeof(EfOrderRepository).Assembly)
            .That()
            .HaveNameEndingWith("Repository")
            .Should()
            .ImplementInterface(typeof(IRepository<>))
            .GetResult();

        Assert.True(result.IsSuccessful);
    }
}
```

### Common Fitness Function Categories

| Category | Example rule | NetArchTest predicate |
|----------|-------------|----------------------|
| Dependency direction | Domain must not depend on Infrastructure | `HaveDependencyOnAny(...)` |
| Naming conventions | All classes in `Application/Commands/` end with `Command` | `HaveNameEndingWith("Command")` |
| Layer isolation | Controllers must not call repositories directly | `HaveDependencyOn("Repositories")` |
| Access modifiers | Domain entities must not have public setters | Custom (Roslyn) |
| Class placement | Validators must be in Application namespace | `ResideInNamespace(...)` |
| Abstract base adherence | All handlers must implement `IRequestHandler` | `ImplementInterface(typeof(IRequestHandler<,>))` |

### Module Boundary Enforcement

For Modular Monoliths, enforce that modules don't cross-reference:

```csharp
[Fact]
public void Orders_Module_Should_Not_Reference_Inventory_Internals()
{
    var result = Types.InCurrentDomain()
        .That()
        .ResideInNamespace("YourApp.Orders")
        .ShouldNot()
        .HaveDependencyOn("YourApp.Inventory.Application")  // internal namespace
        .GetResult();

    Assert.True(result.IsSuccessful,
        $"Cross-module violations: {string.Join(", ", result.FailingTypeNames ?? [])}");
}

[Theory]
[InlineData("YourApp.Orders")]
[InlineData("YourApp.Inventory")]
[InlineData("YourApp.Payments")]
public void Each_Module_Should_Only_Depend_On_Common_And_Own_API(string moduleNamespace)
{
    var result = Types.InCurrentDomain()
        .That()
        .ResideInNamespace($"{moduleNamespace}.Application")
        .ShouldNot()
        .HaveDependencyOnAny(
            "YourApp.Orders.Application",
            "YourApp.Inventory.Application",
            "YourApp.Payments.Application")
        .GetResult();

    Assert.True(result.IsSuccessful);
}
```

### Custom Roslyn Analyzer (Advanced)

For rules NetArchTest can't express (e.g., "entities must have private setters"), write a Roslyn analyzer:

```csharp
[DiagnosticAnalyzer(LanguageNames.CSharp)]
public class EntityPublicSetterAnalyzer : DiagnosticAnalyzer
{
    private static readonly DiagnosticDescriptor Rule = new(
        id: "ARCH001",
        title: "Domain entity has public setter",
        messageFormat: "Property '{0}' on entity '{1}' has a public setter",
        category: "Architecture",
        defaultSeverity: DiagnosticSeverity.Error,
        isEnabledByDefault: true);

    public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics => [Rule];

    public override void Initialize(AnalysisContext context)
    {
        context.RegisterSyntaxNodeAction(AnalyzeProperty, SyntaxKind.PropertyDeclaration);
    }

    private static void AnalyzeProperty(SyntaxNodeAnalysisContext ctx)
    {
        // Check if the containing class inherits AggregateRoot and has public setter
        // ... (implementation omitted for brevity)
    }
}
```

### Integrating with CI

```yaml
# .github/workflows/arch-tests.yml
- name: Run Architecture Tests
  run: dotnet test tests/YourApp.Architecture.Tests/ --no-build
```

Fitness function tests should run in a dedicated lightweight test project with no infrastructure setup — they only need the assemblies loaded.

## Code Example

```csharp
// A complete set of Clean Architecture fitness functions
public class CleanArchitectureFitnessTests
{
    private static readonly Assembly DomainAssembly = typeof(Order).Assembly;
    private static readonly Assembly ApplicationAssembly = typeof(PlaceOrderCommand).Assembly;
    private static readonly Assembly InfrastructureAssembly = typeof(EfOrderRepository).Assembly;

    [Fact]
    public void Domain_Has_No_External_Dependencies()
    {
        var result = Types.InAssembly(DomainAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(
                "Microsoft.EntityFrameworkCore",
                "MediatR",
                "Microsoft.AspNetCore",
                "Newtonsoft.Json")
            .GetResult();

        Assert.True(result.IsSuccessful, FormatFailure(result));
    }

    [Fact]
    public void Application_Does_Not_Reference_Infrastructure()
    {
        var result = Types.InAssembly(ApplicationAssembly)
            .ShouldNot()
            .HaveDependencyOn("YourApp.Infrastructure")
            .GetResult();

        Assert.True(result.IsSuccessful, FormatFailure(result));
    }

    [Fact]
    public void All_Validators_Are_In_Application_Namespace()
    {
        var result = Types.InAssembly(ApplicationAssembly)
            .That()
            .HaveNameEndingWith("Validator")
            .Should()
            .ResideInNamespace("YourApp.Application")
            .GetResult();

        Assert.True(result.IsSuccessful, FormatFailure(result));
    }

    private static string FormatFailure(TestResult result)
        => $"Failing types: {string.Join(", ", result.FailingTypeNames ?? [])}";
}
```

## Common Follow-up Questions

- How do you write fitness functions for rules that NetArchTest can't express — like "no public setters on domain entities"?
- How do you handle legitimate exceptions to architectural rules (e.g., a specific class that must cross a boundary)?
- What is the difference between architectural tests and integration tests?
- How do you measure architectural coupling (afferent/efferent coupling, instability) in .NET?
- How do you use ArchUnit (originally a Java tool) with its .NET ports?

## Common Mistakes / Pitfalls

- **Fitness function tests in the same project as production code**: architecture tests should be in a separate `*.Architecture.Tests` project that references all assembly types without coupling to domain logic.
- **Too granular rules**: testing that every single class ends with a specific suffix makes refactoring painful and generates false positives. Focus on structural dependency rules, not naming micro-rules.
- **Running fitness functions only locally**: the whole point is CI enforcement. Tests that only run locally are forgotten.
- **Not updating fitness functions after intentional architecture changes**: if you deliberately add a dependency (e.g., Domain now uses `System.Text.Json` for a serialization VO), update the test to reflect the new intent.

## References

- [NetArchTest — GitHub](https://github.com/BenMorris/NetArchTest)
- [Building Evolutionary Architectures — Ford, Parsons, Kua (O'Reilly)](https://www.oreilly.com/library/view/building-evolutionary-architectures/9781491986356/) (verify URL)
- [Roslyn Analyzers — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/tutorials/how-to-write-csharp-analyzer-code-fix)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
- [See: module-isolation-enforcement.md](./module-isolation-enforcement.md)
