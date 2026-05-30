# What Is ApprovalTests and How Does It Differ From Traditional Assertion Testing?

**Category:** Testing / Advanced Topics
**Difficulty:** 🔴 Senior
**Tags:** `ApprovalTests`, `snapshot-testing`, `Verify`, `golden-file`, `testing`

## Question
> What is Approval Tests and how does it differ from traditional assertion testing?

## Short Answer
**ApprovalTests** (and its modern successor **Verify**) are libraries that implement "golden file" or "snapshot" testing. Instead of writing `x.Should().Be(y)`, you call `Approvals.Verify(output)` or `await Verify(output)` — the library compares the output to an approved file on disk. Traditional assertion testing requires you to specify expected values upfront; approval testing lets you review the actual output, approve it, and detect regressions on subsequent runs.

## Detailed Explanation

### Traditional Assertion Testing
```csharp
var invoice = invoiceService.Generate(order);
invoice.Total.Should().Be(100m);
invoice.CustomerName.Should().Be("Alice");
invoice.Lines.Should().HaveCount(2);
// ... 20 more property assertions
```

**Problem**: Writing assertions for complex objects is tedious and brittle — adding a new property requires updating every test.

### Approval / Golden File Testing
```csharp
// Verify library (modern, recommended)
await Verify(invoiceService.Generate(order));

// ApprovalTests library (older)
Approvals.VerifyJson(JsonSerializer.Serialize(invoice));
```

On first run: the output is written to a `.received.txt` file. You review it, rename it to `.verified.txt` (approve it), and commit it. On subsequent runs: the output is compared to the approved file. Any difference = test failure.

### When to Use Approval Testing

| Scenario | Traditional assertions | Approval testing |
|---|---|---|
| Single property check | ✅ Ideal | Overkill |
| Complex object graph | Tedious | ✅ Ideal |
| HTML/report rendering | Very hard | ✅ Ideal |
| API JSON response | Moderate | ✅ Good |
| Code generation output | Very hard | ✅ Ideal |
| Refactoring verification | Normal assertions | ✅ Excellent |

### Verify vs. ApprovalTests

| | Verify | ApprovalTests |
|---|---|---|
| Maintained | ✅ Actively (.NET 8/9) | 🟡 Less active |
| Async support | ✅ Async-first | ❌ Synchronous |
| Scrubbing | ✅ Built-in (GUID, timestamp) | Manual |
| Test frameworks | xUnit, NUnit, MSTest | xUnit, NUnit, MSTest |

### Key Verify Features
```csharp
// Scrub non-deterministic values
await Verify(order).ScrubMember<Order>(o => o.CreatedAt);

// Scrub all GUIDs globally
settings.ScrubInlineGuids();

// Approve via CLI
dotnet verify approve
```

### Approval Workflow
1. Write test: `await Verify(output)`
2. Run test: **FAILS** — creates `Test.received.txt`
3. Review `received.txt` — is this the correct output?
4. Approve: rename to `Test.verified.txt` (or run `dotnet verify approve`)
5. Commit the `.verified.txt` file
6. Future runs: output compared to `.verified.txt` — pass if same, fail if different

## Code Example
```csharp
using VerifyXunit;
using Xunit;

[UsesVerify]
public class ReportTests
{
    [Fact]
    public async Task MonthlyReport_MatchesApprovedOutput()
    {
        var report = new MonthlyReportGenerator().Generate(
            month: new DateTime(2024, 1, 1),
            orders: SampleOrders.January2024);

        // Output is serialized and compared to ReportTests.MonthlyReport_MatchesApprovedOutput.verified.txt
        await Verify(report);
    }

    [Fact]
    public async Task Invoice_HtmlRender_MatchesSnapshot()
    {
        var html = new InvoiceRenderer().Render(SampleInvoice.Standard);

        // Scrub the generation timestamp so it doesn't change every run
        var settings = new VerifySettings();
        settings.ScrubMember<Invoice>(i => i.GeneratedAt);

        await Verify(html, settings);
    }
}
```

## Common Follow-up Questions
- What is the difference between Verify and ApprovalTests?
- How do you handle non-deterministic data (GUIDs, timestamps) in approval tests?
- How do you approve changed snapshots in a CI pipeline?
- When should you use approval testing vs. traditional assertion testing?
- How do you store approved files in source control?

## Common Mistakes / Pitfalls
- **Not scrubbing non-deterministic data** — timestamps and GUIDs cause failures on every run.
- **Not committing `.verified.txt` files** — approved files must be in source control for CI to work.
- **Using approval tests for simple properties** — overkill; use targeted assertions instead.
- **Blindly approving changes** — review diffs carefully; an unexpected change may be a bug.

## References
- [Verify GitHub](https://github.com/VerifyTests/Verify)
- [ApprovalTests.NET GitHub](https://github.com/approvals/ApprovalTests.Net)
- [Verify documentation](https://verifyTests.github.io/Verify/)
- [See also: snapshot-testing.md](snapshot-testing.md)
