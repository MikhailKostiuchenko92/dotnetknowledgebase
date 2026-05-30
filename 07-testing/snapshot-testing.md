# What Is Snapshot Testing and When Is It Useful for .NET Code?

**Category:** Testing / Advanced Topics
**Difficulty:** 🟡 Middle
**Tags:** `snapshot-testing`, `ApprovalTests`, `Verify`, `testing`, `output-comparison`

## Question
> What is snapshot testing and when is it useful for .NET code?

## Short Answer
Snapshot testing captures the serialized output of a method on first run and stores it as a "golden file." On subsequent runs, the output is compared to the stored snapshot; if it differs, the test fails. It's useful for testing complex object graphs, HTML rendering, JSON API responses, or any output where writing manual assertions would be tedious. In .NET, **Verify** (formerly VerifyTests) is the modern library for this.

## Detailed Explanation

### How It Works
1. First run: no snapshot exists → test **writes** the output to a `.verified.txt` file and passes (or fails depending on config)
2. Developer reviews the file and approves it
3. Subsequent runs: output is compared to the approved snapshot → fail if different

### Use Cases

| Scenario | Why snapshot testing helps |
|---|---|
| Complex JSON API responses | 50-field response object is tedious to assert manually |
| HTML/Razor rendering | Compare rendered HTML without dozens of `Contains` checks |
| Report generation | Exact string output comparison |
| Code generation | Assert generated C# or SQL |
| Serialization output | Verify JSON/XML format doesn't change unexpectedly |

### Verify Library (.NET)
```shell
dotnet add package Verify.Xunit   # or Verify.NUnit / Verify.MSTest
```

```csharp
[UsesVerify]
public class ProductTests
{
    [Fact]
    public async Task Serialize_Product_MatchesSnapshot()
    {
        var product = new Product { Id = 1, Name = "Laptop", Price = 999.99m };
        await Verify(product); // generates ProductTests.Serialize_Product_MatchesSnapshot.verified.txt
    }
}
```

### Approving Changes
When output changes legitimately, run:
```shell
dotnet verify approve
```
Or use the VS/Rider extension to diff and approve inline.

### Exclusions and Scrubbers
Non-deterministic data (timestamps, GUIDs) can be scrubbed:
```csharp
await Verify(order).ScrubMember<Order>(o => o.CreatedAt);
// or globally:
VerifySettings settings = new();
settings.ScrubInlineGuids();
await Verify(order, settings);
```

### ApprovalTests (Older Alternative)
```csharp
Approvals.VerifyJson(JsonSerializer.Serialize(product));
```
Verify is generally preferred on new projects (better .NET 8/9 support, async-first).

## Code Example
```csharp
using VerifyXunit;
using Xunit;

[UsesVerify]
public class InvoiceRendererTests
{
    [Fact]
    public async Task RenderInvoice_ReturnsExpectedHtml()
    {
        var invoice = new Invoice
        {
            Number = "INV-001",
            Lines = [new InvoiceLine { Description = "Laptop", Amount = 999m }],
            Total = 999m
        };

        var renderer = new InvoiceHtmlRenderer();
        var html = renderer.Render(invoice);

        await Verify(html);
        // On first run: creates InvoiceRendererTests.RenderInvoice_ReturnsExpectedHtml.verified.txt
        // On subsequent runs: compares against the file
    }
}
```

## Common Follow-up Questions
- How do you handle non-deterministic data (timestamps, GUIDs) in snapshots?
- How does Verify compare to ApprovalTests?
- How do you review and approve snapshot changes in a CI pipeline?
- When does snapshot testing become a maintenance burden?
- How do you store snapshot files in a Git repository?

## Common Mistakes / Pitfalls
- **Not scrubbing non-deterministic data** — tests fail on every run due to changing timestamps or GUIDs.
- **Storing snapshots outside source control** — snapshot files must be committed alongside the code.
- **Blindly approving changed snapshots** — review the diff carefully; unexpected changes may indicate bugs.
- **Using snapshot tests for business-logic assertions** — snapshot tests don't explain _why_ output changed; combine with targeted assertions.

## References
- [Verify GitHub](https://github.com/VerifyTests/Verify)
- [Verify documentation](https://verifyTests.github.io/Verify/)
- [ApprovalTests.NET GitHub](https://github.com/approvals/ApprovalTests.Net)
