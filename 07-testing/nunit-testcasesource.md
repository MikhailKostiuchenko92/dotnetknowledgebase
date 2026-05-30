# What Is `[TestCaseSource]` in NUnit and When Would You Use It?

**Category:** Testing / NUnit
**Difficulty:** 🟡 Middle
**Tags:** `nunit`, `[TestCaseSource]`, `parameterized-tests`, `data-driven`, `complex-data`

## Question
> What is `[TestCaseSource]` and when would you use it?

## Short Answer
`[TestCaseSource]` is NUnit's attribute for supplying parameterised test data from an external source — a static property, method, or field returning `IEnumerable` — rather than inline attribute arguments. Use it when data requires runtime construction (objects, computed values, file reads) or when it should be reused across multiple test methods or classes.

## Detailed Explanation

### Why `[TestCaseSource]` Over `[TestCase]`?
`[TestCase]` only accepts compile-time constants. When you need:
- `new` object instances
- `DateTime`, `decimal`, or other non-constant types
- Data loaded from a file, database, or environment variable
- A single data set shared by multiple test methods

→ Use `[TestCaseSource]`.

### Syntax
```csharp
[TestCaseSource(nameof(MyData))]
public void Test(InputType input, bool expected) { }

private static IEnumerable<TestCaseData> MyData
{
    get
    {
        yield return new TestCaseData(new InputType("a"), true)
            .SetName("ValidInput_A")
            .SetDescription("Tests a valid input 'a'");
        yield return new TestCaseData(new InputType("b"), false)
            .SetName("InvalidInput_B");
    }
}
```

### `TestCaseData` Class
`TestCaseData` is a rich wrapper for a single data row:
- `.SetName(string)` — custom test name in output
- `.SetDescription(string)` — description metadata
- `.Ignore(string)` — skip this specific row
- `.Returns(object)` — expected return value (like `ExpectedResult`)
- `.Throws(typeof(Exception))` — expected exception type

### Source Location
The source member can be:
- **In the same class** — `[TestCaseSource(nameof(MyData))]`
- **In another class** — `[TestCaseSource(typeof(SharedData), nameof(SharedData.Cases))]`
- **A method** — `private static IEnumerable<TestCaseData> MyData() { ... }`

> ⚠️ **Warning:** The source member must be `static`. NUnit evaluates it at test-discovery time (before any test runs), so avoid heavy I/O or database queries in the source — use lazy loading or factory methods if necessary.

### Comparison: NUnit `[TestCaseSource]` vs. xUnit `[MemberData]`

| Feature | NUnit `[TestCaseSource]` | xUnit `[MemberData]` |
|---|---|---|
| Rich metadata per row | `TestCaseData.SetName(...)` | Not built-in |
| Skip per row | `.Ignore("reason")` | No native support |
| Expected exception | `.Throws(typeof(T))` | Not built-in |
| Source in another class | `typeof(OtherClass)` param | `MemberType = typeof(T)` |
| Type safety | `IEnumerable<TestCaseData>` | `TheoryData<T>` (xUnit) |

## Code Example
```csharp
namespace Validation.Tests;

[TestFixture]
public class InvoiceValidatorTests
{
    // Source in the same class
    [Test, TestCaseSource(nameof(InvalidInvoiceCases))]
    public void Validate_WithInvalidInvoice_ReturnsExpectedError(
        Invoice invoice, string expectedError)
    {
        var sut = new InvoiceValidator();
        var result = sut.Validate(invoice);
        Assert.That(result.Errors, Does.Contain(expectedError));
    }

    private static IEnumerable<TestCaseData> InvalidInvoiceCases()
    {
        yield return new TestCaseData(
            new Invoice { CustomerId = 0, Total = 100m },
            "Customer ID is required")
            .SetName("MissingCustomerId");

        yield return new TestCaseData(
            new Invoice { CustomerId = 1, Total = -5m },
            "Total must be positive")
            .SetName("NegativeTotal");

        yield return new TestCaseData(
            new Invoice { CustomerId = 1, Total = 0m, Items = [] },
            "Invoice must have at least one item")
            .SetName("EmptyItems")
            .Ignore("Edge case not yet implemented"); // skip this row
    }
}

// Source in a shared class — reusable across test projects
public static class SharedInvoiceData
{
    public static IEnumerable<TestCaseData> ValidInvoices =>
    [
        new TestCaseData(new Invoice { CustomerId = 1, Total = 100m })
            .SetName("MinimalValidInvoice"),
        new TestCaseData(new Invoice { CustomerId = 2, Total = 9999m, Items = [new()] })
            .SetName("LargeInvoice"),
    ];
}

[TestFixture]
public class InvoiceProcessorTests
{
    [Test, TestCaseSource(typeof(SharedInvoiceData), nameof(SharedInvoiceData.ValidInvoices))]
    public void Process_WithValidInvoice_Succeeds(Invoice invoice)
    {
        var sut = new InvoiceProcessor();
        Assert.DoesNotThrow(() => sut.Process(invoice));
    }
}
```

## Common Follow-up Questions
- What is the difference between `[TestCaseSource]` and `[TestCase]`?
- How do you share `[TestCaseSource]` data across multiple test classes?
- What is `TestCaseData` and what metadata can it carry?
- How does NUnit's `[TestCaseSource]` compare to xUnit's `[MemberData]`?
- How do you skip a single row from a `[TestCaseSource]`?
- What happens if the source method returns `null` or an empty enumerable?

## Common Mistakes / Pitfalls
- **Non-static source member** — NUnit requires the source to be `static`; instance members cause a discovery-time exception.
- **Heavy I/O in the source** — evaluated at assembly-load time; slow data sources delay test discovery.
- **Forgetting `nameof`** — hardcoded strings break silently on rename; always use `nameof(...)`.
- **Not using `TestCaseData.SetName`** — auto-generated names include the `ToString()` of each argument, which may be "MyClass" for all rows; add meaningful names.
- **Mutable shared objects across rows** — if two `TestCaseData` rows reference the same object instance and tests mutate it, rows interfere with each other.

## References
- [NUnit documentation — TestCaseSource attribute](https://docs.nunit.org/articles/nunit/writing-tests/attributes/testcasesource.html)
- [NUnit documentation — TestCaseData class](https://docs.nunit.org/articles/nunit/writing-tests/TestCaseData.html)
- [NUnit documentation — Parameterised tests](https://docs.nunit.org/articles/nunit/writing-tests/parameterized-tests.html)
- [Microsoft Learn — Unit testing with NUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-nunit)
