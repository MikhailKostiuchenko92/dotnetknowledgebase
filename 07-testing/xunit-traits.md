# How Do You Categorize and Filter Tests Using Traits in xUnit?

**Category:** Testing / xUnit
**Difficulty:** 🟡 Middle
**Tags:** `xunit`, `[Trait]`, `traits`, `test-filtering`, `categories`, `dotnet-test`

## Question
> How do you categorize and filter tests using traits in xUnit?

## Short Answer
Apply `[Trait("key", "value")]` to test methods or classes to attach arbitrary metadata. Then use `dotnet test --filter` with trait key/value expressions to run only the matching tests. Traits are xUnit's equivalent of NUnit's `[Category]` attribute.

## Detailed Explanation

### What Is a Trait?
A trait is a key-value pair attached to a test. It carries no runtime behaviour — it's metadata that test runners can use to select, group, or report tests. Both the key and value are free-form strings.

Common conventions:

| Trait key | Example values | Purpose |
|---|---|---|
| `"Category"` | `"Unit"`, `"Integration"`, `"Slow"` | Test type grouping |
| `"Feature"` | `"Checkout"`, `"Auth"`, `"Reporting"` | Business feature grouping |
| `"Priority"` | `"P0"`, `"P1"` | Critical vs. nice-to-have |
| `"OS"` | `"Windows"`, `"Linux"` | Platform-specific grouping |

### Applying Traits
```csharp
// On a single test method
[Fact]
[Trait("Category", "Integration")]
[Trait("Feature", "Auth")]
public void Login_WithValidCredentials_ReturnsToken() { ... }

// On a test class (applies to all tests in the class)
[Trait("Category", "Slow")]
public class HeavyIntegrationTests { ... }
```

### Filtering with `dotnet test`
```bash
# Run only integration tests
dotnet test --filter "Category=Integration"

# Run only fast (unit) tests
dotnet test --filter "Category=Unit"

# Run by feature
dotnet test --filter "Feature=Checkout"

# Combine with AND (& or &amp; in some shells)
dotnet test --filter "Category=Unit&Feature=Auth"

# Combine with OR (|)
dotnet test --filter "Category=Unit|Category=Integration"

# Exclude slow tests
dotnet test --filter "Category!=Slow"
```

> 💡 The `--filter` syntax is the standard `.NET test platform` filter expression, not xUnit-specific. It also supports `FullyQualifiedName~ClassName` and `DisplayName~SomeText` for name-based filtering.

### Custom Trait Attributes
Writing `[Trait("Category","Unit")]` everywhere is verbose and typo-prone. Create strongly-typed attribute wrappers:

```csharp
// ITraitAttribute marker (xUnit v2)
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class UnitTestAttribute : Attribute, ITraitAttribute
{
    public IReadOnlyCollection<KeyValuePair<string, string>> GetTraits()
        => [new("Category", "Unit")];
}

// xUnit v3 — use TraitDiscoverer
```

Then use `[UnitTest]` instead of `[Trait("Category","Unit")]`.

### CI Pipeline Usage
In GitHub Actions:
```yaml
- name: Run unit tests only
  run: dotnet test --filter "Category=Unit" --no-build

- name: Run all tests
  run: dotnet test --no-build
```

## Code Example
```csharp
namespace Shop.Tests;

// ── Trait on method ───────────────────────────────────────────────────────────
public class PricingTests
{
    [Fact]
    [Trait("Category", "Unit")]
    [Trait("Feature", "Pricing")]
    public void ApplyDiscount_ReducesPrice()
    {
        new DiscountCalculator().Apply(100m, 10m).Should().Be(90m);
    }

    [Fact]
    [Trait("Category", "Slow")]
    [Trait("Feature", "Pricing")]
    public async Task GetLivePrices_ReturnsResults()
    {
        // hits external API — excluded from fast unit suite
        var prices = await new LivePriceService().GetAllAsync();
        prices.Should().NotBeEmpty();
    }
}

// ── Trait on class (applies to ALL tests in the class) ───────────────────────
[Trait("Category", "Integration")]
[Trait("Feature", "Orders")]
public class OrderApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    // every test here has Category=Integration, Feature=Orders
}
```

```bash
# Run only Pricing unit tests
dotnet test --filter "Category=Unit&Feature=Pricing"

# Exclude slow tests from PR pipeline
dotnet test --filter "Category!=Slow"
```

## Common Follow-up Questions
- How do you create a custom trait attribute to avoid repeating `[Trait("Category","Unit")]`?
- How does xUnit's `[Trait]` compare to NUnit's `[Category]` and MSTest's `[TestCategory]`?
- How do you filter tests in Visual Studio's Test Explorer using traits?
- Can you apply multiple `[Trait]` attributes to the same test?
- How do you run only a specific test class from the command line?
- What is the difference between `dotnet test --filter` and `--testcasefilter`?

## Common Mistakes / Pitfalls
- **Typos in trait strings** — `"Intergration"` vs `"Integration"` causes tests to be silently excluded from runs.
- **Not applying traits consistently** — new tests added without traits get excluded from filtered CI runs.
- **Over-categorising** — ten different trait keys with one value each becomes unmaintainable; keep it to 2–3 meaningful categories.
- **Filtering by `DisplayName~` instead of Trait** — brittle if test names are refactored.
- **Missing `[Trait]` on integration tests** — slow integration tests run in every PR build, blocking developers.

## References
- [xUnit documentation — Running tests in parallel and filtering](https://xunit.net/docs/running-tests-in-parallel)
- [Microsoft Learn — dotnet test --filter](https://learn.microsoft.com/en-us/dotnet/core/testing/selective-unit-tests)
- [xUnit GitHub — TraitAttribute](https://github.com/xunit/xunit/blob/main/src/xunit.v3.core/TraitAttribute.cs)
- [Andrew Lock — Filtering tests with dotnet test](https://andrewlock.net/running-tests-with-dotnet-test/) (verify URL)
