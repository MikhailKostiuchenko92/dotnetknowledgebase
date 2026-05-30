# What Is Shouldly and How Does It Compare to FluentAssertions?

**Category:** Testing / Assertion Libraries
**Difficulty:** 🟡 Middle
**Tags:** `Shouldly`, `FluentAssertions`, `assertions`, `test-readability`

## Question
> What is Shouldly and how does it compare to FluentAssertions?

## Short Answer
Shouldly is a lightweight assertion library with a `.ShouldBe()` / `.ShouldNotBeNull()` style that produces readable error messages by inspecting the expression source at runtime. FluentAssertions is more feature-rich with a `.Should().Be()` syntax and a larger API surface for complex scenarios. Shouldly is simpler to adopt; FluentAssertions is more powerful for deep object comparison, scoped assertions, and custom extensions.

## Detailed Explanation

### Shouldly Syntax
```csharp
result.ShouldNotBeNull();
result.ShouldBe(42);
result.ShouldBeGreaterThan(0);
result.ShouldContain("expected text");
list.ShouldContain(x => x.IsActive);
list.ShouldAllBe(x => x.Price > 0);
```

### Exception Assertion (Shouldly)
```csharp
Should.Throw<ArgumentException>(() => sut.Process(-1));
await Should.ThrowAsync<InvalidOperationException>(() => sut.ProcessAsync());
```

### What Makes Shouldly Different: Expression-Based Error Messages
Shouldly captures the variable names from the source expression and uses them in the error message:
```csharp
var count = results.Count();
count.ShouldBe(5);
// Failure: "count should be 5 but was 3"
// Not: "Expected 5 but found 3" (anonymous)
```

This is achieved via `[CallerArgumentExpression]` in .NET 6+ or Fody-based IL weaving.

### Side-by-Side Comparison

| Feature | Shouldly | FluentAssertions |
|---|---|---|
| Syntax style | `.ShouldBe()` | `.Should().Be()` |
| Error messages | Expression-aware | Rich, descriptive |
| Deep object comparison | Basic | `BeEquivalentTo` (advanced) |
| Collection assertions | Basic set | Very rich set |
| Exception assertions | `Should.Throw<T>()` | `act.Should().Throw<T>()` |
| `AssertionScope` equivalent | ❌ No | ✅ `AssertionScope` |
| Custom extensions | Minimal API | Full extension model |
| Package size | Smaller | Larger |
| License | MIT | MIT (v7) / Commercial (v8+) |
| Best for | Simple assertions, small projects | Complex scenarios, enterprise |

### Shouldly Collection Assertions
```csharp
items.ShouldNotBeEmpty();
items.ShouldContain(x => x.Id == 5);
items.ShouldAllBe(x => x.IsValid);
items.Count.ShouldBe(3);
```

### When to Choose Each

| Choose Shouldly | Choose FluentAssertions |
|---|---|
| Minimal dependencies | Need deep structural comparison |
| Prefer concise syntax | Need `AssertionScope` |
| Commercial licensing concern with FA v8+ | Need custom assertion extensions |
| Simple projects / internal tools | Large team with complex domain models |

## Code Example
```csharp
namespace ShouldlyDemo.Tests;

public class ProductServiceTests
{
    private readonly ProductService _sut = new();

    // ── Shouldly ──────────────────────────────────────────
    [Fact]
    public void GetProduct_ReturnsCorrectProduct()
    {
        var product = _sut.GetById(1);

        product.ShouldNotBeNull();
        product.Id.ShouldBe(1);
        product.Price.ShouldBeGreaterThan(0m);
        product.Name.ShouldContain("Widget");
    }

    [Fact]
    public void GetAll_ReturnsActiveProducts()
    {
        var products = _sut.GetAll();

        products.ShouldNotBeEmpty();
        products.ShouldAllBe(p => p.IsActive);
        products.Count().ShouldBe(5);
    }

    [Fact]
    public void GetById_InvalidId_Throws()
    {
        Should.Throw<ArgumentException>(() => _sut.GetById(-1))
              .Message.ShouldContain("invalid");
    }

    // ── Equivalent with FluentAssertions ──────────────────
    [Fact]
    public void GetProduct_FluentAssertions_Style()
    {
        var product = _sut.GetById(1);

        product.Should().NotBeNull();
        product!.Id.Should().Be(1);
        product.Price.Should().BeGreaterThan(0m);
        product.Name.Should().Contain("Widget");
    }
}
```

## Common Follow-up Questions
- What is the equivalent of FluentAssertions' `AssertionScope` in Shouldly?
- How does Shouldly generate its expression-based error messages?
- Can you use Shouldly and FluentAssertions in the same project?
- Is Shouldly supported in .NET 8/9?
- How do you extend Shouldly with custom assertion methods?
- What changed in the FluentAssertions v8 licensing that drove some teams to Shouldly?

## Common Mistakes / Pitfalls
- **Mixing Shouldly and FluentAssertions in the same file** — both can coexist in a project, but mixing styles in one test class creates inconsistency.
- **Expecting `AssertionScope`-style soft assertions from Shouldly** — Shouldly does not have an equivalent; each assertion still throws immediately.
- **Using `ShouldBe` for deep object comparison** — like `Assert.Equal`, this uses `Equals`; for structural comparison you need to compare properties individually.
- **Assuming Shouldly supports chaining** — `product.ShouldNotBeNull().ShouldBe(...)` is not possible in Shouldly; each assertion is standalone.
- **Ignoring FA v8 licensing** — if your team uses FluentAssertions in a commercial product, audit your version; v8+ requires a paid license.

## References
- [Shouldly on GitHub](https://github.com/shouldly/shouldly)
- [Shouldly documentation](https://docs.shouldly.org/)
- [NuGet — Shouldly](https://www.nuget.org/packages/Shouldly/)
- [FluentAssertions vs Shouldly comparison](https://fluentassertions.com/) (verify URL)
