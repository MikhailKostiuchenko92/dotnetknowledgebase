# How Do You Create a Basic Mock with Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟢 Junior
**Tags:** `moq`, `mock`, `test-doubles`, `setup`, `returns`

## Question
> How do you create a basic mock with Moq?

## Short Answer
Install `Moq` via NuGet, create a mock with `new Mock<IYourInterface>()`, configure it with `Setup(...)...Returns(...)`, and pass `mock.Object` to the system under test. Optionally verify calls with `mock.Verify(...)` after the act.

## Detailed Explanation

### Installation
```bash
dotnet add package Moq
```
Moq targets .NET Standard 2.0+; compatible with .NET 8/9.

### The Three Steps of a Moq-Based Test
1. **Create** — `var mock = new Mock<IFoo>();`
2. **Setup (Arrange)** — configure return values and exceptions.
3. **Use** — pass `mock.Object` to the SUT.
4. **Verify (Assert)** — optionally assert interactions.

### `Mock<T>` vs. `Mock.Of<T>()`
| | `new Mock<T>()` | `Mock.Of<T>()` |
|---|---|---|
| Returns | `Mock<T>` wrapper | `T` directly |
| Customisation | Via `mock.Setup(...)` | Via `Mock.Get(obj).Setup(...)` or LINQ config |
| Verification | `mock.Verify(...)` | Needs `Mock.Get(obj).Verify(...)` |
| Use case | When you need to set up or verify | When you need a quick, unconfigured instance (dummy) |

### `MockBehavior`
- **`MockBehavior.Loose`** (default) — un-configured members return defaults (`null`, `0`, `false`, empty collections). Doesn't throw.
- **`MockBehavior.Strict`** — throws `MockException` for any call that wasn't explicitly set up. Forces you to be explicit about every interaction.

### Moq's Key Capabilities
| Capability | How |
|---|---|
| Return a value | `.Setup(x => x.Method()).Returns(value)` |
| Return async | `.Setup(x => x.MethodAsync()).ReturnsAsync(value)` |
| Throw | `.Setup(x => x.Method()).Throws<MyException>()` |
| Callback | `.Setup(x => x.Method()).Callback(() => ...)` |
| Match arguments | `It.IsAny<T>()`, `It.Is<T>(pred)` |
| Verify call | `mock.Verify(x => x.Method(), Times.Once)` |
| Verify no calls | `mock.VerifyNoOtherCalls()` |

## Code Example
```csharp
namespace Orders.Tests;

public class OrderServiceTests
{
    [Fact]
    public void GetOrder_WhenExists_ReturnsOrder()
    {
        // 1. Create the mock
        var repo = new Mock<IOrderRepository>();

        // 2. Configure it (stub)
        repo.Setup(r => r.FindById(42))
            .Returns(new Order { Id = 42, Total = 150m });

        // 3. Inject mock.Object (not the mock itself)
        var sut = new OrderService(repo.Object);

        // 4. Act
        var order = sut.GetOrder(42);

        // 5. Assert on SUT output
        order.Should().NotBeNull();
        order!.Total.Should().Be(150m);
    }

    [Fact]
    public void PlaceOrder_SendsConfirmationEmail()
    {
        var repo = new Mock<IOrderRepository>();
        var emailSender = new Mock<IEmailSender>();
        var sut = new OrderService(repo.Object, emailSender.Object);

        sut.PlaceOrder(new Order { Id = 1, CustomerEmail = "user@test.com", Total = 200m });

        // Verify interaction
        emailSender.Verify(
            e => e.Send(It.Is<Email>(m => m.To == "user@test.com")),
            Times.Once);
    }

    [Fact]
    public void GetOrder_WhenNotFound_ReturnsNull()
    {
        var repo = new Mock<IOrderRepository>(); // Loose — FindById returns null by default
        var sut = new OrderService(repo.Object);

        var order = sut.GetOrder(999);

        order.Should().BeNull();
    }

    // Mock.Of<T>() — quick dummy with no setup needed
    [Fact]
    public void Constructor_AcceptsNullLogger()
    {
        var repo = new Mock<IOrderRepository>();
        // ILogger is a dummy — we don't configure or verify it
        var logger = Mock.Of<ILogger<OrderService>>();

        var sut = new OrderService(repo.Object, logger: logger);
        sut.Should().NotBeNull();
    }
}
```

## Common Follow-up Questions
- How do you set up a method to return different values on successive calls (`SetupSequence`)?
- How do you configure a mock to throw an exception?
- What is `It.IsAny<T>()` and when should you use it?
- What is the difference between `MockBehavior.Strict` and `MockBehavior.Loose`?
- Can Moq mock static methods or sealed classes?
- How do you mock a method that returns `Task<T>` in Moq?

## Common Mistakes / Pitfalls
- **Passing `mock` instead of `mock.Object`** — `mock` is the Moq wrapper; `mock.Object` is the actual `T` to inject.
- **Setting up on the wrong interface** — `Setup(r => r.FindById(42)).Returns(...)` must match the exact member and parameter.
- **Forgetting to use argument matchers** — `Setup(r => r.FindById(42))` only matches calls with exactly `42`; use `It.IsAny<int>()` for general matching.
- **Verifying a call that was also used as a stub** — sometimes valid, but double-check that the verification adds value beyond the state assertion.
- **Using Moq to mock concrete classes without a virtual method** — Moq can only mock abstract/interface members or virtual members of concrete classes.

## References
- [Moq documentation — Quickstart](https://github.com/devlooped/moq/wiki/Quickstart)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
- [Microsoft Learn — Unit testing with Moq](https://learn.microsoft.com/en-us/dotnet/core/testing/)
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns (Manning)](https://www.manning.com/books/unit-testing)
