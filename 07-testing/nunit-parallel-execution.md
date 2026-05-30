# How Does NUnit Handle Parallel Test Execution and What Risks Does It Introduce?

**Category:** Testing / NUnit
**Difficulty:** 🔴 Senior
**Tags:** `nunit`, `parallel`, `[Parallelizable]`, `thread-safety`, `concurrency`, `[NonParallelizable]`

## Question
> How does NUnit handle parallel test execution and what risks does it introduce?

## Short Answer
NUnit supports parallel execution via the `[Parallelizable]` attribute and the `LevelOfParallelism` assembly-level setting. Tests run in parallel unless explicitly opted out with `[NonParallelizable]`. The primary risks are shared mutable state between tests causing interference and thread-safety violations in the system under test or test infrastructure.

## Detailed Explanation

### Enabling Parallelism
```csharp
// assembly-level (AssemblyInfo.cs or any .cs file)
[assembly: Parallelizable(ParallelScope.Fixtures)]
[assembly: LevelOfParallelism(4)] // number of parallel threads
```

Or per class/method:
```csharp
[Parallelizable(ParallelScope.Children)] // methods in this class run in parallel
public class MyTests { }

[Parallelizable(ParallelScope.Fixtures)] // fixtures within the assembly run in parallel
```

### `ParallelScope` Options

| Scope | Meaning |
|---|---|
| `ParallelScope.None` | Run sequentially (default if no attribute) |
| `ParallelScope.Self` | This fixture or test runs in parallel with siblings |
| `ParallelScope.Children` | Child tests within this fixture run in parallel |
| `ParallelScope.Fixtures` | All fixtures in the assembly run in parallel (most common) |
| `ParallelScope.All` | Tests and fixtures all run in parallel |

### `[NonParallelizable]`
Forces a test or fixture to run sequentially, even if the parent scope is parallel. Use this for:
- Tests that rely on shared infrastructure (a specific port, a global registry)
- Tests with external side effects (environment variables, file system state)

### Risks of Parallel Execution

#### 1. Shared Mutable State
The most common bug: two tests read/modify the same object simultaneously.
```csharp
// ❌ Dangerous with Parallelizable — shared static state
private static readonly List<string> _log = new();

[Test] public void Test1() { _log.Add("a"); } // race condition
[Test] public void Test2() { _log.Add("b"); }
```

**Fix:** Use `[NonParallelizable]` on tests that use shared state, or eliminate shared state entirely.

#### 2. Non-Thread-Safe Test Infrastructure
In-memory fakes, `DbContext` instances, mock objects — none are thread-safe for concurrent use. Each test must own its own instances.

#### 3. Port/Resource Conflicts
Integration tests that start HTTP servers on fixed ports conflict when run in parallel. Use dynamic port allocation (`0` for the port) or use `WebApplicationFactory` (which handles this internally).

#### 4. Test Output Interleaving
`TestContext.Progress.WriteLine` from parallel tests interleaves in output, making it hard to correlate messages with tests. Use `ITestOutputHelper` (xUnit) or per-test log sinks.

#### 5. Deadlocks
If tests hold locks (database transactions, `Monitor.Enter`) and compete for the same resources, deadlocks occur.

### Diagnosing Parallel Failures
Tests that **pass individually** but **fail in parallel** almost certainly have shared mutable state or resource conflicts. Run with `--agents=1` to confirm:
```bash
dotnet test -- NUnit.NumberOfTestWorkers=1
```
If they pass with 1 worker, the problem is concurrency.

## Code Example
```csharp
// Assembly-level config (often in a dedicated file)
[assembly: Parallelizable(ParallelScope.Fixtures)]
[assembly: LevelOfParallelism(4)]

namespace Catalog.Tests;

// ✅ Safe for parallelism — each test creates its own objects
[Parallelizable(ParallelScope.Children)]
[TestFixture]
public class ProductServiceTests
{
    [Test]
    public void GetById_WhenExists_ReturnsProduct()
    {
        // All objects are local — no shared state
        var repo = new Mock<IProductRepository>();
        repo.Setup(r => r.FindById(1)).Returns(new Product { Id = 1 });
        var sut = new ProductService(repo.Object);

        var result = sut.GetById(1);
        Assert.That(result, Is.Not.Null);
    }
}

// ⚠️ Must be non-parallelizable — uses a fixed external resource
[NonParallelizable]
[TestFixture]
public class LegacyFileImporterTests
{
    // Tests that write to a fixed temp directory — cannot run concurrently
    private static readonly string TempPath = Path.Combine(Path.GetTempPath(), "importer-tests");

    [OneTimeSetUp]
    public void SetUp() => Directory.CreateDirectory(TempPath);

    [OneTimeTearDown]
    public void TearDown() => Directory.Delete(TempPath, recursive: true);

    [Test]
    public void Import_CreatesOutputFile()
    {
        var importer = new FileImporter(TempPath);
        importer.Import("data.csv");
        Assert.That(File.Exists(Path.Combine(TempPath, "output.json")), Is.True);
    }
}
```

## Common Follow-up Questions
- How do you detect shared state bugs in a parallel test suite?
- What is `LevelOfParallelism` and what value should you set?
- How does xUnit handle parallel execution compared to NUnit?
- What is the `[SingleThreaded]` attribute in NUnit?
- How do you use `TestContext.CurrentContext` safely in parallel tests?
- What are the risks of running `WebApplicationFactory` tests in parallel?

## Common Mistakes / Pitfalls
- **Static mutable fields in test classes** — the most common cause of parallel test failures; make all test state per-instance.
- **Shared `DbContext` or repository** — not thread-safe; each test needs its own context.
- **Forgetting to mark infrastructure-dependent tests as `[NonParallelizable]`** — causes flaky failures that are hard to reproduce.
- **Port conflicts in integration tests** — fix by using dynamic ports or `WebApplicationFactory` (self-assigns ports).
- **Setting `LevelOfParallelism` too high** — can overwhelm the test machine, increasing flakiness from resource starvation.

## References
- [NUnit documentation — Parallelizable attribute](https://docs.nunit.org/articles/nunit/writing-tests/attributes/parallelizable.html)
- [NUnit documentation — Parallel test execution](https://docs.nunit.org/articles/nunit/technical-notes/usage/parallelism.html)
- [xUnit documentation — Running tests in parallel](https://xunit.net/docs/running-tests-in-parallel)
- [Microsoft Learn — Unit testing in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/)
