# What Is NUnit's `[Retry]` Attribute and When Is Using It Appropriate vs. a Code Smell?

**Category:** Testing / NUnit
**Difficulty:** 🔴 Senior
**Tags:** `nunit`, `[Retry]`, `flaky-tests`, `test-smells`, `reliability`

## Question
> What is NUnit's `[Retry]` attribute and when is using it appropriate vs. a code smell?

## Short Answer
`[Retry(n)]` re-runs a failing test up to `n` times, passing if any attempt succeeds. It is almost always a **code smell**: it masks non-determinism (flaky tests) rather than fixing it. The only legitimate use case is verifying retry logic in the system under test itself.

## Detailed Explanation

### What `[Retry]` Does
```csharp
[Test, Retry(3)]
public void SomeTest()
{
    // Run up to 3 times; passes if any attempt succeeds
}
```
NUnit re-executes the test on failure. If the second or third run passes, the overall test result is *Pass*. The failure count is noted in output but the test is not marked failed.

### When It Might Seem Attractive
- Integration tests that connect to external services (flaky network)
- Tests that depend on timing (`Thread.Sleep`, eventual consistency)
- Tests in CI environments with resource contention

### Why It Is Almost Always Wrong

#### 1. It Hides Flaky Tests Rather Than Fixing Them
A flaky test is a symptom of a real problem: non-deterministic code, shared state, timing issues, or environment dependencies. `[Retry]` makes the test *pass* without fixing anything. The underlying bug remains.

#### 2. It Slows Down the Test Suite
Each retry takes as long as the original test. A test that fails twice and passes third time took 3× the normal time.

#### 3. It Erodes Trust
If tests sometimes need 3 attempts, developers stop trusting test failures. "Maybe it'll pass on retry" becomes the mindset, and genuine regressions go undetected.

#### 4. It Accumulates Technical Debt
`[Retry]` tests are rarely cleaned up. The codebase accumulates a growing list of acknowledged-but-ignored flaky tests.

### The One Legitimate Use Case
Testing your *own* retry logic:
```csharp
// Testing that a service properly retries a transient failure
[Test, Retry(1)] // not actually needed — the test controls the mock
public void OrderService_RetriesTransientFailureThenSucceeds()
{
    var gateway = new Mock<IPaymentGateway>();
    gateway.SetupSequence(g => g.Charge(It.IsAny<decimal>()))
           .Throws<TransientException>() // first call fails
           .Returns(true);              // second call succeeds

    var sut = new OrderService(gateway.Object);
    sut.Submit(order); // should internally retry

    gateway.Verify(g => g.Charge(It.IsAny<decimal>()), Times.Exactly(2));
}
// Note: the mock controls determinism; [Retry] is NOT needed here
```

In practice, even this use case doesn't require `[Retry]` — your mock controls the determinism.

### What To Do Instead of `[Retry]`

| Problem | Fix |
|---|---|
| `DateTime.Now` non-determinism | Inject `ITimeProvider`; use `FakeTimeProvider` |
| Random values | Seed randomness; use deterministic inputs |
| Timing (`Thread.Sleep`) | Use proper async/await; use `FakeTimeProvider` |
| External service dependency | Mock or use `WireMock.Net` / `HttpClientFactory` fakes |
| Shared state | Fix isolation; use per-test object creation |
| CI resource contention | Fix `[Parallelizable]` settings; use `[NonParallelizable]` |

> ⚠️ **Rule of thumb:** If you are tempted to add `[Retry]`, first ask: "What is the real reason this test is flaky?" Fix that instead.

## Code Example
```csharp
namespace Notifications.Tests;

[TestFixture]
public class EmailDispatcherTests
{
    // ❌ Code smell — [Retry] masks the real problem (shared state)
    [Test, Retry(3)]
    public void Send_DeliveredToQueue_BadExample()
    {
        // This test is flaky because _queue is a static shared resource
        // The real fix: make _queue per-test
        EmailDispatcher.Send(new Email { To = "user@example.com" });
        Assert.That(SharedTestQueue.Count, Is.EqualTo(1)); // fails if another test ran first
    }

    // ✅ Correct — remove shared state, test is now deterministic
    [Test]
    public void Send_DeliveredToQueue_GoodExample()
    {
        var queue = new InMemoryEmailQueue();  // fresh per test
        var sut = new EmailDispatcher(queue);

        sut.Send(new Email { To = "user@example.com" });

        Assert.That(queue.Count, Is.EqualTo(1));
    }

    // ✅ Legitimate [Retry] use — testing YOUR retry infrastructure
    // (In practice, mock controls determinism; [Retry] not needed)
    [Test]
    public void Dispatcher_RetriesOnTransientError_ThenSucceeds()
    {
        int callCount = 0;
        var queue = new Mock<IEmailQueue>();
        queue.Setup(q => q.Enqueue(It.IsAny<Email>()))
             .Callback(() =>
             {
                 if (++callCount < 3) throw new TransientQueueException();
             });

        var sut = new EmailDispatcher(queue.Object, maxRetries: 3);
        Assert.DoesNotThrow(() => sut.Send(new Email { To = "test@example.com" }));
        Assert.That(callCount, Is.EqualTo(3));
    }
}
```

## Common Follow-up Questions
- How do you identify flaky tests in a CI pipeline?
- What tools can automatically quarantine flaky tests?
- How does `[Retry]` interact with `[SetUp]`/`[TearDown]`?
- What is `FakeTimeProvider` and how does it make time-based tests deterministic?
- What are the alternatives to `[Retry]` in a microservices environment where external dependencies are unreliable?
- How do you report flaky test metrics in a CI/CD pipeline?

## Common Mistakes / Pitfalls
- **Adding `[Retry]` to "fix" a flaky test in a PR deadline** — creates permanent technical debt; always fix the root cause.
- **Large retry counts** — `[Retry(5)]` makes a flaky test take 5× longer and is even more expensive in CI.
- **`[Retry]` on unit tests** — unit tests should be 100% deterministic; any flakiness is a design problem.
- **Not investigating what `[Retry]` is hiding** — failing once and passing on retry is a bug signal that should be investigated, not silenced.
- **Using `[Retry]` for async tests that have timing issues** — fix the timing issue; use `FakeTimeProvider`, proper `await`, or `Task.WhenAny` patterns.

## References
- [NUnit documentation — Retry attribute](https://docs.nunit.org/articles/nunit/writing-tests/attributes/retry.html)
- [Martin Fowler — Eradicating Non-Determinism in Tests](https://martinfowler.com/articles/nonDeterminism.html)
- [Google Testing Blog — Flaky Tests at Google](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html) (verify URL)
- [Microsoft Learn — FakeTimeProvider](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-platform-intro)
