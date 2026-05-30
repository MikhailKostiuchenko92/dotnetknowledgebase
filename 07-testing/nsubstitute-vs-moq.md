# How Does NSubstitute Differ from Moq in Terms of API Design and Philosophy?

**Category:** Testing / Mocking
**Difficulty:** 🔴 Senior
**Tags:** `NSubstitute`, `moq`, `mocking`, `test-doubles`, `API-design`

## Question
> How does NSubstitute differ from Moq in terms of API design and philosophy?

## Short Answer
NSubstitute takes a "natural language" approach: you call the substitute as if it were the real object to configure it, then assert after the fact using `Received()`. Moq uses a lambda-based fluent API with `.Setup().Returns()` for configuration and `.Verify()` for assertions. Both produce the same runtime behaviour (DynamicProxy-based), but NSubstitute produces significantly less boilerplate for simple stubs and is often considered more readable.

## Detailed Explanation

### Core Philosophy

| Aspect | Moq | NSubstitute |
|---|---|---|
| Style | Fluent wrapper (`Mock<T>`) | Act-on-the-substitute directly |
| Setup syntax | `.Setup(x => x.M()).Returns(v)` | `sub.M().Returns(v)` |
| Verification | `.Verify(x => x.M(), Times.Once)` | `sub.Received(1).M()` |
| Object | `.Object` property | Substitute IS the object |
| Default behaviour | MockBehavior.Loose by default | Auto-returns defaults |
| Protected members | `.Protected()` + `ItExpr` | Not supported natively |

### Moq — Verbose but Explicit
```csharp
var repo = new Mock<IOrderRepository>();
repo.Setup(r => r.GetById(1)).Returns(new Order { Id = 1 });

var sut = new OrderService(repo.Object); // .Object needed

repo.Verify(r => r.GetById(1), Times.Once);
```

### NSubstitute — Compact and Natural
```csharp
var repo = Substitute.For<IOrderRepository>();
repo.GetById(1).Returns(new Order { Id = 1 });

var sut = new OrderService(repo); // no .Object

repo.Received(1).GetById(1);
```

### Argument Matchers

```csharp
// Moq
mock.Setup(r => r.Find(It.IsAny<string>())).Returns(null);

// NSubstitute
sub.Find(Arg.Any<string>()).Returns((Order?)null);
```

### Async Methods

```csharp
// Moq
mock.Setup(s => s.SaveAsync(It.IsAny<Order>())).ReturnsAsync(true);

// NSubstitute
sub.SaveAsync(Arg.Any<Order>()).Returns(Task.FromResult(true));
// or shorter:
sub.SaveAsync(Arg.Any<Order>()).Returns(true); // auto-wraps in Task
```

### Throwing Exceptions

```csharp
// Moq
mock.Setup(r => r.GetById(0)).Throws<ArgumentException>();

// NSubstitute
sub.GetById(0).Throws<ArgumentException>();
// async:
sub.GetAsync(0).Throws<ArgumentException>(); // wraps in faulted Task
```

### Callbacks

```csharp
// Moq
mock.Setup(s => s.Log(It.IsAny<string>()))
    .Callback<string>(msg => Console.WriteLine(msg));

// NSubstitute
sub.When(s => s.Log(Arg.Any<string>()))
   .Do(ctx => Console.WriteLine(ctx.Arg<string>()));
```

### When to Choose Which

| Prefer Moq when… | Prefer NSubstitute when… |
|---|---|
| Team already uses Moq | Starting fresh — NSubstitute is more ergonomic |
| Need `MockBehavior.Strict` | Prefer minimal boilerplate stubs |
| Mocking protected members | Writing tests that read like prose |
| Using `Mock.Of<T>()` LINQ style | Want `Received`/`DidNotReceive` for clarity |

> 💡 Both libraries have identical runtime constraints (Castle DynamicProxy): cannot mock sealed classes, static members, or non-virtual methods.

## Code Example
```csharp
namespace Comparison.Tests;

// ── Moq ──────────────────────────────────────────────────
public class OrderServiceTests_Moq
{
    [Fact]
    public async Task FulfillOrder_CallsRepository_AndNotification()
    {
        var repo = new Mock<IOrderRepository>();
        var notify = new Mock<INotificationService>();

        repo.Setup(r => r.GetByIdAsync(1))
            .ReturnsAsync(new Order { Id = 1, Status = OrderStatus.Pending });

        var sut = new OrderService(repo.Object, notify.Object);
        await sut.FulfillAsync(1);

        repo.Verify(r => r.GetByIdAsync(1), Times.Once);
        notify.Verify(n => n.SendAsync(It.Is<string>(s => s.Contains("fulfilled"))), Times.Once);
    }
}

// ── NSubstitute ───────────────────────────────────────────
public class OrderServiceTests_NSub
{
    [Fact]
    public async Task FulfillOrder_CallsRepository_AndNotification()
    {
        var repo = Substitute.For<IOrderRepository>();
        var notify = Substitute.For<INotificationService>();

        repo.GetByIdAsync(1).Returns(new Order { Id = 1, Status = OrderStatus.Pending });

        var sut = new OrderService(repo, notify);
        await sut.FulfillAsync(1);

        await repo.Received(1).GetByIdAsync(1);
        await notify.Received(1).SendAsync(Arg.Is<string>(s => s.Contains("fulfilled")));
    }
}
```

## Common Follow-up Questions
- Which is more popular in the .NET ecosystem, Moq or NSubstitute?
- Can you mix NSubstitute and Moq in the same test project?
- Does NSubstitute support `MockBehavior.Strict` equivalent?
- How do you verify that a method was NOT called in NSubstitute?
- What is the `When...Do` pattern in NSubstitute?
- How do you handle argument matching for `ref` parameters in NSubstitute?

## Common Mistakes / Pitfalls
- **Forgetting `.Object` in Moq but not in NSubstitute** — NSubstitute returns `T` directly; if you're used to Moq, watch for this when switching.
- **Using `Received()` without `await` for async methods** — async verified calls should use `await sub.Received(n).MethodAsync()`.
- **Assuming NSubstitute supports `Strict` mode** — it doesn't have direct equivalent; unexpected calls return defaults silently.
- **Mixing `It` (Moq) with `Arg` (NSubstitute)** — different namespaces; importing both causes ambiguity.
- **Ignoring the Moq controversy (2024 telemetry incident)** — some teams moved to NSubstitute after concerns about telemetry in Moq 4.20; verify your version.

## References
- [NSubstitute documentation](https://nsubstitute.github.io/)
- [NSubstitute on GitHub](https://github.com/nsubstitute/NSubstitute)
- [Moq on GitHub](https://github.com/devlooped/moq)
- [NuGet — NSubstitute](https://www.nuget.org/packages/NSubstitute/)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
